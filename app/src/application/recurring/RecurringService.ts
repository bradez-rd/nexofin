import { db } from '../../infrastructure/database/db.js';
import { insertLedgerEntry } from '../../infrastructure/repositories/LedgerWriter.js';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';
import { RecurrenceRules, Frequency } from '../../domain/services/RecurrenceRules.js';
import { DateUtils } from '../../domain/services/DateUtils.js';
import { DateRules } from '../../domain/services/DateRules.js';
import { NotFoundError, ValidationError } from '../../domain/errors/DomainError.js';
import { CategorizationService } from '../categories/CategorizationService.js';
import { BudgetService } from '../budgets/BudgetService.js';

export interface Recurring {
  id: string;
  cuenta_id: string;
  categoria_id: string | null;
  tipo: 'ingreso' | 'gasto';
  monto: number;
  descripcion: string;
  frecuencia: Frequency;
  fecha_inicio: string;
  fecha_fin: string | null;
  ultima_generada: string | null;
  estado: 'activa' | 'pausada' | 'finalizada';
}

function map(r: any): Recurring {
  return {
    id: r.id,
    cuenta_id: r.cuenta_id,
    categoria_id: r.categoria_id,
    tipo: r.tipo,
    monto: Number(r.monto),
    descripcion: r.descripcion,
    frecuencia: r.frecuencia,
    fecha_inicio: DateUtils.toDateStr(r.fecha_inicio),
    fecha_fin: r.fecha_fin ? DateUtils.toDateStr(r.fecha_fin) : null,
    ultima_generada: r.ultima_generada ? DateUtils.toDateStr(r.ultima_generada) : null,
    estado: r.estado,
  };
}

/** Transacciones recurrentes (RF-TRX-06): renta, suscripciones y nómina. */
export class RecurringService {
  constructor(
    private readonly categorization = new CategorizationService(),
    private readonly budgets = new BudgetService()
  ) {}

  public async list(userId: string): Promise<Recurring[]> {
    const res = await db.query<any>(
      `SELECT * FROM transaccion_recurrente WHERE usuario_id = $1 ORDER BY estado ASC, fecha_inicio ASC`,
      [userId]
    );
    return res.rows.map(map);
  }

  private async assertAccount(userId: string, cuentaId: string): Promise<void> {
    const acc = await db.query<any>(`SELECT archivada FROM cuenta WHERE id = $1 AND usuario_id = $2`, [cuentaId, userId]);
    if (acc.rowCount === 0) throw new NotFoundError('La cuenta no existe o no pertenece al usuario');
    if (acc.rows[0].archivada) throw new ValidationError('La cuenta está archivada');
  }

