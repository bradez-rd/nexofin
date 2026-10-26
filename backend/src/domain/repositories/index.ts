import { User, Account, Transaction, Category } from '../models/index.js';

export interface CreateUserData {
  nombre: string;
  email: string;
  password_hash: string;
  moneda_predeterminada?: string;
  zona_horaria?: string;
}

export interface UpdateUserData {
  nombre?: string;
  foto_url?: string | null;
  moneda_predeterminada?: string;
  zona_horaria?: string;
}

export interface IUserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  create(data: CreateUserData): Promise<User>;
  update(id: string, data: UpdateUserData): Promise<User>;
  updateFailedAttempts(id: string, attempts: number, lockUntil?: Date | null): Promise<void>;
  resetFailedAttempts(id: string): Promise<void>;
}

export interface CreateAccountData {
  usuario_id: string;
  nombre: string;
  tipo: 'efectivo' | 'bancaria' | 'tarjeta';
  moneda?: string;
  saldo_inicial?: number;
  limite_credito?: number | null;
  dia_corte?: number | null;
  dia_pago?: number | null;
}

export interface UpdateAccountData {
  nombre?: string;
  saldo_inicial?: number;
  limite_credito?: number | null;
  dia_corte?: number | null;
  dia_pago?: number | null;
  archivada?: boolean;
}

export interface IAccountRepository {
  findById(id: string, usuarioId: string): Promise<Account | null>;
  findByUser(usuarioId: string, includeArchived?: boolean): Promise<Account[]>;
  create(data: CreateAccountData): Promise<Account>;
  update(id: string, usuarioId: string, data: UpdateAccountData): Promise<Account>;
  archive(id: string, usuarioId: string): Promise<Account>;
  getBalancesSummary(usuarioId: string): Promise<{ moneda: string; total_saldo: number; cantidad_cuentas: number }[]>;
}

export interface TransactionFilter {
  cuenta_id?: string;
  categoria_id?: string;
  tipo?: string;
  fecha_inicio?: string;
  fecha_fin?: string;
  busqueda?: string;
  limit?: number;
  offset?: number;
}

export interface CreateTransactionData {
  usuario_id: string;
  cuenta_id: string;
  categoria_id?: string | null;
  tipo: 'ingreso' | 'gasto' | 'transferencia' | 'ajuste' | 'aporte_meta';
  sentido: 'entrada' | 'salida';
  monto: number;
  fecha: string;
  descripcion?: string | null;
  nota?: string | null;
  transferencia_vinculada_id?: string | null;
  huella?: string | null;
}

export interface UpdateTransactionData {
  categoria_id?: string | null;
  monto?: number;
  fecha?: string;
  descripcion?: string | null;
  nota?: string | null;
}

export interface ITransactionRepository {
  findById(id: string, usuarioId: string): Promise<Transaction | null>;
  findByUser(usuarioId: string, filter?: TransactionFilter): Promise<{ transactions: Transaction[]; total: number }>;
  findByFingerprint(huella: string, usuarioId: string): Promise<Transaction | null>;
  create(data: CreateTransactionData): Promise<Transaction>;
  createTransfer(
    usuarioId: string,
    cuentaOrigenId: string,
    cuentaDestinoId: string,
    monto: number,
    fecha: string,
    descripcion?: string
  ): Promise<{ salida: Transaction; entrada: Transaction }>;
  update(id: string, usuarioId: string, data: UpdateTransactionData, oldValuesSnapshot: Record<string, unknown>): Promise<Transaction>;
  softDelete(id: string, usuarioId: string): Promise<void>;
  getMonthlySummary(usuarioId: string, year: number, month: number): Promise<{ totalIngresos: number; totalGastos: number; balanceNeto: number }>;
}

export interface ICategoryRepository {
  findById(id: string): Promise<Category | null>;
  findAllForUser(usuarioId: string, tipo?: 'ingreso' | 'gasto'): Promise<Category[]>;
  create(usuarioId: string, nombre: string, tipo: 'ingreso' | 'gasto', icono?: string, color?: string): Promise<Category>;
}
