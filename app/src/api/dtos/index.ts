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
  codigo_2fa: z.string().regex(/^\d{6}$/, 'El código debe tener 6 dígitos').optional(),
});

export const ForgotPasswordSchema = z.object({ email: z.string().email('Debe ser un correo electrónico válido') });
export const ResetPasswordSchema = z.object({
  token: z.string().min(20),
  password: z.string().min(10, 'La contraseña debe tener al menos 10 caracteres'),
});
export const ChangePasswordSchema = z.object({
  password_actual: z.string().min(1, 'Indica tu contraseña actual'),
  password_nueva: z.string().min(10, 'La contraseña debe tener al menos 10 caracteres'),
});
export const VerifyEmailSchema = z.object({ token: z.string().min(20) });
export const TwoFactorEnableSchema = z.object({ codigo: z.string().regex(/^\d{6}$/, 'El código debe tener 6 dígitos') });
export const PasswordConfirmSchema = z.object({ password: z.string().min(1, 'Indica tu contraseña') });
export const DeleteAccountSchema = z.object({ password: z.string().min(1), confirmacion: z.string() });
export const ConsentSchema = z.object({ otorgado: z.boolean() });

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

// ============================================================================
// DTOs de deudas, recurrentes, presupuestos y metas (RF-CTA, RF-TRX-06, RF-PRE)
// ============================================================================

const dateStr = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Formato de fecha inválido (debe ser AAAA-MM-DD)');
const monthStr = z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/, 'El mes debe tener el formato AAAA-MM');

export const CreateDebtSchema = z.object({
  acreedor: z.string().min(2, 'Indica el acreedor').max(100),
  monto_original: z.number().positive('El monto debe ser mayor que 0'),
  tasa_anual: z.number().min(0).max(1000).optional().default(0),
  num_cuotas: z.number().int().min(1).max(600),
  fecha_primera_cuota: dateStr,
});

export const PayDebtSchema = z.object({
  monto: z.number().positive('El monto debe ser mayor que 0'),
  fecha: dateStr,
  cuenta_id: z.string().uuid('ID de cuenta inválido'),
});

const FrequencyEnum = z.enum(['semanal', 'quincenal', 'mensual', 'anual']);

export const CreateRecurringSchema = z.object({
  cuenta_id: z.string().uuid(),
  categoria_id: z.string().uuid().nullable().optional(),
  tipo: z.enum(['ingreso', 'gasto']),
  monto: z.number().positive('El monto debe ser mayor que 0'),
  descripcion: z.string().min(2).max(200),
  frecuencia: FrequencyEnum,
  fecha_inicio: dateStr,
  fecha_fin: dateStr.nullable().optional(),
});

export const UpdateRecurringSchema = z.object({
  monto: z.number().positive().optional(),
  descripcion: z.string().min(2).max(200).optional(),
  categoria_id: z.string().uuid().nullable().optional(),
  fecha_fin: dateStr.nullable().optional(),
  frecuencia: FrequencyEnum.optional(),
  estado: z.enum(['activa', 'pausada', 'finalizada']).optional(),
});

export const CreateBudgetSchema = z.object({
  categoria_id: z.string().uuid(),
  mes: monthStr,
  monto_limite: z.number().positive('El monto debe ser mayor que 0'),
  umbral_alerta: z.number().gt(0).max(1).optional(),
});

export const UpdateBudgetSchema = z.object({
  monto_limite: z.number().positive().optional(),
  umbral_alerta: z.number().gt(0).max(1).optional(),
});

export const CreateGoalSchema = z.object({
  nombre: z.string().min(2).max(100),
  monto_objetivo: z.number().positive('El monto objetivo debe ser mayor que 0'),
  fecha_limite: dateStr,
  cuenta_id: z.string().uuid().nullable().optional(),
});

export const UpdateGoalSchema = z.object({
  nombre: z.string().min(2).max(100).optional(),
  monto_objetivo: z.number().positive().optional(),
  fecha_limite: dateStr.optional(),
  estado: z.enum(['activa', 'pausada', 'cerrada']).optional(),
});

export const ContributeGoalSchema = z.object({
  monto: z.number().positive('El monto debe ser mayor que 0'),
  fecha: dateStr,
  cuenta_id: z.string().uuid(),
});

export const CreateRuleSchema = z.object({
  texto_contiene: z.string().min(2).max(100),
  categoria_id: z.string().uuid(),
  prioridad: z.number().int().min(0).max(100).optional(),
});

export const UpdateRuleSchema = z.object({
  texto_contiene: z.string().min(2).max(100).optional(),
  categoria_id: z.string().uuid().optional(),
  prioridad: z.number().int().min(0).max(100).optional(),
  activa: z.boolean().optional(),
});

export const CategorizeSchema = z.object({
  categoria_id: z.string().uuid(),
  crear_regla: z.boolean().optional().default(false),
});

export const UpdateCategorySchema = z.object({
  nombre: z.string().min(2).max(60).optional(),
  icono: z.string().max(50).optional(),
  color: z.string().max(20).optional(),
  archivada: z.boolean().optional(),
});

export const NotificationPrefSchema = z.object({
  canal_app: z.boolean(),
  canal_correo: z.boolean().optional().default(false),
});

// ============================================================================
// DTOs del simulador (RF-SIM)
// ============================================================================

export const SimulateExpenseSchema = z.object({
  monto: z.number().positive('El monto debe ser mayor que 0'),
  categoria_id: z.string().uuid().nullable().optional(),
  fecha: dateStr.optional(),
  horizonte_meses: z.number().int().min(1).max(12).optional(),
  guardar: z.boolean().optional().default(false),
});

export const SimulateSavingSchema = z.object({
  monto_objetivo: z.number().positive('El monto objetivo debe ser mayor que 0'),
  fecha_limite: dateStr,
  acumulado_actual: z.number().min(0).optional(),
  guardar: z.boolean().optional().default(false),
});

export const SimulateInstallmentsSchema = z.object({
  monto: z.number().positive('El monto debe ser mayor que 0'),
  tasa_anual: z.number().min(0).max(1000),
  num_cuotas: z.number().int().min(1).max(600),
  guardar: z.boolean().optional().default(false),
});

export const CompareSimulationsSchema = z.object({
  ids: z.array(z.string().uuid()).min(2).max(3),
});

export const AssistantMessageSchema = z.object({
  mensaje: z.string().min(1, 'Escribe tu pregunta').max(1000),
  conversacion_id: z.string().uuid().optional(),
});

// ============================================================================
// DTOs de importación de estados de cuenta (RF-IMP)
// ============================================================================

const MappingSchema = z.object({
  fecha: z.number().int().min(0),
  descripcion: z.number().int().min(0),
  monto: z.number().int().min(0).optional(),
  debito: z.number().int().min(0).optional(),
  credito: z.number().int().min(0).optional(),
  tipo: z.number().int().min(0).optional(),
});

export const UploadImportSchema = z.object({
  cuenta_id: z.string().uuid('ID de cuenta inválido'),
  nombre_archivo: z.string().min(3).max(255),
  contenido_base64: z.string().min(4, 'El archivo está vacío'),
  mapeo: MappingSchema.optional(),
  guardar_mapeo: z.boolean().optional(),
});

export const UpdateImportMovementSchema = z.object({
  decision: z.enum(['aprobado', 'excluido']).optional(),
  fecha: dateStr.optional(),
  monto: z.number().positive().optional(),
  descripcion: z.string().min(1).max(300).optional(),
  categoria_id: z.string().uuid().nullable().optional(),
});
