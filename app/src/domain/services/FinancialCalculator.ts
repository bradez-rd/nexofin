import crypto from 'crypto';

export class FinancialCalculator {
  /**
   * Redondea un importe monetario a exactamente 2 decimales según RN-DAT-01.
   * Evita errores de punto flotante en cálculos acumulativos.
   */
  public static roundMoney(amount: number): number {
    return Math.round((amount + Number.EPSILON) * 100) / 100;
  }

  /**
   * Genera la huella criptográfica SHA-256 única para detección de duplicados (RN-TRX-01 / RF-IMP).
   * huella = sha256(cuenta_id + '|' + fecha + '|' + monto_formateado + '|' + descripcion_normalizada)
   */
  public static generateFingerprint(
    cuentaId: string,
    fecha: string,
    monto: number,
    descripcion: string = ''
  ): string {
    const normalizedDesc = descripcion.trim().toLowerCase().replace(/\s+/g, ' ');
    const normalizedAmount = this.roundMoney(monto).toFixed(2);
    const raw = `${cuentaId}|${fecha}|${normalizedAmount}|${normalizedDesc}`;
    return crypto.createHash('sha256').update(raw).digest('hex');
  }

  /**
   * Determina el sentido financiero (entrada o salida) a partir del tipo de transacción.
   */
  public static getDirectionFromType(
    tipo: 'ingreso' | 'gasto' | 'transferencia' | 'ajuste' | 'aporte_meta',
    explicitDirection?: 'entrada' | 'salida'
  ): 'entrada' | 'salida' {
    if (tipo === 'ingreso') return 'entrada';
    if (tipo === 'gasto' || tipo === 'aporte_meta') return 'salida';
    if (explicitDirection) return explicitDirection;
    return 'salida';
  }

  /**
   * Calcula el saldo derivado determinísticamente a partir del saldo inicial y movimientos.
   */
  public static calculateAccountBalance(
    saldoInicial: number,
    totalEntradas: number,
    totalSalidas: number
  ): number {
    return this.roundMoney(saldoInicial + totalEntradas - totalSalidas);
  }
}
