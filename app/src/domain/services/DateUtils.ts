/**
 * Utilidades de fechas calendario (AAAA-MM-DD) sin dependencia de la zona horaria del servidor.
 * Todas las operaciones trabajan en UTC sobre fechas "de pared".
 */
export class DateUtils {
  /** Convierte lo que devuelve el driver (Date o texto) a AAAA-MM-DD. */
  public static toDateStr(value: unknown): string {
    if (value instanceof Date) {
      // pg-mem entrega las fechas a medianoche UTC y el driver pg a medianoche local: se
      // interpreta cada una con sus propios getters para no correr el día según la zona horaria.
      const utcMidnight =
        value.getUTCHours() === 0 && value.getUTCMinutes() === 0 && value.getUTCSeconds() === 0;
      const y = utcMidnight ? value.getUTCFullYear() : value.getFullYear();
      const m = String((utcMidnight ? value.getUTCMonth() : value.getMonth()) + 1).padStart(2, '0');
      const d = String(utcMidnight ? value.getUTCDate() : value.getDate()).padStart(2, '0');
      return `${y}-${m}-${d}`;
    }
    return String(value).split('T')[0];
  }

  public static parse(fecha: string): { y: number; m: number; d: number } {
    const [y, m, d] = fecha.split('-').map(Number);
    return { y, m, d };
  }

  public static format(y: number, m: number, d: number): string {
    return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
  }

  public static daysInMonth(y: number, m: number): number {
    return new Date(Date.UTC(y, m, 0)).getUTCDate();
  }

  /** Suma meses conservando el día original cuando existe (31 ene + 1 mes = 28/29 feb). */
  public static addMonths(fecha: string, months: number, anchorDay?: number): string {
    const { y, m, d } = this.parse(fecha);
    const total = y * 12 + (m - 1) + months;
    const ny = Math.floor(total / 12);
    const nm = (total % 12) + 1;
    const day = Math.min(anchorDay ?? d, this.daysInMonth(ny, nm));
    return this.format(ny, nm, day);
  }

  public static addDays(fecha: string, days: number): string {
    const { y, m, d } = this.parse(fecha);
    const dt = new Date(Date.UTC(y, m - 1, d + days));
    return this.format(dt.getUTCFullYear(), dt.getUTCMonth() + 1, dt.getUTCDate());
  }

  public static addYears(fecha: string, years: number): string {
    return this.addMonths(fecha, years * 12);
  }

  public static diffDays(a: string, b: string): number {
    const pa = this.parse(a);
    const pb = this.parse(b);
    return Math.round((Date.UTC(pb.y, pb.m - 1, pb.d) - Date.UTC(pa.y, pa.m - 1, pa.d)) / 86400000);
  }

  /** Primer día del mes (AAAA-MM-01) de la fecha dada. */
  public static monthStart(fecha: string): string {
    const { y, m } = this.parse(fecha);
    return this.format(y, m, 1);
  }

  public static monthEnd(fecha: string): string {
    const { y, m } = this.parse(fecha);
    return this.format(y, m, this.daysInMonth(y, m));
  }

  /** Meses completos y parciales entre dos fechas, mínimo 1 (para repartir una meta). */
  public static monthsBetween(desde: string, hasta: string): number {
    const a = this.parse(desde);
    const b = this.parse(hasta);
    let months = (b.y - a.y) * 12 + (b.m - a.m);
    if (b.d > a.d) months += 1;
    return Math.max(1, months);
  }
}
