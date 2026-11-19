import { FinancialCalculator } from './FinancialCalculator.js';
import { DateUtils } from './DateUtils.js';
import { ValidationError } from '../errors/DomainError.js';

export interface Installment {
  numero: number;
  vencimiento: string;
  monto: number;
  capital: number;
  interes: number;
}

export interface LoanSummary {
  cuota: number;
  total_pagado: number;
  total_intereses: number;
}

/**
 * Cálculo de préstamos con el sistema francés (cuota fija). Los importes se redondean
 * half-up a dos decimales (RN-DAT-01) y la última cuota absorbe la diferencia de redondeo
 * para que la suma de capital sea exactamente el monto original.
 */
export class LoanCalculator {
  public static schedule(
    principal: number,
    tasaAnualPct: number,
    numCuotas: number,
    primeraCuota: string
  ): Installment[] {
    if (!(principal > 0)) throw new ValidationError('El monto debe ser mayor que cero');
    if (!Number.isInteger(numCuotas) || numCuotas < 1) {
      throw new ValidationError('El número de cuotas debe ser un entero positivo');
    }
    if (tasaAnualPct < 0) throw new ValidationError('La tasa no puede ser negativa');

    const r = tasaAnualPct / 100 / 12;
    const cuotaBase =
      r === 0 ? principal / numCuotas : (principal * r) / (1 - Math.pow(1 + r, -numCuotas));
    const cuota = FinancialCalculator.roundMoney(cuotaBase);
    const anchor = DateUtils.parse(primeraCuota).d;

    const rows: Installment[] = [];
    let saldo = FinancialCalculator.roundMoney(principal);
    for (let n = 1; n <= numCuotas; n++) {
      const interes = FinancialCalculator.roundMoney(saldo * r);
      let capital = FinancialCalculator.roundMoney(cuota - interes);
      let monto = cuota;
      if (n === numCuotas || capital > saldo) {
        capital = saldo;
        monto = FinancialCalculator.roundMoney(capital + interes);
      }
      saldo = FinancialCalculator.roundMoney(saldo - capital);
      rows.push({
        numero: n,
        vencimiento: DateUtils.addMonths(primeraCuota, n - 1, anchor),
        monto,
        capital,
        interes,
      });
    }
    return rows;
  }

  public static summary(principal: number, tasaAnualPct: number, numCuotas: number): LoanSummary {
    const rows = this.schedule(principal, tasaAnualPct, numCuotas, '2000-01-01');
    const total = FinancialCalculator.roundMoney(rows.reduce((s, r) => s + r.monto, 0));
    return {
      cuota: rows[0].monto,
      total_pagado: total,
      total_intereses: FinancialCalculator.roundMoney(total - principal),
    };
  }
}
