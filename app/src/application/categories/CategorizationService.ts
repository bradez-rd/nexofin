import { db } from '../../infrastructure/database/db.js';
import {
  CategorizationEngine,
  Classification,
  CategoryRule,
  PastCorrection,
} from '../../domain/services/CategorizationEngine.js';
import { NotFoundError, ValidationError, ConflictError } from '../../domain/errors/DomainError.js';
import { DateUtils } from '../../domain/services/DateUtils.js';

export interface RuleRow {
  id: string;
  texto_contiene: string;
  categoria_id: string;
  prioridad: number;
  activa: boolean;
}

export interface ReviewItem {
  id: string;
  cuenta_id: string;
  tipo: string;
  monto: number;
  fecha: string;
  descripcion: string | null;
  estado_categoria: string;
  confianza: number | null;
}

/** Categorización automática y gestión de reglas y categorías (RF-CAT-01 a 06). */
export class CategorizationService {
  private async rules(userId: string): Promise<CategoryRule[]> {
    const res = await db.query<any>(
      `SELECT texto_contiene, categoria_id, prioridad FROM regla_categorizacion
       WHERE usuario_id = $1 AND activa = TRUE`,
      [userId]
    );
    return res.rows.map((r) => ({ ...r, prioridad: Number(r.prioridad) }));
  }

  private async corrections(userId: string): Promise<PastCorrection[]> {
    const res = await db.query<any>(
      `SELECT descripcion, categoria_id FROM transaccion
       WHERE usuario_id = $1 AND categoria_manual = TRUE AND eliminada = FALSE
         AND descripcion IS NOT NULL AND categoria_id IS NOT NULL`,
      [userId]
    );
    return res.rows.map((r) => ({
      descripcion_norm: CategorizationEngine.normalize(r.descripcion),
      categoria_id: r.categoria_id,
    }));
  }

  /** Clasifica una descripción nueva según reglas, correcciones previas y palabras clave. */
  public async classify(
    userId: string,
    descripcion: string | null | undefined,
    tipo: 'ingreso' | 'gasto'
  ): Promise<Classification> {
    const [rules, corrections] = await Promise.all([this.rules(userId), this.corrections(userId)]);
    return CategorizationEngine.classify(descripcion, tipo, rules, corrections);
  }

  // ---- Reglas (RF-CAT-02) --------------------------------------------------------------------

  public async listRules(userId: string): Promise<RuleRow[]> {
    const res = await db.query<any>(
      `SELECT id, texto_contiene, categoria_id, prioridad, activa FROM regla_categorizacion
       WHERE usuario_id = $1 ORDER BY prioridad DESC, texto_contiene ASC`,
      [userId]
    );
    return res.rows.map((r) => ({ ...r, prioridad: Number(r.prioridad), activa: Boolean(r.activa) }));
  }

  private async assertCategory(userId: string, categoriaId: string): Promise<{ tipo: string }> {
    const res = await db.query<any>(
      `SELECT tipo FROM categoria WHERE id = $1 AND (usuario_id = $2 OR usuario_id IS NULL) AND archivada = FALSE`,
      [categoriaId, userId]
    );
    if (res.rowCount === 0) throw new NotFoundError('La categoría no existe o está archivada');
    return res.rows[0];
  }

  public async createRule(
    userId: string,
    data: { texto_contiene: string; categoria_id: string; prioridad?: number }
  ): Promise<RuleRow> {
    const text = data.texto_contiene.trim();
    if (text.length < 2) throw new ValidationError('El texto de la regla debe tener al menos 2 caracteres');
    await this.assertCategory(userId, data.categoria_id);
    const dup = await db.query(
      `SELECT 1 FROM regla_categorizacion WHERE usuario_id = $1 AND LOWER(texto_contiene) = $2`,
      [userId, text.toLowerCase()]
    );
    if (dup.rowCount > 0) throw new ConflictError('Ya existe una regla con ese texto');
    const res = await db.query<any>(
      `INSERT INTO regla_categorizacion (usuario_id, categoria_id, texto_contiene, prioridad)
       VALUES ($1, $2, $3, $4) RETURNING id, texto_contiene, categoria_id, prioridad, activa`,
      [userId, data.categoria_id, text, data.prioridad ?? 0]
    );
    await this.reprocess(userId);
    const r = res.rows[0];
    return { ...r, prioridad: Number(r.prioridad), activa: Boolean(r.activa) };
  }