  public async create(
    userId: string,
    data: {
      cuenta_id: string;
      categoria_id?: string | null;
      tipo: 'ingreso' | 'gasto';
      monto: number;
      descripcion: string;
      frecuencia: Frequency;
      fecha_inicio: string;
      fecha_fin?: string | null;
    }
  ): Promise<Recurring> {
    if (!(data.monto > 0)) throw new ValidationError('El monto debe ser mayor que cero');
    if (!DateRules.isRealDate(data.fecha_inicio)) throw new ValidationError('La fecha de inicio no es válida');
    if (data.fecha_fin && (!DateRules.isRealDate(data.fecha_fin) || data.fecha_fin < data.fecha_inicio)) {
      throw new ValidationError('La fecha de fin debe ser válida y no anterior al inicio');
    }
    await this.assertAccount(userId, data.cuenta_id);
    const res = await db.query<any>(
      `INSERT INTO transaccion_recurrente
         (usuario_id, cuenta_id, categoria_id, tipo, monto, descripcion, frecuencia, fecha_inicio, fecha_fin)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [
        userId,
        data.cuenta_id,
        data.categoria_id ?? null,
        data.tipo,
        FinancialCalculator.roundMoney(data.monto),
        data.descripcion.trim(),
        data.frecuencia,
        data.fecha_inicio,
        data.fecha_fin ?? null,
      ]
    );
    return map(res.rows[0]);
  }

  /** Editar no altera las transacciones ya generadas: solo afecta a las futuras. */
  public async update(
    userId: string,
    id: string,
    data: { monto?: number; descripcion?: string; categoria_id?: string | null; fecha_fin?: string | null; estado?: 'activa' | 'pausada' | 'finalizada'; frecuencia?: Frequency }
  ): Promise<Recurring> {
    const cur = await db.query<any>(`SELECT * FROM transaccion_recurrente WHERE id = $1 AND usuario_id = $2`, [id, userId]);
    if (cur.rowCount === 0) throw new NotFoundError('Recurrencia no encontrada');
    const c = map(cur.rows[0]);
    if (c.estado === 'finalizada' && data.estado && data.estado !== 'finalizada') {
      throw new ValidationError('Una recurrencia finalizada no se puede reactivar');
    }
    if (data.monto !== undefined && !(data.monto > 0)) throw new ValidationError('El monto debe ser mayor que cero');
    const res = await db.query<any>(
      `UPDATE transaccion_recurrente SET monto = $1, descripcion = $2, categoria_id = $3, fecha_fin = $4, estado = $5, frecuencia = $6
       WHERE id = $7 RETURNING *`,
      [
        FinancialCalculator.roundMoney(data.monto ?? c.monto),
        data.descripcion?.trim() || c.descripcion,
        data.categoria_id === undefined ? c.categoria_id : data.categoria_id,
        data.fecha_fin === undefined ? c.fecha_fin : data.fecha_fin,
        data.estado ?? c.estado,
        data.frecuencia ?? c.frecuencia,
        id,
      ]
    );
    return map(res.rows[0]);
  }

  public async finish(userId: string, id: string): Promise<Recurring> {
    return this.update(userId, id, { estado: 'finalizada' });
  }

  /**
   * Genera las transacciones vencidas hasta hoy. Es idempotente: `ultima_generada` evita duplicar
   * y una recurrencia pausada no genera nada. Devuelve cuántas se crearon.
   */
  public async generateDue(userId: string, today: string): Promise<number> {
    const res = await db.query<any>(
      `SELECT * FROM transaccion_recurrente WHERE usuario_id = $1 AND estado = 'activa'`,
      [userId]
    );
    let created = 0;
    for (const raw of res.rows) {
      const r = map(raw);
      const dates = RecurrenceRules.between(r.fecha_inicio, r.frecuencia, r.ultima_generada, today, r.fecha_fin);
      if (dates.length === 0) continue;
      const client = await db.getClient();
      try {
        await client.query('BEGIN');
        let categoria = r.categoria_id;
        let estado: 'categorizada' | 'pendiente_revision' | 'sin_categoria' = categoria ? 'categorizada' : 'sin_categoria';
        let confianza: number | null = null;
        if (!categoria) {
          const c = await this.categorization.classify(userId, r.descripcion, r.tipo);
          categoria = c.categoria_id;
          estado = c.estado;
          confianza = c.confianza;
        }
        for (const f of dates) {
          await insertLedgerEntry(client, {
            usuario_id: userId,
            cuenta_id: r.cuenta_id,
            categoria_id: categoria,
            tipo: r.tipo,
            sentido: r.tipo === 'ingreso' ? 'entrada' : 'salida',
            monto: r.monto,
            fecha: f,
            descripcion: r.descripcion,
            recurrente_id: r.id,
            estado_categoria: estado,
            confianza,
          });
          created++;
        }
        const last = dates[dates.length - 1];
        const finished = r.fecha_fin !== null && RecurrenceRules.between(r.fecha_inicio, r.frecuencia, last, r.fecha_fin, r.fecha_fin).length === 0;
        await client.query(`UPDATE transaccion_recurrente SET ultima_generada = $1, estado = $2 WHERE id = $3`, [
          last,
          finished && today >= r.fecha_fin! ? 'finalizada' : 'activa',
          r.id,
        ]);
        await client.query('COMMIT');
        if (r.tipo === 'gasto') await this.budgets.checkAfterChange(userId, categoria, last);
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    }
    return created;
  }
}
