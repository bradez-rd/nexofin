import { db } from '../../infrastructure/database/db.js';
import { FinancialSnapshot, RecurringItem } from '../../domain/services/SimulationEngine.js';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';
import { DateUtils } from '../../domain/services/DateUtils.js';
import { BudgetService } from '../budgets/BudgetService.js';
import { DebtService } from '../debts/DebtService.js';
import { GoalService } from '../goals/GoalService.js';
import { RecurringService } from '../recurring/RecurringService.js';

const r2 = (n: number) => FinancialCalculator.roundMoney(n);

/** Reúne los datos persistidos del usuario en un snapshot que el motor de simulación consume. */
export class SnapshotService {
  constructor(
    private readonly budgets = new BudgetService(),
    private readonly debts = new DebtService(),
    private readonly goals = new GoalService(),
    private readonly recurring = new RecurringService()
  ) {}

  public async build(userId: string, hoy: string, mesesPresupuesto: string[] = [hoy.slice(0, 7)]): Promise<FinancialSnapshot> {
    // Mantiene al día las transacciones recurrentes antes de leer los saldos
    await this.recurring.generateDue(userId, hoy);

    const acc = await db.query<any>(
      `SELECT c.tipo, c.moneda, COALESCE(v.saldo_actual, c.saldo_inicial) AS saldo
       FROM cuenta c LEFT JOIN vista_saldo_cuenta v ON v.cuenta_id = c.id
       WHERE c.usuario_id = $1 AND c.archivada = FALSE`,
      [userId]
    );
    let disponible = 0;
    let tarjetas = 0;
    for (const a of acc.rows) {
      const saldo = Number(a.saldo);
      if (a.tipo === 'tarjeta') tarjetas += Math.max(0, -saldo);
      else disponible += saldo;
    }

    const desde = DateUtils.addDays(hoy, -90);
    const tx = await db.query<any>(
      `SELECT t.tipo, t.monto, t.categoria_id, c.nombre AS categoria
       FROM transaccion t LEFT JOIN categoria c ON c.id = t.categoria_id
       WHERE t.usuario_id = $1 AND t.eliminada = FALSE AND t.fecha >= $2 AND t.fecha <= $3
         AND t.tipo IN ('ingreso','gasto')`,
      [userId, desde, hoy]
    );
    let ingresos = 0;
    let gastos = 0;
    const porCategoria = new Map<string, { nombre: string; total: number }>();
    for (const t of tx.rows) {
      const m = Number(t.monto);
      if (t.tipo === 'ingreso') ingresos += m;
      else {
        gastos += m;
        if (t.categoria_id) {
          const cur = porCategoria.get(t.categoria_id) ?? { nombre: t.categoria, total: 0 };
          cur.total += m;
          porCategoria.set(t.categoria_id, cur);
        }
      }
    }

    const rec = await db.query<any>(
      `SELECT tipo, descripcion, monto, frecuencia, fecha_inicio, fecha_fin FROM transaccion_recurrente
       WHERE usuario_id = $1 AND estado = 'activa'`,
      [userId]
    );
    const toItem = (r: any): RecurringItem => ({
      descripcion: r.descripcion,
      monto: Number(r.monto),
      frecuencia: r.frecuencia,
      fecha_inicio: DateUtils.toDateStr(r.fecha_inicio),
      fecha_fin: r.fecha_fin ? DateUtils.toDateStr(r.fecha_fin) : null,
    });

    const cuotas = await db.query<any>(
      `SELECT c.vencimiento, c.monto, c.monto_pagado, d.acreedor FROM cuota_deuda c
       JOIN deuda d ON d.id = c.deuda_id WHERE d.usuario_id = $1 AND d.estado = 'activa' AND c.estado != 'pagada'`,
      [userId]
    );

    const metas = (await this.goals.list(userId)).filter((g) => g.estado === 'activa');
    const presupuestos = [];
    for (const mes of mesesPresupuesto) {
      for (const b of await this.budgets.list(userId, mes)) {
        presupuestos.push({
          categoria_id: b.categoria_id,
          categoria_nombre: b.categoria_nombre,
          mes: b.mes,
          monto_limite: b.monto_limite,
          consumido: b.consumido,
        });
      }
    }

    return {
      hoy,
      moneda: 'DOP',
      saldo_disponible: r2(disponible),
      deuda_tarjetas: r2(tarjetas),
      deuda_prestamos: await this.debts.totalOutstanding(userId),
      num_cuentas: acc.rowCount,
      num_transacciones_90d: tx.rowCount,
      ingresos_promedio_mensual_90d: r2(ingresos / 3),
      gasto_promedio_mensual_90d: r2(gastos / 3),
      recurrentes_ingreso: rec.rows.filter((r) => r.tipo === 'ingreso').map(toItem),
      recurrentes_gasto: rec.rows.filter((r) => r.tipo === 'gasto').map(toItem),
      cuotas_pendientes: cuotas.rows.map((c) => ({
        vencimiento: DateUtils.toDateStr(c.vencimiento),
        monto: r2(Number(c.monto) - Number(c.monto_pagado)),
        acreedor: c.acreedor,
      })),
      metas: metas.map((g) => ({ id: g.id, nombre: g.nombre, monto_mensual_necesario: g.monto_mensual_necesario })),
      presupuestos,
      gasto_por_categoria_90d: [...porCategoria.entries()].map(([id, v]) => ({
        categoria_id: id,
        nombre: v.nombre,
        promedio_mensual: r2(v.total / 3),
      })),
    };
  }
}