  public async updateRule(
    userId: string,
    id: string,
    data: { texto_contiene?: string; categoria_id?: string; prioridad?: number; activa?: boolean }
  ): Promise<RuleRow> {
    const current = await db.query<any>(
      `SELECT * FROM regla_categorizacion WHERE id = $1 AND usuario_id = $2`,
      [id, userId]
    );
    if (current.rowCount === 0) throw new NotFoundError('Regla no encontrada');
    if (data.categoria_id) await this.assertCategory(userId, data.categoria_id);
    const merged = { ...current.rows[0], ...Object.fromEntries(Object.entries(data).filter(([, v]) => v !== undefined)) };
    const res = await db.query<any>(
      `UPDATE regla_categorizacion SET texto_contiene = $1, categoria_id = $2, prioridad = $3, activa = $4
       WHERE id = $5 AND usuario_id = $6 RETURNING id, texto_contiene, categoria_id, prioridad, activa`,
      [String(merged.texto_contiene).trim(), merged.categoria_id, merged.prioridad, merged.activa, id, userId]
    );
    await this.reprocess(userId);
    const r = res.rows[0];
    return { ...r, prioridad: Number(r.prioridad), activa: Boolean(r.activa) };
  }

  public async deleteRule(userId: string, id: string): Promise<void> {
    const res = await db.query(`DELETE FROM regla_categorizacion WHERE id = $1 AND usuario_id = $2 RETURNING id`, [
      id,
      userId,
    ]);
    if (res.rowCount === 0) throw new NotFoundError('Regla no encontrada');
  }

  // ---- Reproceso y bandeja de revisión (RF-CAT-03/06) ------------------------------------------

  /**
   * Reclasifica las transacciones sin categoría o pendientes. Nunca toca las que el usuario
   * corrigió a mano ni las que ya tienen una categoría asignada.
   */
  public async reprocess(userId: string): Promise<number> {
    const pending = await db.query<any>(
      `SELECT id, tipo, descripcion FROM transaccion
       WHERE usuario_id = $1 AND eliminada = FALSE AND categoria_manual = FALSE
         AND tipo IN ('ingreso','gasto') AND estado_categoria != 'categorizada'`,
      [userId]
    );
    let changed = 0;
    const [rules, corrections] = await Promise.all([this.rules(userId), this.corrections(userId)]);
    for (const t of pending.rows) {
      const c = CategorizationEngine.classify(t.descripcion, t.tipo, rules, corrections);
      if (c.estado === 'categorizada') {
        await db.query(
          `UPDATE transaccion SET categoria_id = $1, estado_categoria = 'categorizada', confianza = $2 WHERE id = $3`,
          [c.categoria_id, c.confianza, t.id]
        );
        changed++;
      }
    }
    return changed;
  }

  public async reviewInbox(userId: string): Promise<ReviewItem[]> {
    const res = await db.query<any>(
      `SELECT id, cuenta_id, tipo, monto, fecha, descripcion, estado_categoria, confianza FROM transaccion
       WHERE usuario_id = $1 AND eliminada = FALSE AND tipo IN ('ingreso','gasto')
         AND estado_categoria IN ('pendiente_revision','sin_categoria')
       ORDER BY fecha DESC, creada_en DESC LIMIT 200`,
      [userId]
    );
    return res.rows.map((r) => ({
      id: r.id,
      cuenta_id: r.cuenta_id,
      tipo: r.tipo,
      monto: Number(r.monto),
      fecha: DateUtils.toDateStr(r.fecha),
      descripcion: r.descripcion,
      estado_categoria: r.estado_categoria,
      confianza: r.confianza !== null ? Number(r.confianza) : null,
    }));
  }

