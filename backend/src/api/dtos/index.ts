import { z } from 'zod';

// ============================================================================
// DTOs de Autenticación (RF-AUT)
// ============================================================================

export const RegisterSchema = z.object({
  nombre: z.string().min(2, 'El nombre debe tener al menos 2 caracteres').max(100),
  email: z.string().email('Debe ser un correo electrónico válido'),
  password: z
    .string()
    .min(10, 'La contraseña debe tener al menos 10 caracteres según la política de seguridad'),
  moneda_predeterminada: z.string().length(3).optional().default('DOP'),
  zona_horaria: z.string().optional().default('America/Santo_Domingo'),
});

export const LoginSchema = z.object({
  email: z.string().email('Debe ser un correo electrónico válido'),
  password: z.string().min(1, 'La contraseña es requerida'),
});

export const UpdateProfileSchema = z.object({
  nombre: z.string().min(2).max(100).optional(),
  foto_url: z.string().url().nullable().optional(),
  moneda_predeterminada: z.string().length(3).optional(),
  zona_horaria: z.string().optional(),
});

// ============================================================================
// DTOs de Cuentas Financieras (RF-CTA)
// ============================================================================

export const CreateAccountSchema = z.object({
  nombre: z.string().min(2, 'El nombre debe tener al menos 2 caracteres').max(80),
  tipo: z.enum(['efectivo', 'bancaria', 'tarjeta']),
  moneda: z.string().length(3).optional().default('DOP'),
  saldo_inicial: z.number().optional().default(0),
  limite_credito: z.number().positive().nullable().optional(),
  dia_corte: z.number().int().min(1).max(31).nullable().optional(),
  dia_pago: z.number().int().min(1).max(31).nullable().optional(),
});

export const UpdateAccountSchema = z.object({
  nombre: z.string().min(2).max(80).optional(),
  saldo_inicial: z.number().optional(),
  limite_credito: z.number().positive().nullable().optional(),
  dia_corte: z.number().int().min(1).max(31).nullable().optional(),
  dia_pago: z.number().int().min(1).max(31).nullable().optional(),
  archivada: z.boolean().optional(),
});

// ============================================================================
// DTOs de Transacciones Financieras (RF-TRX)
// ============================================================================

export const CreateTransactionSchema = z.object({
  cuenta_id: z.string().uuid('ID de cuenta inválido'),
  categoria_id: z.string().uuid('ID de categoría inválido').nullable().optional(),
  tipo: z.enum(['ingreso', 'gasto', 'transferencia', 'ajuste', 'aporte_meta']),
  sentido: z.enum(['entrada', 'salida']).optional(),
  monto: z.number().positive('El monto debe ser estrictamente mayor que 0'),
  fecha: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Formato de fecha inválido (debe ser AAAA-MM-DD)'),
  descripcion: z.string().max(200).optional(),
  nota: z.string().max(500).optional(),
});

export const CreateTransferSchema = z.object({
  cuenta_origen_id: z.string().uuid('ID de cuenta origen inválido'),
  cuenta_destino_id: z.string().uuid('ID de cuenta destino inválido'),
  monto: z.number().positive('El monto a transferir debe ser mayor que 0'),
  fecha: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Formato de fecha inválido (debe ser AAAA-MM-DD)'),
  descripcion: z.string().max(200).optional(),
});

export const UpdateTransactionSchema = z.object({
  categoria_id: z.string().uuid('ID de categoría inválido').nullable().optional(),
  monto: z.number().positive('El monto debe ser mayor que 0').optional(),
  fecha: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Formato de fecha inválido (debe ser AAAA-MM-DD)').optional(),
  descripcion: z.string().max(200).optional(),
  nota: z.string().max(500).optional(),
});

export const TransactionQuerySchema = z.object({
  cuenta_id: z.string().uuid().optional(),
  categoria_id: z.string().uuid().optional(),
  tipo: z.enum(['ingreso', 'gasto', 'transferencia', 'ajuste', 'aporte_meta']).optional(),
  fecha_inicio: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  fecha_fin: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  busqueda: z.string().optional(),
  limit: z.coerce.number().int().positive().optional().default(20),
  offset: z.coerce.number().int().nonnegative().optional().default(0),
});
