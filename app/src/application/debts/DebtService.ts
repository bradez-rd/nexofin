import { db } from '../../infrastructure/database/db.js';
import { insertLedgerEntry, SYSTEM_CATEGORY } from '../../infrastructure/repositories/LedgerWriter.js';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';
import { LoanCalculator } from '../../domain/services/LoanCalculator.js';
import { RecurrenceRules, Frequency } from '../../domain/services/RecurrenceRules.js';
import { DateUtils } from '../../domain/services/DateUtils.js';
import { DateRules } from '../../domain/services/DateRules.js';
import { NotFoundError, ValidationError } from '../../domain/errors/DomainError.js';
import { env } from '../../config/env.js';

export interface DebtStatus {
  id: string;
  acreedor: string;
  monto_original: number;
  tasa_anual: number;
  num_cuotas: number;
  fecha_primera_cuota: string;
  estado: 'activa' | 'saldada';
  saldo_pendiente: number;
  capital_pendiente: number;
  cuotas_restantes: number;
  proxima_cuota: { numero: number; vencimiento: string; monto_pendiente: number } | null;
}

export interface CalendarItem {
  fecha: string;
  tipo: 'cuota_deuda' | 'pago_tarjeta' | 'recurrente_gasto';
  descripcion: string;
  monto: number | null;
}

/** Deudas, calendario de cuotas y pagos atómicos (RF-CTA-06/07/08/09). */
export class DebtService {
  private async statusOf(row: any): Promise<DebtStatus> {
    const cuotas = await db.query<any>(
      `SELECT numero, vencimiento, monto, capital, monto_pagado, estado FROM cuota_deuda
       WHERE deuda_id = $1 ORDER BY numero ASC`,
      [row.id]
    );
    let saldo = 0;
    let capital = 0;
    let restantes = 0;
    let proxima: DebtStatus['proxima_cuota'] = null;
    for (const c of cuotas.rows) {
      const pendiente = FinancialCalculator.roundMoney(Number(c.monto) - Number(c.monto_pagado));
      saldo += pendiente;
      capital += Number(c.capital) * (pendiente / Number(c.monto));
      if (c.estado !== 'pagada') {
        restantes++;
        if (!proxima) {
          proxima = { numero: Number(c.numero), vencimiento: DateUtils.toDateStr(c.vencimiento), monto_pendiente: pendiente };
        }
      }
    }
    return {
      id: row.id,
      acreedor: row.acreedor,
      monto_original: Number(row.monto_original),
      tasa_anual: Number(row.tasa_anual),
      num_cuotas: Number(row.num_cuotas),
      fecha_primera_cuota: DateUtils.toDateStr(row.fecha_primera_cuota),
      estado: row.estado,
      saldo_pendiente: FinancialCalculator.roundMoney(saldo),
      capital_pendiente: FinancialCalculator.roundMoney(capital),
      cuotas_restantes: restantes,
      proxima_cuota: proxima,
    };
  }

