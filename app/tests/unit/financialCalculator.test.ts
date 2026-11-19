import { FinancialCalculator } from '../../src/domain/services/FinancialCalculator.js';

/**
 * Pruebas unitarias del núcleo financiero (capa domain, sin base de datos).
 * Reglas del SRS: RN-DAT-01 (redondeo), RN-CTA-01 (saldo), RN-TRX-01 (sentido del movimiento)
 * y RN-IMP-02 (huella para detectar duplicados).
 */
describe('FinancialCalculator - pruebas unitarias', () => {
  describe('roundMoney (RN-DAT-01, RNF-DAT-02)', () => {
    it('UT-01 · redondea a 2 decimales y evita el error de punto flotante (0.1 + 0.2 = 0.30)', () => {
      expect(FinancialCalculator.roundMoney(0.1 + 0.2)).toBe(0.3);
      expect(FinancialCalculator.roundMoney(1234.5678)).toBe(1234.57);
      expect(FinancialCalculator.roundMoney(100)).toBe(100);
    });

    it('UT-02 · aplica "mitad hacia arriba": 0.005 -> 0.01, 2.345 -> 2.35', () => {
      expect(FinancialCalculator.roundMoney(0.005)).toBe(0.01);
      expect(FinancialCalculator.roundMoney(2.345)).toBe(2.35);
    });

    it('UT-03 · aplica "mitad hacia arriba" en montos que la coma flotante representa por debajo (2.135, 2.175, 4.015)', () => {
      expect(FinancialCalculator.roundMoney(1.005)).toBe(1.01);
      expect(FinancialCalculator.roundMoney(10.005)).toBe(10.01);
      expect(FinancialCalculator.roundMoney(2.135)).toBe(2.14);
      expect(FinancialCalculator.roundMoney(2.175)).toBe(2.18);
      expect(FinancialCalculator.roundMoney(4.015)).toBe(4.02);
    });

    it('UT-32 · barrido: todo monto con 5 en la tercera cifra decimal sube al siguiente centavo (14,000 casos)', () => {
      const failures: number[] = [];
      for (const base of [1, 100, 10000, 100000, 1000000, 5000000, 10000000]) {
        for (let c = 0; c < 2000; c++) {
          const cents = base * 100 + c;
          const amount = (cents * 10 + 5) / 1000; // p. ej. 2.135
          const expected = (cents + 1) / 100;
          if (Math.abs(FinancialCalculator.roundMoney(amount) - expected) > 1e-9) failures.push(amount);
        }
      }
      expect(failures.slice(0, 5)).toEqual([]);
      expect(failures.length).toBe(0);
    });

    it('UT-33 · montos negativos se redondean de forma simétrica y nunca devuelven -0', () => {
      expect(FinancialCalculator.roundMoney(-2.135)).toBe(-2.14);
      expect(FinancialCalculator.roundMoney(-0.001)).toBe(0);
      expect(Object.is(FinancialCalculator.roundMoney(-0.001), -0)).toBe(false);
    });
  });

  describe('calculateAccountBalance (RN-CTA-01)', () => {
    it('UT-04 · saldo = inicial + entradas - salidas (caso de la evidencia del Entregable 3: RD$ 75,800.00)', () => {
      expect(FinancialCalculator.calculateAccountBalance(45000, 38500, 7700)).toBe(75800);
    });

    it('UT-05 · conserva exactitud con centavos (5,000 - 2,450.75 + 3,500 = 6,049.25)', () => {
      expect(FinancialCalculator.calculateAccountBalance(5000, 3500, 2450.75)).toBe(6049.25);
    });

    it('UT-06 · una tarjeta con deuda produce saldo negativo', () => {
      expect(FinancialCalculator.calculateAccountBalance(0, 0, 8700)).toBe(-8700);
    });
  });

  describe('getDirectionFromType (RN-TRX-01)', () => {
    it('UT-07 · ingreso suma; gasto y aporte a meta restan', () => {
      expect(FinancialCalculator.getDirectionFromType('ingreso')).toBe('entrada');
      expect(FinancialCalculator.getDirectionFromType('gasto')).toBe('salida');
      expect(FinancialCalculator.getDirectionFromType('aporte_meta')).toBe('salida');
    });

    it('UT-08 · un ajuste usa el sentido que elige el usuario', () => {
      expect(FinancialCalculator.getDirectionFromType('ajuste', 'entrada')).toBe('entrada');
      expect(FinancialCalculator.getDirectionFromType('ajuste', 'salida')).toBe('salida');
    });

    it('UT-09 · el tipo ingreso no puede ser invertido por un sentido explícito', () => {
      expect(FinancialCalculator.getDirectionFromType('ingreso', 'salida')).toBe('entrada');
      expect(FinancialCalculator.getDirectionFromType('gasto', 'entrada')).toBe('salida');
    });
  });

  describe('generateFingerprint (RN-IMP-02)', () => {
    const base = ['cuenta-1', '2026-10-26', 1500, 'Supermercado Bravo'] as const;

    it('UT-10 · produce un SHA-256 de 64 caracteres hexadecimales', () => {
      expect(FinancialCalculator.generateFingerprint(...base)).toMatch(/^[a-f0-9]{64}$/);
    });

    it('UT-11 · es determinística y no distingue mayúsculas ni espacios repetidos', () => {
      const a = FinancialCalculator.generateFingerprint(...base);
      const b = FinancialCalculator.generateFingerprint('cuenta-1', '2026-10-26', 1500, '  SUPERMERCADO   bravo ');
      expect(b).toBe(a);
    });

    it('UT-12 · cambia si varía la cuenta, la fecha, el monto o la descripción', () => {
      const a = FinancialCalculator.generateFingerprint(...base);
      expect(FinancialCalculator.generateFingerprint('cuenta-2', '2026-10-26', 1500, 'Supermercado Bravo')).not.toBe(a);
      expect(FinancialCalculator.generateFingerprint('cuenta-1', '2026-10-27', 1500, 'Supermercado Bravo')).not.toBe(a);
      expect(FinancialCalculator.generateFingerprint('cuenta-1', '2026-10-26', 1500.01, 'Supermercado Bravo')).not.toBe(a);
      expect(FinancialCalculator.generateFingerprint('cuenta-1', '2026-10-26', 1500, 'Farmacia')).not.toBe(a);
    });
  });
});
