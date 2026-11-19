import { DateUtils } from './DateUtils.js';

export type Frequency = 'semanal' | 'quincenal' | 'mensual' | 'anual';

/**
 * Fechas en que debe ocurrir una transacción recurrente. La fecha k-ésima se calcula siempre
 * desde la fecha de inicio (no encadenando) para que un día 31 no "se corra" tras febrero.
 */
export class RecurrenceRules {
  public static occurrence(inicio: string, frecuencia: Frequency, k: number): string {
    switch (frecuencia) {
      case 'semanal':
        return DateUtils.addDays(inicio, 7 * k);
      case 'quincenal':
        return DateUtils.addDays(inicio, 15 * k);
      case 'mensual':
        return DateUtils.addMonths(inicio, k, DateUtils.parse(inicio).d);
      case 'anual':
        return DateUtils.addMonths(inicio, 12 * k, DateUtils.parse(inicio).d);
    }
  }

  /** Ocurrencias en el rango (desde, hasta] limitadas por la fecha de fin opcional. */
  public static between(
    inicio: string,
    frecuencia: Frequency,
    afterExclusive: string | null,
    untilInclusive: string,
    fin?: string | null,
    maxItems = 400
  ): string[] {
    const out: string[] = [];
    for (let k = 0; k < maxItems; k++) {
      const f = this.occurrence(inicio, frecuencia, k);
      if (f > untilInclusive) break;
      if (fin && f > fin) break;
      if (afterExclusive && f <= afterExclusive) continue;
      out.push(f);
    }
    return out;
  }

  /** Equivalente mensual aproximado de un monto recurrente (para proyecciones). */
  public static monthlyEquivalent(monto: number, frecuencia: Frequency): number {
    switch (frecuencia) {
      case 'semanal':
        return (monto * 52) / 12;
      case 'quincenal':
        return (monto * 365) / 15 / 12;
      case 'mensual':
        return monto;
      case 'anual':
        return monto / 12;
    }
  }
}
