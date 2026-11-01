import { db } from '../../infrastructure/database/db.js';
import { insertLedgerEntry, SYSTEM_CATEGORY } from '../../infrastructure/repositories/LedgerWriter.js';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';
import { DateUtils } from '../../domain/services/DateUtils.js';
import { DateRules } from '../../domain/services/DateRules.js';
import { NotFoundError, ValidationError } from '../../domain/errors/DomainError.js';
import { NotificationService } from '../notifications/NotificationService.js';
import { env } from '../../config/env.js';

export interface GoalProgress {
  id: string;
  nombre: string;
  cuenta_id: string | null;
  monto_objetivo: number;
  fecha_limite: string;
  estado: 'activa' | 'pausada' | 'cerrada' | 'alcanzada';
  acumulado: number;
  faltante: number;
  porcentaje: number;
  meses_restantes: number;
  monto_mensual_necesario: number;
  ritmo_mensual_actual: number;
  fecha_estimada_cumplimiento: string | null;
  vencida: boolean;
}

/** Metas de ahorro y aportes (RF-PRE-03 a 06). */
export class GoalService {
  public static monthlyNeeded(objetivo: number, acumulado: number, hoy: string, limite: string): number {
    const faltante = Math.max(0, FinancialCalculator.roundMoney(objetivo - acumulado));
    if (faltante === 0) return 0;
    const meses = limite <= hoy ? 1 : DateUtils.monthsBetween(hoy, limite);
    return FinancialCalculator.roundMoney(faltante / meses);
  }

  /** Fecha estimada si se mantiene el ritmo medio mensual de aportes realizados. */
  public static estimate(faltante: number, ritmoMensual: number, hoy: string): string | null {
    if (faltante <= 0) return hoy;
    if (ritmoMensual <= 0) return null;
    return DateUtils.addMonths(hoy, Math.ceil(faltante / ritmoMensual));
  }

  private today(): string {
    return DateRules.todayIn(env.TIMEZONE);
  }

  private async progressOf(row: any, hoy: string): Promise<GoalProgress> {
    const ap = await db.query<any>(
      `SELECT a.monto, a.fecha FROM aporte_meta a JOIN transaccion t ON t.id = a.transaccion_id
       WHERE a.meta_id = $1 AND t.eliminada = FALSE ORDER BY a.fecha ASC`,
      [row.id]
    );
    const acumulado = FinancialCalculator.roundMoney(ap.rows.reduce((s, r) => s + Number(r.monto), 0));
    const objetivo = FinancialCalculator.roundMoney(Number(row.monto_objetivo));
    const limite = DateUtils.toDateStr(row.fecha_limite);
    const faltante = Math.max(0, FinancialCalculator.roundMoney(objetivo - acumulado));

    let ritmo = 0;
    if (ap.rows.length > 0) {
      const first = DateUtils.toDateStr(ap.rows[0].fecha);
      const months = DateUtils.monthsBetween(first, hoy > first ? hoy : first);
      ritmo = FinancialCalculator.roundMoney(acumulado / months);
    }
    return {
      id: row.id,
      nombre: row.nombre,
      cuenta_id: row.cuenta_id,
      monto_objetivo: objetivo,
      fecha_limite: limite,
      estado: row.estado,
      acumulado,
      faltante,
      porcentaje: Math.min(100, Math.round((acumulado / objetivo) * 1000) / 10),
      meses_restantes: limite <= hoy ? 0 : DateUtils.monthsBetween(hoy, limite),
      monto_mensual_necesario: GoalService.monthlyNeeded(objetivo, acumulado, hoy, limite),
      ritmo_mensual_actual: ritmo,
      fecha_estimada_cumplimiento: GoalService.estimate(faltante, ritmo, hoy),
      vencida: limite < hoy && faltante > 0,
    };
  }

  public async list(userId: string): Promise<GoalProgress[]> {
    const rows = await db.query<any>(`SELECT * FROM meta_ahorro WHERE usuario_id = $1 ORDER BY fecha_limite ASC`, [userId]);
    const hoy = this.today();
    return Promise.all(rows.rows.map((r) => this.progressOf(r, hoy)));
  }

  public async get(userId: string, id: string): Promise<GoalProgress> {
    const row = await db.query<any>(`SELECT * FROM meta_ahorro WHERE id = $1 AND usuario_id = $2`, [id, userId]);
    if (row.rowCount === 0) throw new NotFoundError('Meta de ahorro no encontrada');
    return this.progressOf(row.rows[0], this.today());
  }

