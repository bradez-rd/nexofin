import { ValidationError } from '../errors/DomainError.js';

/**
 * Reglas de fechas del dominio (RN-TRX-02 y RN-DAT-03).
 * Una transacción manual debe tener una fecha real del calendario y no puede ser posterior a hoy,
 * donde "hoy" se evalúa en la zona horaria del usuario (America/Santo_Domingo por defecto).
 */
export class DateRules {
  /** Fecha de hoy (AAAA-MM-DD) en la zona horaria indicada. */
  public static todayIn(timeZone: string, now: Date = new Date()): string {
    return now.toLocaleDateString('en-CA', { timeZone });
  }

  /** Indica si el texto AAAA-MM-DD es una fecha que existe en el calendario (rechaza 2026-02-30). */
  public static isRealDate(fecha: string): boolean {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(fecha);
    if (!match) return false;
    const [year, month, day] = [Number(match[1]), Number(match[2]), Number(match[3])];
    const d = new Date(Date.UTC(year, month - 1, day));
    return d.getUTCFullYear() === year && d.getUTCMonth() === month - 1 && d.getUTCDate() === day;
  }

  /** Lanza ValidationError si la fecha no existe o es posterior a hoy. */
  public static assertManualDate(fecha: string, timeZone: string, now: Date = new Date()): void {
    if (!this.isRealDate(fecha)) {
      throw new ValidationError('La fecha no existe en el calendario');
    }
    if (fecha > this.todayIn(timeZone, now)) {
      throw new ValidationError('La fecha de una transacción manual no puede ser posterior a hoy');
    }
  }
}