  /** Corrección manual: se conserva en reprocesos y se ofrece crear una regla (RF-CAT-03). */
  public async categorize(
    userId: string,
    transactionId: string,
    categoriaId: string,
    crearRegla = false
  ): Promise<{ transaccion_id: string; categoria_id: string; sugerencia_regla: { texto_contiene: string; categoria_id: string } | null; regla_creada: RuleRow | null }> {
    const trx = await db.query<any>(
      `SELECT id, tipo, descripcion FROM transaccion WHERE id = $1 AND usuario_id = $2 AND eliminada = FALSE`,
      [transactionId, userId]
    );
    if (trx.rowCount === 0) throw new NotFoundError('Transacción no encontrada');
    const t = trx.rows[0];
    if (t.tipo === 'transferencia') throw new ValidationError('Las transferencias no llevan categoría');
    const cat = await this.assertCategory(userId, categoriaId);
    if (cat.tipo !== t.tipo && ['ingreso', 'gasto'].includes(t.tipo)) {
      throw new ValidationError(`La categoría debe ser de tipo ${t.tipo}`);
    }
    await db.query(
      `UPDATE transaccion SET categoria_id = $1, categoria_manual = TRUE, estado_categoria = 'categorizada', confianza = 1
       WHERE id = $2 AND usuario_id = $3`,
      [categoriaId, transactionId, userId]
    );
    const sugerencia = t.descripcion
      ? { texto_contiene: CategorizationEngine.normalize(t.descripcion), categoria_id: categoriaId }
      : null;
    let created: RuleRow | null = null;
    if (crearRegla && sugerencia) {
      try {
        created = await this.createRule(userId, sugerencia);
      } catch (e) {
        if (!(e instanceof ConflictError)) throw e;
      }
    }
    return { transaccion_id: transactionId, categoria_id: categoriaId, sugerencia_regla: sugerencia, regla_creada: created };
  }

  // ---- Categorías personalizadas (RF-CAT-04/05) ----------------------------------------------

  public async updateCategory(
    userId: string,
    id: string,
    data: { nombre?: string; icono?: string; color?: string; archivada?: boolean }
  ): Promise<any> {
    const cur = await db.query<any>(`SELECT * FROM categoria WHERE id = $1`, [id]);
    if (cur.rowCount === 0) throw new NotFoundError('Categoría no encontrada');
    const c = cur.rows[0];
    if (c.es_sistema) throw new ValidationError('Las categorías del sistema no se pueden modificar ni archivar');
    if (c.usuario_id !== userId) throw new NotFoundError('Categoría no encontrada');
    if (data.archivada === true) await this.assertNoOrphans(userId, id);
    const res = await db.query<any>(
      `UPDATE categoria SET nombre = $1, icono = $2, color = $3, archivada = $4 WHERE id = $5 RETURNING *`,
      [
        data.nombre?.trim() || c.nombre,
        data.icono ?? c.icono,
        data.color ?? c.color,
        data.archivada ?? c.archivada,
        id,
      ]
    );
    return res.rows[0];
  }

  private async assertNoOrphans(userId: string, categoryId: string): Promise<void> {
    const used = await db.query<any>(
      `SELECT COUNT(*)::text AS n FROM transaccion WHERE usuario_id = $1 AND categoria_id = $2 AND eliminada = FALSE`,
      [userId, categoryId]
    );
    if (parseInt(used.rows[0].n, 10) > 0) {
      throw new ValidationError(
        'La categoría tiene transacciones: reasígnalas a otra categoría antes de archivarla o eliminarla'
      );
    }
  }

  /** Elimina una categoría propia reasignando antes sus transacciones (ninguna queda huérfana). */
  public async deleteCategory(userId: string, id: string, reasignarA?: string): Promise<void> {
    const cur = await db.query<any>(`SELECT * FROM categoria WHERE id = $1`, [id]);
    if (cur.rowCount === 0 || (cur.rows[0].usuario_id !== userId && !cur.rows[0].es_sistema)) {
      throw new NotFoundError('Categoría no encontrada');
    }
    if (cur.rows[0].es_sistema) throw new ValidationError('Las categorías del sistema no se pueden eliminar');

    const used = await db.query<any>(
      `SELECT COUNT(*)::text AS n FROM transaccion WHERE usuario_id = $1 AND categoria_id = $2`,
      [userId, id]
    );
    if (parseInt(used.rows[0].n, 10) > 0) {
      if (!reasignarA) {
        throw new ValidationError(
          'La categoría tiene transacciones: indica "reasignar_a" con la categoría que las recibirá'
        );
      }
      const target = await this.assertCategory(userId, reasignarA);
      if (reasignarA === id || target.tipo !== cur.rows[0].tipo) {
        throw new ValidationError('La categoría de destino debe ser distinta y del mismo tipo');
      }
      await db.query(`UPDATE transaccion SET categoria_id = $1 WHERE usuario_id = $2 AND categoria_id = $3`, [
        reasignarA,
        userId,
        id,
      ]);
    }
    await db.query(`DELETE FROM regla_categorizacion WHERE usuario_id = $1 AND categoria_id = $2`, [userId, id]);
    await db.query(`DELETE FROM presupuesto WHERE usuario_id = $1 AND categoria_id = $2`, [userId, id]);
    await db.query(`DELETE FROM categoria WHERE id = $1 AND usuario_id = $2`, [id, userId]);
  }
}