  public async create(
    userId: string,
    data: { nombre: string; monto_objetivo: number; fecha_limite: string; cuenta_id?: string | null }
  ): Promise<GoalProgress> {
    if (!(data.monto_objetivo > 0)) throw new ValidationError('El monto objetivo debe ser mayor que cero');
    if (!DateRules.isRealDate(data.fecha_limite)) throw new ValidationError('La fecha límite no es válida');
    if (data.fecha_limite <= this.today()) throw new ValidationError('La fecha límite debe ser posterior a hoy');
    if (data.cuenta_id) await this.assertAccount(userId, data.cuenta_id);
    const res = await db.query<any>(
      `INSERT INTO meta_ahorro (usuario_id, cuenta_id, nombre, monto_objetivo, fecha_limite)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [userId, data.cuenta_id ?? null, data.nombre.trim(), FinancialCalculator.roundMoney(data.monto_objetivo), data.fecha_limite]
    );
    return this.progressOf(res.rows[0], this.today());
  }

  public async update(
    userId: string,
    id: string,
    data: { nombre?: string; monto_objetivo?: number; fecha_limite?: string; estado?: 'activa' | 'pausada' | 'cerrada' }
  ): Promise<GoalProgress> {
    const cur = await db.query<any>(`SELECT * FROM meta_ahorro WHERE id = $1 AND usuario_id = $2`, [id, userId]);
    if (cur.rowCount === 0) throw new NotFoundError('Meta de ahorro no encontrada');
    const c = cur.rows[0];
    if (data.monto_objetivo !== undefined && !(data.monto_objetivo > 0)) {
      throw new ValidationError('El monto objetivo debe ser mayor que cero');
    }
    if (data.fecha_limite !== undefined && !DateRules.isRealDate(data.fecha_limite)) {
      throw new ValidationError('La fecha límite no es válida');
    }
    await db.query(
      `UPDATE meta_ahorro SET nombre = $1, monto_objetivo = $2, fecha_limite = $3, estado = $4 WHERE id = $5`,
      [
        data.nombre?.trim() || c.nombre,
        FinancialCalculator.roundMoney(data.monto_objetivo ?? Number(c.monto_objetivo)),
        data.fecha_limite ?? DateUtils.toDateStr(c.fecha_limite),
        data.estado ?? c.estado,
        id,
      ]
    );
    return this.get(userId, id);
  }

  private async assertAccount(userId: string, cuentaId: string): Promise<any> {
    const acc = await db.query<any>(`SELECT * FROM cuenta WHERE id = $1 AND usuario_id = $2`, [cuentaId, userId]);
    if (acc.rowCount === 0) throw new NotFoundError('La cuenta no existe o no pertenece al usuario');
    if (acc.rows[0].archivada) throw new ValidationError('La cuenta está archivada');
    return acc.rows[0];
  }

  /** Aporte: crea el movimiento de la cuenta de origen y el aporte en una sola operación atómica. */
  public async contribute(
    userId: string,
    goalId: string,
    data: { monto: number; fecha: string; cuenta_id: string }
  ): Promise<{ aporte_id: string; transaccion_id: string; meta: GoalProgress }> {
    if (!(data.monto > 0)) throw new ValidationError('El monto del aporte debe ser mayor que cero');
    DateRules.assertManualDate(data.fecha, env.TIMEZONE);
    const goal = await db.query<any>(`SELECT * FROM meta_ahorro WHERE id = $1 AND usuario_id = $2`, [goalId, userId]);
    if (goal.rowCount === 0) throw new NotFoundError('Meta de ahorro no encontrada');
    if (['cerrada', 'alcanzada'].includes(goal.rows[0].estado)) {
      throw new ValidationError('La meta ya está cerrada o alcanzada y no admite más aportes');
    }
    await this.assertAccount(userId, data.cuenta_id);

    const monto = FinancialCalculator.roundMoney(data.monto);
    const client = await db.getClient();
    let aporteId = '';
    let trxId = '';
    try {
      await client.query('BEGIN');
      const trx = await insertLedgerEntry(client, {
        usuario_id: userId,
        cuenta_id: data.cuenta_id,
        categoria_id: SYSTEM_CATEGORY.aporteMeta,
        tipo: 'aporte_meta',
        sentido: 'salida',
        monto,
        fecha: data.fecha,
        descripcion: `Aporte a meta: ${goal.rows[0].nombre}`,
      });
      trxId = trx.id;
      const ap = await client.query(
        `INSERT INTO aporte_meta (meta_id, transaccion_id, monto, fecha) VALUES ($1,$2,$3,$4) RETURNING id`,
        [goalId, trx.id, monto, data.fecha]
      );
      aporteId = ap.rows[0].id;
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    let meta = await this.get(userId, goalId);
    if (meta.faltante === 0 && meta.estado === 'activa') {
      await db.query(`UPDATE meta_ahorro SET estado = 'alcanzada' WHERE id = $1`, [goalId]);
      await NotificationService.notify(userId, 'meta_alcanzada', `¡Alcanzaste tu meta "${meta.nombre}"!`, `meta:${goalId}`);
      meta = await this.get(userId, goalId);
    }
    return { aporte_id: aporteId, transaccion_id: trxId, meta };
  }

  public async contributions(userId: string, goalId: string): Promise<{ id: string; monto: number; fecha: string; transaccion_id: string }[]> {
    await this.get(userId, goalId);
    const res = await db.query<any>(
      `SELECT a.id, a.monto, a.fecha, a.transaccion_id FROM aporte_meta a JOIN transaccion t ON t.id = a.transaccion_id
       WHERE a.meta_id = $1 AND t.eliminada = FALSE ORDER BY a.fecha DESC`,
      [goalId]
    );
    return res.rows.map((r) => ({
      id: r.id,
      monto: Number(r.monto),
      fecha: DateUtils.toDateStr(r.fecha),
      transaccion_id: r.transaccion_id,
    }));
  }
}