  public async create(
    userId: string,
    data: { acreedor: string; monto_original: number; tasa_anual?: number; num_cuotas: number; fecha_primera_cuota: string }
  ): Promise<{ deuda: DebtStatus; cuotas: ReturnType<typeof LoanCalculator.schedule> }> {
    if (!DateRules.isRealDate(data.fecha_primera_cuota)) throw new ValidationError('La fecha de la primera cuota no es válida');
    const monto = FinancialCalculator.roundMoney(data.monto_original);
    const schedule = LoanCalculator.schedule(monto, data.tasa_anual ?? 0, data.num_cuotas, data.fecha_primera_cuota);

    const client = await db.getClient();
    let debtRow: any;
    try {
      await client.query('BEGIN');
      const d = await client.query(
        `INSERT INTO deuda (usuario_id, acreedor, monto_original, tasa_anual, num_cuotas, fecha_primera_cuota)
         VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
        [userId, data.acreedor.trim(), monto, data.tasa_anual ?? 0, data.num_cuotas, data.fecha_primera_cuota]
      );
      debtRow = d.rows[0];
      for (const c of schedule) {
        await client.query(
          `INSERT INTO cuota_deuda (deuda_id, numero, vencimiento, monto, capital, interes) VALUES ($1,$2,$3,$4,$5,$6)`,
          [debtRow.id, c.numero, c.vencimiento, c.monto, c.capital, c.interes]
        );
      }
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
    return { deuda: await this.statusOf(debtRow), cuotas: schedule };
  }

  public async list(userId: string): Promise<DebtStatus[]> {
    const rows = await db.query<any>(`SELECT * FROM deuda WHERE usuario_id = $1 ORDER BY creada_en ASC`, [userId]);
    return Promise.all(rows.rows.map((r) => this.statusOf(r)));
  }

  public async get(userId: string, id: string): Promise<{ deuda: DebtStatus; cuotas: any[]; pagos: any[] }> {
    const row = await db.query<any>(`SELECT * FROM deuda WHERE id = $1 AND usuario_id = $2`, [id, userId]);
    if (row.rowCount === 0) throw new NotFoundError('Deuda no encontrada');
    const cuotas = await db.query<any>(`SELECT * FROM cuota_deuda WHERE deuda_id = $1 ORDER BY numero ASC`, [id]);
    const pagos = await db.query<any>(
      `SELECT p.id, p.monto, p.fecha, p.cuenta_id, p.transaccion_id FROM pago_deuda p
       JOIN transaccion t ON t.id = p.transaccion_id WHERE p.deuda_id = $1 AND t.eliminada = FALSE ORDER BY p.fecha DESC`,
      [id]
    );
    return {
      deuda: await this.statusOf(row.rows[0]),
      cuotas: cuotas.rows.map((c) => ({
        numero: Number(c.numero),
        vencimiento: DateUtils.toDateStr(c.vencimiento),
        monto: Number(c.monto),
        capital: Number(c.capital),
        interes: Number(c.interes),
        monto_pagado: Number(c.monto_pagado),
        estado: c.estado,
      })),
      pagos: pagos.rows.map((p) => ({ ...p, monto: Number(p.monto), fecha: DateUtils.toDateStr(p.fecha) })),
    };
  }

  /**
   * Registra un pago: genera un gasto en la cuenta elegida, lo aplica a las cuotas más antiguas
   * y recalcula el saldo, todo en una única transacción SQL (RF-CTA-07).
   */
  public async pay(
    userId: string,
    debtId: string,
    data: { monto: number; fecha: string; cuenta_id: string }
  ): Promise<{ pago_id: string; transaccion_id: string; deuda: DebtStatus }> {
    if (!(data.monto > 0)) throw new ValidationError('El monto del pago debe ser mayor que cero');
    DateRules.assertManualDate(data.fecha, env.TIMEZONE);
    const debt = await db.query<any>(`SELECT * FROM deuda WHERE id = $1 AND usuario_id = $2`, [debtId, userId]);
    if (debt.rowCount === 0) throw new NotFoundError('Deuda no encontrada');
    if (debt.rows[0].estado === 'saldada') throw new ValidationError('La deuda ya está saldada');
    const acc = await db.query<any>(`SELECT * FROM cuenta WHERE id = $1 AND usuario_id = $2`, [data.cuenta_id, userId]);
    if (acc.rowCount === 0) throw new NotFoundError('La cuenta no existe o no pertenece al usuario');
    if (acc.rows[0].archivada) throw new ValidationError('La cuenta está archivada');

    const monto = FinancialCalculator.roundMoney(data.monto);
    const before = await this.statusOf(debt.rows[0]);
    if (monto > before.saldo_pendiente) {
      throw new ValidationError(`El pago excede el saldo pendiente de la deuda (RD$ ${before.saldo_pendiente.toFixed(2)})`);
    }

    const client = await db.getClient();
    let pagoId = '';
    let trxId = '';
    try {
      await client.query('BEGIN');
      const trx = await insertLedgerEntry(client, {
        usuario_id: userId,
        cuenta_id: data.cuenta_id,
        categoria_id: SYSTEM_CATEGORY.pagoDeuda,
        tipo: 'gasto',
        sentido: 'salida',
        monto,
        fecha: data.fecha,
        descripcion: `Pago de deuda: ${debt.rows[0].acreedor}`,
      });
      trxId = trx.id;
      const pago = await client.query(
        `INSERT INTO pago_deuda (deuda_id, cuenta_id, transaccion_id, monto, fecha) VALUES ($1,$2,$3,$4,$5) RETURNING id`,
        [debtId, data.cuenta_id, trx.id, monto, data.fecha]
      );
      pagoId = pago.rows[0].id;

      let restante = monto;
      const cuotas = await client.query(
        `SELECT id, monto, monto_pagado FROM cuota_deuda WHERE deuda_id = $1 AND estado != 'pagada' ORDER BY numero ASC`,
        [debtId]
      );
      for (const c of cuotas.rows) {
        if (restante <= 0) break;
        const pendiente = FinancialCalculator.roundMoney(Number(c.monto) - Number(c.monto_pagado));
        const aplicado = Math.min(pendiente, restante);
        const nuevo = FinancialCalculator.roundMoney(Number(c.monto_pagado) + aplicado);
        await client.query(`UPDATE cuota_deuda SET monto_pagado = $1, estado = $2 WHERE id = $3`, [
          nuevo,
          nuevo >= Number(c.monto) ? 'pagada' : 'parcial',
          c.id,
        ]);
        await client.query(`INSERT INTO aplicacion_pago (pago_id, cuota_id, monto_aplicado) VALUES ($1,$2,$3)`, [
          pagoId,
          c.id,
          aplicado,
        ]);
        restante = FinancialCalculator.roundMoney(restante - aplicado);
      }
      const left = await client.query(`SELECT COUNT(*)::text AS n FROM cuota_deuda WHERE deuda_id = $1 AND estado != 'pagada'`, [debtId]);
      if (parseInt(left.rows[0].n, 10) === 0) {
        await client.query(`UPDATE deuda SET estado = 'saldada' WHERE id = $1`, [debtId]);
      }
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
    const refreshed = await db.query<any>(`SELECT * FROM deuda WHERE id = $1`, [debtId]);
    return { pago_id: pagoId, transaccion_id: trxId, deuda: await this.statusOf(refreshed.rows[0]) };
  }

  /** Total pendiente de todas las deudas activas más el saldo usado en tarjetas (para el dashboard). */
  public async totalOutstanding(userId: string): Promise<number> {
    const debts = await this.list(userId);
    return FinancialCalculator.roundMoney(debts.filter((d) => d.estado === 'activa').reduce((s, d) => s + d.saldo_pendiente, 0));
  }

  /** Calendario cronológico de obligaciones de los próximos N días (RF-CTA-09). */
  public async calendar(userId: string, today: string, days = 60): Promise<CalendarItem[]> {
    const until = DateUtils.addDays(today, days);
    const items: CalendarItem[] = [];

    const cuotas = await db.query<any>(
      `SELECT c.numero, c.vencimiento, c.monto, c.monto_pagado, d.acreedor FROM cuota_deuda c
       JOIN deuda d ON d.id = c.deuda_id WHERE d.usuario_id = $1 AND d.estado = 'activa' AND c.estado != 'pagada'`,
      [userId]
    );
    for (const c of cuotas.rows) {
      const f = DateUtils.toDateStr(c.vencimiento);
      if (f >= today && f <= until) {
        items.push({
          fecha: f,
          tipo: 'cuota_deuda',
          descripcion: `Cuota ${c.numero} · ${c.acreedor}`,
          monto: FinancialCalculator.roundMoney(Number(c.monto) - Number(c.monto_pagado)),
        });
      }
    }

    const tarjetas = await db.query<any>(
      `SELECT c.id, c.nombre, c.dia_pago, COALESCE(v.saldo_actual, c.saldo_inicial) AS saldo FROM cuenta c
       LEFT JOIN vista_saldo_cuenta v ON v.cuenta_id = c.id
       WHERE c.usuario_id = $1 AND c.tipo = 'tarjeta' AND c.archivada = FALSE AND c.dia_pago IS NOT NULL`,
      [userId]
    );
    for (const t of tarjetas.rows) {
      for (let k = 0; k <= Math.ceil(days / 28); k++) {
        const base = DateUtils.addMonths(DateUtils.monthStart(today), k);
        const { y, m } = DateUtils.parse(base);
        const f = DateUtils.format(y, m, Math.min(Number(t.dia_pago), DateUtils.daysInMonth(y, m)));
        if (f >= today && f <= until) {
          const used = Math.max(0, -Number(t.saldo));
          items.push({ fecha: f, tipo: 'pago_tarjeta', descripcion: `Pago de tarjeta ${t.nombre}`, monto: used > 0 ? FinancialCalculator.roundMoney(used) : null });
        }
      }
    }

    const rec = await db.query<any>(
      `SELECT descripcion, monto, frecuencia, fecha_inicio, fecha_fin FROM transaccion_recurrente
       WHERE usuario_id = $1 AND tipo = 'gasto' AND estado = 'activa'`,
      [userId]
    );
    for (const r of rec.rows) {
      const dates = RecurrenceRules.between(
        DateUtils.toDateStr(r.fecha_inicio),
        r.frecuencia as Frequency,
        DateUtils.addDays(today, -1),
        until,
        r.fecha_fin ? DateUtils.toDateStr(r.fecha_fin) : null
      );
      for (const f of dates) {
        items.push({ fecha: f, tipo: 'recurrente_gasto', descripcion: r.descripcion, monto: Number(r.monto) });
      }
    }
    return items.sort((a, b) => a.fecha.localeCompare(b.fecha) || a.descripcion.localeCompare(b.descripcion));
  }
}
