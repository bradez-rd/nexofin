import { db } from '../../infrastructure/database/db.js';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';
import { DateUtils } from '../../domain/services/DateUtils.js';
import { NotFoundError, ValidationError, ConflictError } from '../../domain/errors/DomainError.js';
import { NotificationService } from '../notifications/NotificationService.js';

export interface BudgetStatus {
  id: string;
  categoria_id: string;
  categoria_nombre: string;
  mes: string;
  monto_limite: number;
  umbral_alerta: number;
  consumido: number;
  disponible: number;
  porcentaje: number;
  estado: 'ok' | 'alerta' | 'superado';
}

/** Presupuestos mensuales por categoría (RF-PRE-01/02). */
export class BudgetService {
  public static monthKey(mes: string): string {
    if (!/^\d{4}-(0[1-9]|1[0-2])(-\d{2})?$/.test(mes)) {
      throw new ValidationError('El mes debe tener el formato AAAA-MM');
    }
    return `${mes.slice(0, 7)}-01`;
  }

  private static statusOf(pct: number, umbral: number): BudgetStatus['estado'] {
    if (pct >= 100) return 'superado';
    if (pct / 100 >= umbral) return 'alerta';
    return 'ok';
  }

  private async spentByCategory(userId: string, mesStart: string): Promise<Map<string, number>> {
    const res = await db.query<any>(
      `SELECT categoria_id, SUM(monto)::numeric AS total FROM transaccion
       WHERE usuario_id = $1 AND tipo = 'gasto' AND eliminada = FALSE
         AND fecha >= $2 AND fecha <= $3 AND categoria_id IS NOT NULL
       GROUP BY categoria_id`,
      [userId, mesStart, DateUtils.monthEnd(mesStart)]
    );
    return new Map(res.rows.map((r) => [r.categoria_id as string, FinancialCalculator.roundMoney(Number(r.total))]));
  }

  public async list(userId: string, mes: string): Promise<BudgetStatus[]> {
    const start = BudgetService.monthKey(mes);
    const rows = await db.query<any>(
      `SELECT p.id, p.categoria_id, p.monto_limite, p.umbral_alerta, c.nombre
       FROM presupuesto p JOIN categoria c ON c.id = p.categoria_id
       WHERE p.usuario_id = $1 AND p.mes = $2 ORDER BY c.nombre ASC`,
      [userId, start]
    );
    const spent = await this.spentByCategory(userId, start);
    return rows.rows.map((r) => {
      const limite = FinancialCalculator.roundMoney(Number(r.monto_limite));
      const consumido = spent.get(r.categoria_id) ?? 0;
      const porcentaje = Math.round((consumido / limite) * 1000) / 10;
      const umbral = Number(r.umbral_alerta);
      return {
        id: r.id,
        categoria_id: r.categoria_id,
        categoria_nombre: r.nombre,
        mes: start.slice(0, 7),
        monto_limite: limite,
        umbral_alerta: umbral,
        consumido,
        disponible: FinancialCalculator.roundMoney(limite - consumido),
        porcentaje,
        estado: BudgetService.statusOf(porcentaje, umbral),
      };
    });
  }

