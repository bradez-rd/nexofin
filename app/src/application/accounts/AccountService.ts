import { IAccountRepository } from '../../domain/repositories/index.js';
import { Account, AccountType } from '../../domain/models/index.js';
import { NotFoundError, ValidationError } from '../../domain/errors/DomainError.js';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';

export interface CreateAccountDTO {
  nombre: string;
  tipo: AccountType;
  moneda?: string;
  saldo_inicial?: number;
  limite_credito?: number | null;
  dia_corte?: number | null;
  dia_pago?: number | null;
}

export interface UpdateAccountDTO {
  nombre?: string;
  saldo_inicial?: number;
  limite_credito?: number | null;
  dia_corte?: number | null;
  dia_pago?: number | null;
  archivada?: boolean;
}

export class AccountService {
  constructor(private readonly accountRepository: IAccountRepository) {}

  public async createAccount(userId: string, dto: CreateAccountDTO): Promise<Account> {
    if (!dto.nombre || dto.nombre.trim().length === 0) {
      throw new ValidationError('El nombre de la cuenta es obligatorio');
    }

    if (!['efectivo', 'bancaria', 'tarjeta'].includes(dto.tipo)) {
      throw new ValidationError('Tipo de cuenta inválido. Debe ser efectivo, bancaria o tarjeta');
    }

    if (dto.saldo_inicial !== undefined && isNaN(dto.saldo_inicial)) {
      throw new ValidationError('El saldo inicial debe ser un número válido');
    }

    return this.accountRepository.create({
      usuario_id: userId,
      nombre: dto.nombre.trim(),
      tipo: dto.tipo,
      moneda: dto.moneda || 'DOP',
      saldo_inicial: dto.saldo_inicial !== undefined ? FinancialCalculator.roundMoney(dto.saldo_inicial) : 0,
      limite_credito: dto.limite_credito,
      dia_corte: dto.dia_corte,
      dia_pago: dto.dia_pago,
    });
  }

  public async listAccounts(userId: string, includeArchived: boolean = false): Promise<Account[]> {
    return this.accountRepository.findByUser(userId, includeArchived);
  }

  public async getAccountById(userId: string, accountId: string): Promise<Account> {
    const account = await this.accountRepository.findById(accountId, userId);
    if (!account) {
      throw new NotFoundError('Cuenta financiera no encontrada');
    }
    return account;
  }

  public async updateAccount(
    userId: string,
    accountId: string,
    dto: UpdateAccountDTO
  ): Promise<Account> {
    await this.getAccountById(userId, accountId); // Verificar existencia y pertenencia
    return this.accountRepository.update(accountId, userId, dto);
  }

  public async archiveAccount(userId: string, accountId: string): Promise<Account> {
    await this.getAccountById(userId, accountId);
    return this.accountRepository.archive(accountId, userId);
  }

  public async getBalancesSummary(
    userId: string
  ): Promise<{ moneda: string; total_saldo: number; cantidad_cuentas: number }[]> {
    return this.accountRepository.getBalancesSummary(userId);
  }
}
