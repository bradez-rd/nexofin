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
}

export interface UpdateProfileDTO {
  nombre?: string;
  foto_url?: string | null;
  moneda_predeterminada?: string;
  zona_horaria?: string;
}

export interface AuthResponse {
  user: Omit<User, 'password_hash'>;
  token: string;
}

export class AuthService {
  constructor(private readonly userRepository: IUserRepository) {}

  public async register(dto: RegisterDTO): Promise<AuthResponse> {
    const existing = await this.userRepository.findByEmail(dto.email);
    if (existing) {
      throw new ConflictError('Ya existe una cuenta registrada con este correo electrónico');
    }

    // Regla RF-AUT-01: Contraseña mínima de 10 caracteres
    if (!dto.password || dto.password.length < 10) {
      throw new ValidationError('La contraseña debe tener una longitud mínima de 10 caracteres');
    }

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

    return {
      user: this.sanitizeUser(user),
      token,
    };
  }

  public async login(dto: LoginDTO): Promise<AuthResponse> {
    const user = await this.userRepository.findByEmail(dto.email);
    if (!user) {
      // Error genérico para no revelar si el correo existe (RF-AUT-03)
      throw new UnauthorizedError('Credenciales inválidas');
    }

    // RN-SEG-02: Verificar si la cuenta está bloqueada temporalmente
    if (user.bloqueado_hasta && new Date(user.bloqueado_hasta) > new Date()) {
      const minutesLeft = Math.ceil(
        (new Date(user.bloqueado_hasta).getTime() - Date.now()) / (1000 * 60)
      );
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

      throw new UnauthorizedError('Credenciales inválidas');
    }

    // Si tuvo intentos fallidos previos pero acertó, reiniciar contador
    if (user.intentos_fallidos > 0) {
      await this.userRepository.resetFailedAttempts(user.id);
    }

    const token = TokenService.generateToken({
      userId: user.id,
      email: user.email,
    });

    return {
      user: this.sanitizeUser(user),
      token,
    };
  }

  public async getProfile(userId: string): Promise<Omit<User, 'password_hash'>> {
    const user = await this.userRepository.findById(userId);
    if (!user) {
      throw new NotFoundError('Usuario no encontrado');
    }
    return this.sanitizeUser(user);
  }

  public async updateProfile(
    userId: string,
    dto: UpdateProfileDTO
  ): Promise<Omit<User, 'password_hash'>> {
    const user = await this.userRepository.findById(userId);
    if (!user) {
      throw new NotFoundError('Usuario no encontrado');
    }

    const updated = await this.userRepository.update(userId, dto);
    return this.sanitizeUser(updated);
  }

  private sanitizeUser(user: User): Omit<User, 'password_hash'> {
    const { password_hash, ...rest } = user;
    return rest;
  }
}
