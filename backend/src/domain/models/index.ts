export interface User {
  id: string;
  nombre: string;
  email: string;
  password_hash: string;
  moneda_predeterminada: string;
  zona_horaria: string;
  foto_url?: string | null;
  email_verificado: boolean;
  dos_factores_activo: boolean;
  intentos_fallidos: number;
  bloqueado_hasta?: Date | null;
  consentimiento_ia_en?: Date | null;
  creado_en: Date;
}

export type AccountType = 'efectivo' | 'bancaria' | 'tarjeta';

export interface Account {
  id: string;
  usuario_id: string;
  nombre: string;
  tipo: AccountType;
  moneda: string;
  saldo_inicial: number;
  limite_credito?: number | null;
  dia_corte?: number | null;
  dia_pago?: number | null;
  archivada: boolean;
  creada_en: Date;
  saldo_actual?: number;
}

export type CategoryType = 'ingreso' | 'gasto';

export interface Category {
  id: string;
  usuario_id?: string | null;
  nombre: string;
  tipo: CategoryType;
  icono?: string | null;
  color?: string | null;
  es_sistema: boolean;
  archivada: boolean;
}

export type TransactionType = 'ingreso' | 'gasto' | 'transferencia' | 'ajuste' | 'aporte_meta';
export type TransactionDirection = 'entrada' | 'salida';
export type CategoryStatus = 'categorizada' | 'pendiente_revision' | 'sin_categoria';

export interface Transaction {
  id: string;
  usuario_id: string;
  cuenta_id: string;
  categoria_id?: string | null;
  tipo: TransactionType;
  sentido: TransactionDirection;
  monto: number;
  fecha: string; // YYYY-MM-DD
  descripcion?: string | null;
  nota?: string | null;
  estado_categoria: CategoryStatus;
  confianza?: number | null;
  categoria_manual: boolean;
  transferencia_vinculada_id?: string | null;
  recurrente_id?: string | null;
  importacion_id?: string | null;
  huella?: string | null;
  eliminada: boolean;
  eliminada_en?: Date | null;
  creada_en: Date;
}
