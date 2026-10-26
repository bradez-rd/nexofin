import {
  ITransactionRepository,
  IAccountRepository,
  ICategoryRepository,
  TransactionFilter,
} from '../../domain/repositories/index.js';
import { Transaction, TransactionType, TransactionDirection } from '../../domain/models/index.js';
import {
  NotFoundError,
  ValidationError,
  ConflictError,
} from '../../domain/errors/DomainError.js';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';

export interface CreateTransactionDTO {
  cuenta_id: string;
  categoria_id?: string | null;
  tipo: TransactionType;
  sentido?: TransactionDirection;
  monto: number;
  fecha: string;
  descripcion?: string | null;
  nota?: string | null;
}

export interface CreateTransferDTO {
  cuenta_origen_id: string;
  cuenta_destino_id: string;
  monto: number;
  fecha: string;
  descripcion?: string;
}

export interface UpdateTransactionDTO {
  categoria_id?: string | null;
  monto?: number;
  fecha?: string;
  descripcion?: string | null;
  nota?: string | null;
}

export class TransactionService {
  constructor(
    private readonly transactionRepository: ITransactionRepository,
    private readonly accountRepository: IAccountRepository,
    private readonly categoryRepository: ICategoryRepository
  ) {}

  public async createTransaction(
    userId: string,
    dto: CreateTransactionDTO
  ): Promise<Transaction> {
    // 1. Validaciones financieras (RN-TRX-01)
    if (!dto.cuenta_id) {
      throw new ValidationError('La cuenta es obligatoria');
    }

    if (!dto.monto || dto.monto <= 0) {
      throw new ValidationError('El monto debe ser un valor positivo mayor que cero');
    }

    if (!dto.fecha || !/^\d{4}-\d{2}-\d{2}$/.test(dto.fecha)) {
      throw new ValidationError('La fecha debe tener un formato válido (AAAA-MM-DD)');
    }

    // 2. Verificar existencia de la cuenta y pertenencia al usuario
    const account = await this.accountRepository.findById(dto.cuenta_id, userId);
    if (!account) {
      throw new NotFoundError('La cuenta especificada no existe o no pertenece al usuario');
    }
    if (account.archivada) {
      throw new ValidationError('No se pueden registrar transacciones en una cuenta archivada');
    }

    // 3. Verificar categoría si fue provista
    if (dto.categoria_id) {
      const category = await this.categoryRepository.findById(dto.categoria_id);
      if (!category) {
        throw new NotFoundError('La categoría seleccionada no existe');
      }
    }

    // 4. Determinar sentido financiero según el tipo
    const sentido = FinancialCalculator.getDirectionFromType(dto.tipo, dto.sentido);
    const roundedMonto = FinancialCalculator.roundMoney(dto.monto);

    // 5. Generar huella y prevenir duplicación idéntica reciente
    const huella = FinancialCalculator.generateFingerprint(
      dto.cuenta_id,
      dto.fecha,
      roundedMonto,
      dto.descripcion || ''
    );

    const duplicate = await this.transactionRepository.findByFingerprint(huella, userId);
    if (duplicate) {
      // Advertencia de duplicado potencial
      console.warn(`[Transaction] Posible duplicado detectado con huella ${huella}`);
    }

    return this.transactionRepository.create({
      usuario_id: userId,
      cuenta_id: dto.cuenta_id,
      categoria_id: dto.categoria_id || null,
      tipo: dto.tipo,
      sentido,
      monto: roundedMonto,
      fecha: dto.fecha,
      descripcion: dto.descripcion?.trim() || null,
      nota: dto.nota?.trim() || null,
      huella,
    });
  }

  public async createTransfer(
    userId: string,
    dto: CreateTransferDTO
  ): Promise<{ salida: Transaction; entrada: Transaction }> {
    if (!dto.cuenta_origen_id || !dto.cuenta_destino_id) {
      throw new ValidationError('Se requieren la cuenta de origen y la cuenta de destino');
    }

    if (dto.cuenta_origen_id === dto.cuenta_destino_id) {
      throw new ValidationError('La cuenta de origen y destino no pueden ser la misma');
    }

    if (!dto.monto || dto.monto <= 0) {
      throw new ValidationError('El monto a transferir debe ser mayor que cero');
    }

    if (!dto.fecha || !/^\d{4}-\d{2}-\d{2}$/.test(dto.fecha)) {
      throw new ValidationError('La fecha debe tener un formato válido (AAAA-MM-DD)');
    }

    const [origen, destino] = await Promise.all([
      this.accountRepository.findById(dto.cuenta_origen_id, userId),
      this.accountRepository.findById(dto.cuenta_destino_id, userId),
    ]);

    if (!origen) throw new NotFoundError('La cuenta de origen no existe o no pertenece al usuario');
    if (!destino) throw new NotFoundError('La cuenta de destino no existe o no pertenece al usuario');

    if (origen.archivada || destino.archivada) {
      throw new ValidationError('No se pueden realizar transferencias con cuentas archivadas');
    }

    return this.transactionRepository.createTransfer(
      userId,
      dto.cuenta_origen_id,
      dto.cuenta_destino_id,
      FinancialCalculator.roundMoney(dto.monto),
      dto.fecha,
      dto.descripcion?.trim()
    );
  }

  public async listTransactions(
    userId: string,
    filter: TransactionFilter = {}
  ): Promise<{ transactions: Transaction[]; total: number; limit: number; offset: number }> {
    const limit = filter.limit && filter.limit > 0 ? Math.min(filter.limit, 100) : 20;
    const offset = filter.offset && filter.offset >= 0 ? filter.offset : 0;

    const { transactions, total } = await this.transactionRepository.findByUser(userId, {
      ...filter,
      limit,
      offset,
    });

    return {
      transactions,
      total,
      limit,
      offset,
    };
  }

  public async getTransactionById(userId: string, transactionId: string): Promise<Transaction> {
    const trx = await this.transactionRepository.findById(transactionId, userId);
    if (!trx) {
      throw new NotFoundError('Transacción no encontrada');
    }
    return trx;
  }

  public async updateTransaction(
    userId: string,
    transactionId: string,
    dto: UpdateTransactionDTO
  ): Promise<Transaction> {
    const existing = await this.getTransactionById(userId, transactionId);

    if (dto.monto !== undefined && dto.monto <= 0) {
      throw new ValidationError('El monto debe ser mayor que cero');
    }

    if (dto.categoria_id) {
      const cat = await this.categoryRepository.findById(dto.categoria_id);
      if (!cat) throw new NotFoundError('La categoría no existe');
    }

    // Instantánea de valores anteriores para RF-TRX-03
    const oldValuesSnapshot = {
      monto: existing.monto,
      categoria_id: existing.categoria_id,
      fecha: existing.fecha,
      descripcion: existing.descripcion,
      nota: existing.nota,
    };

    return this.transactionRepository.update(transactionId, userId, dto, oldValuesSnapshot);
  }

  public async deleteTransaction(userId: string, transactionId: string): Promise<void> {
    await this.getTransactionById(userId, transactionId);
    await this.transactionRepository.softDelete(transactionId, userId);
  }

  public async getMonthlySummary(
    userId: string,
    year: number,
    month: number
  ): Promise<{ totalIngresos: number; totalGastos: number; balanceNeto: number; periodo: string }> {
    if (isNaN(year) || isNaN(month) || month < 1 || month > 12) {
      throw new ValidationError('Año y mes inválidos');
    }

    const summary = await this.transactionRepository.getMonthlySummary(userId, year, month);
    return {
      ...summary,
      periodo: `${year}-${String(month).padStart(2, '0')}`,
    };
  }
}