  public async create(
    userId: string,
    data: { categoria_id: string; mes: string; monto_limite: number; umbral_alerta?: number }
  ): Promise<BudgetStatus> {
    const start = BudgetService.monthKey(data.mes);
    const cat = await db.query<any>(
      `SELECT tipo FROM categoria WHERE id = $1 AND (usuario_id = $2 OR usuario_id IS NULL) AND archivada = FALSE`,
      [data.categoria_id, userId]
    );
    if (cat.rowCount === 0) throw new NotFoundError('La categoría no existe');
    if (cat.rows[0].tipo !== 'gasto') throw new ValidationError('Solo se presupuestan categorías de gasto');
    if (!(data.monto_limite > 0)) throw new ValidationError('El monto del presupuesto debe ser mayor que cero');
    const umbral = data.umbral_alerta ?? 0.8;
    if (umbral <= 0 || umbral > 1) throw new ValidationError('El umbral debe estar entre 0 y 1');
    const dup = await db.query(
      `SELECT 1 FROM presupuesto WHERE usuario_id = $1 AND categoria_id = $2 AND mes = $3`,
      [userId, data.categoria_id, start]
    );
    if (dup.rowCount > 0) throw new ConflictError('Ya existe un presupuesto para esa categoría en ese mes');
    const res = await db.query<any>(
      `INSERT INTO presupuesto (usuario_id, categoria_id, mes, monto_limite, umbral_alerta)
       VALUES ($1,$2,$3,$4,$5) RETURNING id`,
      [userId, data.categoria_id, start, FinancialCalculator.roundMoney(data.monto_limite), umbral]
    );
    return (await this.get(userId, res.rows[0].id))!;
  }

  public async get(userId: string, id: string): Promise<BudgetStatus | null> {
    const row = await db.query<any>(`SELECT mes FROM presupuesto WHERE id = $1 AND usuario_id = $2`, [id, userId]);
    if (row.rowCount === 0) return null;
    const list = await this.list(userId, DateUtils.toDateStr(row.rows[0].mes));
    return list.find((b) => b.id === id) ?? null;
  }

  public async update(
    userId: string,
    id: string,
    data: { monto_limite?: number; umbral_alerta?: number }
  ): Promise<BudgetStatus> {
    const cur = await db.query<any>(`SELECT * FROM presupuesto WHERE id = $1 AND usuario_id = $2`, [id, userId]);
    if (cur.rowCount === 0) throw new NotFoundError('Presupuesto no encontrado');
    const limite = data.monto_limite ?? Number(cur.rows[0].monto_limite);
    const umbral = data.umbral_alerta ?? Number(cur.rows[0].umbral_alerta);
    if (!(limite > 0)) throw new ValidationError('El monto del presupuesto debe ser mayor que cero');
    if (umbral <= 0 || umbral > 1) throw new ValidationError('El umbral debe estar entre 0 y 1');
    await db.query(`UPDATE presupuesto SET monto_limite = $1, umbral_alerta = $2 WHERE id = $3`, [
      FinancialCalculator.roundMoney(limite),
      umbral,
      id,
    ]);
    return (await this.get(userId, id))!;
  }

  public async remove(userId: string, id: string): Promise<void> {
    const res = await db.query(`DELETE FROM presupuesto WHERE id = $1 AND usuario_id = $2 RETURNING id`, [id, userId]);
    if (res.rowCount === 0) throw new NotFoundError('Presupuesto no encontrado');
  }

  /**
   * Se invoca al registrar, editar o eliminar un gasto: emite alerta al llegar al umbral y al
   * superar el 100 % en el momento del hecho (RF-PRE-02). Es idempotente por mes y nivel.
   */
  public async checkAfterChange(userId: string, categoriaId: string | null | undefined, fecha: string): Promise<void> {
    if (!categoriaId) return;
    try {
      const list = await this.list(userId, DateUtils.monthStart(fecha).slice(0, 7));
      const b = list.find((x) => x.categoria_id === categoriaId);
      if (!b) return;
      if (b.estado === 'superado') {
        await NotificationService.notify(
          userId,
          'presupuesto_superado',
          `Superaste el presupuesto de ${b.categoria_nombre} (${b.porcentaje}% de RD$ ${b.monto_limite.toFixed(2)}).`,
          `bud:${b.id}:superado`
        );
      } else if (b.estado === 'alerta') {
        await NotificationService.notify(
          userId,
          'presupuesto_umbral',
          `Llevas ${b.porcentaje}% del presupuesto de ${b.categoria_nombre}.`,
          `bud:${b.id}:umbral`
        );
      }
    } catch (err: any) {
      console.error('[Budget] No se pudo evaluar el presupuesto:', err.message);
    }
  }
}
