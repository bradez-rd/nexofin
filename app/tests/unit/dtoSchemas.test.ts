import {
  CreateAccountSchema,
  CreateTransactionSchema,
  CreateTransferSchema,
  RegisterSchema,
  TransactionQuerySchema,
} from '../../src/api/dtos/index.js';

const UUID_A = '11111111-1111-4111-8111-111111111111';
const UUID_B = '22222222-2222-4222-8222-222222222222';

/**
 * Pruebas unitarias de las validaciones de entrada (Zod). Son la primera barrera contra datos
 * inválidos (RNF-DAT-01, RNF-SEG-08) y se ejecutan antes de llegar a la capa de aplicación.
 */
describe('Validaciones de entrada (DTOs Zod) - pruebas unitarias', () => {
  describe('RegisterSchema (RF-AUT-01, RN-SEG-01)', () => {
    const valid = { nombre: 'Paola Piantini', email: 'paola@itla.edu.do', password: 'ClaveSegura2026' };

    it('UT-20 · acepta datos válidos y completa moneda DOP y zona America/Santo_Domingo', () => {
      const parsed = RegisterSchema.parse(valid);
      expect(parsed.moneda_predeterminada).toBe('DOP');
      expect(parsed.zona_horaria).toBe('America/Santo_Domingo');
    });

    it('UT-21 · rechaza contraseñas de 9 caracteres y acepta las de 10', () => {
      expect(RegisterSchema.safeParse({ ...valid, password: '123456789' }).success).toBe(false);
      expect(RegisterSchema.safeParse({ ...valid, password: '1234567890' }).success).toBe(true);
    });

    it('UT-22 · rechaza correos con formato inválido y nombres de un carácter', () => {
      expect(RegisterSchema.safeParse({ ...valid, email: 'correo-sin-arroba' }).success).toBe(false);
      expect(RegisterSchema.safeParse({ ...valid, nombre: 'P' }).success).toBe(false);
    });
  });

  describe('CreateTransactionSchema (RF-TRX-01, RNF-DAT-01)', () => {
    const valid = { cuenta_id: UUID_A, tipo: 'gasto', monto: 1500, fecha: '2026-10-26' };

    it('UT-23 · acepta una transacción válida', () => {
      expect(CreateTransactionSchema.safeParse(valid).success).toBe(true);
    });

    it('UT-24 · rechaza monto cero o negativo (el monto se ingresa siempre positivo)', () => {
      expect(CreateTransactionSchema.safeParse({ ...valid, monto: 0 }).success).toBe(false);
      expect(CreateTransactionSchema.safeParse({ ...valid, monto: -50 }).success).toBe(false);
    });

    it('UT-25 · rechaza fechas con formato inválido y tipos desconocidos', () => {
      expect(CreateTransactionSchema.safeParse({ ...valid, fecha: '26/10/2026' }).success).toBe(false);
      expect(CreateTransactionSchema.safeParse({ ...valid, tipo: 'regalo' }).success).toBe(false);
    });

    it('UT-26 · rechaza una cuenta que no es un UUID', () => {
      expect(CreateTransactionSchema.safeParse({ ...valid, cuenta_id: 'abc' }).success).toBe(false);
    });
  });

  describe('CreateTransferSchema (RF-TRX-02)', () => {
    const valid = { cuenta_origen_id: UUID_A, cuenta_destino_id: UUID_B, monto: 500, fecha: '2026-10-26' };

    it('UT-27 · acepta una transferencia válida y rechaza monto cero', () => {
      expect(CreateTransferSchema.safeParse(valid).success).toBe(true);
      expect(CreateTransferSchema.safeParse({ ...valid, monto: 0 }).success).toBe(false);
    });
  });

  describe('CreateAccountSchema (RF-CTA-01, RF-CTA-02)', () => {
    it('UT-28 · acepta una tarjeta con límite, corte y pago, y usa DOP por defecto', () => {
      const parsed = CreateAccountSchema.parse({
        nombre: 'Visa Popular',
        tipo: 'tarjeta',
        limite_credito: 80000,
        dia_corte: 25,
        dia_pago: 15,
      });
      expect(parsed.moneda).toBe('DOP');
      expect(parsed.saldo_inicial).toBe(0);
    });

    it('UT-29 · rechaza tipo inválido, día de corte fuera de 1-31 y límite no positivo', () => {
      expect(CreateAccountSchema.safeParse({ nombre: 'X1', tipo: 'cripto' }).success).toBe(false);
      expect(CreateAccountSchema.safeParse({ nombre: 'Visa', tipo: 'tarjeta', dia_corte: 32 }).success).toBe(false);
      expect(CreateAccountSchema.safeParse({ nombre: 'Visa', tipo: 'tarjeta', limite_credito: 0 }).success).toBe(false);
    });
  });

  describe('TransactionQuerySchema (RF-TRX-05)', () => {
    it('UT-30 · convierte limit/offset de texto a número y aplica valores por defecto', () => {
      expect(TransactionQuerySchema.parse({ limit: '10', offset: '5' })).toMatchObject({ limit: 10, offset: 5 });
      expect(TransactionQuerySchema.parse({})).toMatchObject({ limit: 20, offset: 0 });
    });

    it('UT-31 · rechaza un tipo de filtro desconocido y fechas con formato inválido', () => {
      expect(TransactionQuerySchema.safeParse({ tipo: 'otro' }).success).toBe(false);
      expect(TransactionQuerySchema.safeParse({ fecha_inicio: '2026/10/01' }).success).toBe(false);
    });
  });
});
