import { IUserRepository } from '../../domain/repositories/index.js';
import { PasswordHasher } from '../../infrastructure/security/PasswordHasher.js';
import { TokenService } from '../../infrastructure/security/TokenService.js';
import {
  ConflictError,
  UnauthorizedError,
  ValidationError,
  NotFoundError,
} from '../../domain/errors/DomainError.js';
import { User } from '../../domain/models/index.js';
import { PasswordPolicy } from '../../domain/services/PasswordPolicy.js';
import { SessionService } from '../../infrastructure/security/SessionService.js';
import { SecurityService } from './SecurityService.js';
import { AuditService } from '../audit/AuditService.js';
import crypto from 'crypto';

export interface RegisterDTO {
  nombre: string;
  email: string;
  password: string;
  moneda_predeterminada?: string;
  zona_horaria?: string;
}

export interface LoginDTO {
  email: string;
  password: string;
  codigo_2fa?: string;
}

export interface UpdateProfileDTO {
  nombre?: string;
  foto_url?: string | null;
  moneda_predeterminada?: string;
  zona_horaria?: string;
}

export interface AuthResponse {
  user: Omit<User, 'password_hash' | 'secreto_2fa'>;
  token: string;
}

export class AuthService {
  constructor(private readonly userRepository: IUserRepository) {}

  public async register(dto: RegisterDTO): Promise<AuthResponse> {
    const existing = await this.userRepository.findByEmail(dto.email);
    if (existing) {
      throw new ConflictError('Ya existe una cuenta registrada con este correo electrónico');
    }

    // Regla RF-AUT-01: mínimo 10 caracteres y fuera de la lista de contraseñas comunes
    PasswordPolicy.assert(dto.password);

    const passwordHash = await PasswordHasher.hash(dto.password);
    const user = await this.userRepository.create({
      nombre: dto.nombre.trim(),
      email: dto.email.trim().toLowerCase(),
      password_hash: passwordHash,
      moneda_predeterminada: dto.moneda_predeterminada || 'DOP',
      zona_horaria: dto.zona_horaria || 'America/Santo_Domingo',
    });

    const token = TokenService.generateToken({
      userId: user.id,
      email: user.email,
    });
    await SessionService.create(user.id, token);
    await AuditService.log(user.id, 'registro');

    return {
      user: this.sanitizeUser(user),
      token,
    };
  }

  public async login(dto: LoginDTO): Promise<AuthResponse> {
    const user = await this.userRepository.findByEmail(dto.email);
    if (!user) {
      // Error genérico para no revelar si el correo existe (RF-AUT-03)
      await AuditService.log(null, 'login', 'fallo', {
        referencia: crypto.createHash('sha256').update(dto.email.toLowerCase()).digest('hex').slice(0, 16),
      });
      throw new UnauthorizedError('Credenciales inválidas');
    }

    // RN-SEG-02: Verificar si la cuenta está bloqueada temporalmente
    if (user.bloqueado_hasta && new Date(user.bloqueado_hasta) > new Date()) {
      const minutesLeft = Math.ceil(
        (new Date(user.bloqueado_hasta).getTime() - Date.now()) / (1000 * 60)
      );
      await AuditService.log(user.id, 'login', 'fallo', { motivo: 'cuenta_bloqueada' });
      throw new UnauthorizedError(
        `Cuenta temporalmente bloqueada por seguridad tras 5 intentos fallidos. Intente nuevamente en ${minutesLeft} minuto(s).`
      );
    }

    const isMatch = await PasswordHasher.compare(dto.password, user.password_hash);
    if (!isMatch) {
      const failed = user.intentos_fallidos + 1;
      let lockUntil: Date | null = null;
      if (failed >= 5) {
        // Bloqueo de 15 minutos tras 5 intentos
        lockUntil = new Date(Date.now() + 15 * 60 * 1000);
      }
      await this.userRepository.updateFailedAttempts(user.id, failed, lockUntil);
      await AuditService.log(user.id, 'login', 'fallo', { motivo: 'credenciales', intentos: failed });

      throw new UnauthorizedError('Credenciales inválidas');
    }

    // RF-AUT-07: con la verificación en dos pasos activa se exige el segundo factor
    if (user.dos_factores_activo) {
      if (!dto.codigo_2fa) {
        throw new UnauthorizedError('Se requiere el código de verificación en dos pasos');
      }
      if (!(await SecurityService.verifySecondFactor(user.id, dto.codigo_2fa))) {
        await AuditService.log(user.id, 'login', 'fallo', { motivo: 'segundo_factor' });
        throw new UnauthorizedError('El código de verificación en dos pasos no es correcto');
      }
    }

    // Si tuvo intentos fallidos previos pero acertó, reiniciar contador
    if (user.intentos_fallidos > 0) {
      await this.userRepository.resetFailedAttempts(user.id);
    }

    const token = TokenService.generateToken({
      userId: user.id,
      email: user.email,
    });
    await SessionService.create(user.id, token);
    await AuditService.log(user.id, 'login');

    return {
      user: this.sanitizeUser(user),
      token,
    };
  }

  public async logout(userId: string, token: string): Promise<void> {
    await SessionService.revoke(token);
    await AuditService.log(userId, 'logout');
  }

  public async getProfile(userId: string): Promise<Omit<User, 'password_hash' | 'secreto_2fa'>> {
    const user = await this.userRepository.findById(userId);
    if (!user) {
      throw new NotFoundError('Usuario no encontrado');
    }
    return this.sanitizeUser(user);
  }

  public async updateProfile(
    userId: string,
    dto: UpdateProfileDTO
  ): Promise<Omit<User, 'password_hash' | 'secreto_2fa'>> {
    const user = await this.userRepository.findById(userId);
    if (!user) {
      throw new NotFoundError('Usuario no encontrado');
    }

    const updated = await this.userRepository.update(userId, dto);
    return this.sanitizeUser(updated);
  }

  private sanitizeUser(user: User): Omit<User, 'password_hash' | 'secreto_2fa'> {
    const { password_hash, secreto_2fa, ...rest } = user;
    return rest;
  }
}
