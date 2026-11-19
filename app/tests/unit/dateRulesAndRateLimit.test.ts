import { DateRules } from '../../src/domain/services/DateRules.js';
import { rateLimit } from '../../src/api/middlewares/rateLimit.middleware.js';
import { TooManyRequestsError, ValidationError } from '../../src/domain/errors/DomainError.js';

/**
 * Reglas de fechas (RN-TRX-02, RN-DAT-03) y límite de intentos (RNF-SEG-06): pruebas unitarias.
 */
describe('DateRules - pruebas unitarias', () => {
  it('UT-34 · reconoce fechas reales y rechaza las que no existen (2026-02-30, 2026-13-01, 2025-02-29)', () => {
    expect(DateRules.isRealDate('2026-02-28')).toBe(true);
    expect(DateRules.isRealDate('2028-02-29')).toBe(true); // año bisiesto
    expect(DateRules.isRealDate('2026-02-30')).toBe(false);
    expect(DateRules.isRealDate('2026-13-01')).toBe(false);
    expect(DateRules.isRealDate('2025-02-29')).toBe(false);
    expect(DateRules.isRealDate('26/10/2026')).toBe(false);
  });

  it('UT-35 · "hoy" se calcula en la zona horaria del usuario, no en UTC', () => {
    // 27 oct 2026 01:30 UTC sigue siendo 26 oct a las 21:30 en Santo Domingo (UTC-4)
    const now = new Date('2026-10-27T01:30:00Z');
    expect(DateRules.todayIn('America/Santo_Domingo', now)).toBe('2026-10-26');
    expect(DateRules.todayIn('UTC', now)).toBe('2026-10-27');
  });

  it('UT-36 · acepta hoy y fechas pasadas, y rechaza fechas futuras o inexistentes', () => {
    const now = new Date('2026-10-26T15:00:00Z');
    const tz = 'America/Santo_Domingo';
    expect(() => DateRules.assertManualDate('2026-10-26', tz, now)).not.toThrow();
    expect(() => DateRules.assertManualDate('2020-01-01', tz, now)).not.toThrow();
    expect(() => DateRules.assertManualDate('2026-10-27', tz, now)).toThrow(ValidationError);
    expect(() => DateRules.assertManualDate('2026-02-30', tz, now)).toThrow(ValidationError);
  });
});

describe('rateLimit - pruebas unitarias', () => {
  const run = (limiter: ReturnType<typeof rateLimit>, ip = '10.0.0.1') => {
    let error: unknown;
    const req: any = { ip, socket: {} };
    const res: any = { setHeader: jest.fn() };
    limiter(req, res, (err?: unknown) => {
      error = err;
    });
    return { error, res };
  };

  it('UT-37 · permite hasta el máximo y bloquea el siguiente intento con error 429', () => {
    const limiter = rateLimit({ windowMs: 60000, max: 3 });
    for (let i = 0; i < 3; i++) expect(run(limiter).error).toBeUndefined();
    const blocked = run(limiter);
    expect(blocked.error).toBeInstanceOf(TooManyRequestsError);
    expect((blocked.error as TooManyRequestsError).statusCode).toBe(429);
    expect(blocked.res.setHeader).toHaveBeenCalledWith('Retry-After', expect.any(String));
  });

  it('UT-38 · cuenta cada origen por separado y reinicia el contador al terminar la ventana', () => {
    jest.useFakeTimers();
    try {
      const limiter = rateLimit({ windowMs: 1000, max: 1 });
      expect(run(limiter, '10.0.0.1').error).toBeUndefined();
      expect(run(limiter, '10.0.0.1').error).toBeInstanceOf(TooManyRequestsError);
      expect(run(limiter, '10.0.0.2').error).toBeUndefined(); // otro origen no se ve afectado
      jest.advanceTimersByTime(1500);
      expect(run(limiter, '10.0.0.1').error).toBeUndefined(); // ventana nueva
    } finally {
      jest.useRealTimers();
    }
  });
});
