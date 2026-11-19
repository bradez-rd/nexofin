import crypto from 'crypto';
import { db } from '../../infrastructure/database/db.js';
import { DocumentReader } from '../../infrastructure/documents/DocumentReader.js';
import { insertLedgerEntry } from '../../infrastructure/repositories/LedgerWriter.js';
import { StatementParser, ColumnMapping, ParseResult } from '../../domain/services/StatementParser.js';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';
import { DateUtils } from '../../domain/services/DateUtils.js';
import { DateRules } from '../../domain/services/DateRules.js';
import { AppError, NotFoundError, ValidationError } from '../../domain/errors/DomainError.js';
import { CategorizationService } from '../categories/CategorizationService.js';
import { BudgetService } from '../budgets/BudgetService.js';
import { NotificationService } from '../notifications/NotificationService.js';
import { AuditService } from '../audit/AuditService.js';
import { env } from '../../config/env.js';

export const IMPORT_MAX_BYTES = 5 * 1024 * 1024;
const REVERT_DAYS = 30;

export interface ImportMovement {
  id: string;
  fecha: string;
  monto: number;
  sentido: 'entrada' | 'salida';
  descripcion: string;
  duplicado_potencial: boolean;
  categoria_sugerida_id: string | null;
  confianza: number | null;
  decision: 'pendiente' | 'aprobado' | 'excluido';
  transaccion_id: string | null;
}

/** Error que devuelve las columnas y una muestra para que el usuario indique el mapeo (RF-IMP-02). */
export class MappingRequiredError extends AppError {
  constructor(public readonly columnas: string[], public readonly muestra: unknown[][]) {
    super('No se reconocieron las columnas del archivo: indica cuál corresponde a fecha, monto y descripción', 422, { columnas, muestra });
  }
}

const ESTADOS_REVISION = ['lista_revision'];

/**
 * Importación de estados de cuenta (RF-IMP-01 a 08): lectura, detección de duplicados, revisión
 * previa, confirmación atómica (todo o nada) y reversión dentro de 30 días.
 */
export class ImportService {
  constructor(
    private readonly categorization = new CategorizationService(),
    private readonly budgets = new BudgetService()
  ) {}

  private signature(headers: unknown[]): string {
    return crypto.createHash('sha256').update(headers.map((h) => String(h ?? '').toLowerCase().trim()).join('|')).digest('hex').slice(0, 24);
  }

  private async savedMapping(userId: string, sig: string): Promise<ColumnMapping | null> {
    const res = await db.query<any>(
      `SELECT mapeo_columnas FROM importacion WHERE usuario_id = $1 AND mapeo_columnas IS NOT NULL ORDER BY creada_en DESC LIMIT 50`,
      [userId]
    );
    for (const r of res.rows) {
      const m = typeof r.mapeo_columnas === 'string' ? JSON.parse(r.mapeo_columnas) : r.mapeo_columnas;
      if (m?.firma === sig) return m.mapeo as ColumnMapping;
    }
    return null;
  }

  private async fail(importId: string, motivo: string): Promise<never> {
    await db.query(`UPDATE importacion SET estado = 'fallida', motivo_fallo = $1 WHERE id = $2`, [motivo.slice(0, 300), importId]);
    throw new ValidationError(motivo);
  }

  public async upload(
    userId: string,
    data: { cuenta_id: string; nombre_archivo: string; contenido_base64: string; mapeo?: ColumnMapping; guardar_mapeo?: boolean }
  ) {
    const acc = await db.query<any>(`SELECT id, archivada FROM cuenta WHERE id = $1 AND usuario_id = $2`, [data.cuenta_id, userId]);
    if (acc.rowCount === 0) throw new NotFoundError('La cuenta no existe o no pertenece al usuario');
    if (acc.rows[0].archivada) throw new ValidationError('La cuenta está archivada');

    // Validaciones previas al archivo: no afectan al resto de la sesión (RF-IMP-01)
    const kind = DocumentReader.kindOf(data.nombre_archivo);
    const buffer = Buffer.from(data.contenido_base64, 'base64');
    if (buffer.length > IMPORT_MAX_BYTES) {
      throw new ValidationError(`El archivo supera el tamaño máximo de ${Math.round(IMPORT_MAX_BYTES / 1024 / 1024)} MB`);
    }

    const created = await db.query<any>(
      `INSERT INTO importacion (usuario_id, cuenta_id, nombre_archivo, tipo_archivo, estado) VALUES ($1,$2,$3,$4,'procesando') RETURNING id`,
      [userId, data.cuenta_id, data.nombre_archivo.slice(0, 255), kind]
    );
    const importId = created.rows[0].id as string;

    let raw;
    try {
      raw = await DocumentReader.read(data.nombre_archivo, buffer);
    } catch (e: any) {
      return this.fail(importId, e.message);
    }

    let parsed: ParseResult;
    let mappingToSave: { firma: string; mapeo: ColumnMapping } | null = null;
    if (raw.kind === 'pdf') {
      parsed = StatementParser.parsePdfLines(raw.lines ?? []);
    } else {
      const rows = raw.rows ?? [];
      if (rows.length < 2) return this.fail(importId, 'El archivo no tiene movimientos para importar');
      const firma = this.signature(rows[0]);
      const mapping =
        data.mapeo ?? (await this.savedMapping(userId, firma)) ?? StatementParser.detectMapping(rows[0].map((c) => String(c ?? '')));
      if (!mapping) {
        await db.query(`DELETE FROM importacion WHERE id = $1`, [importId]);
        throw new MappingRequiredError(rows[0].map((c) => String(c ?? '')), rows.slice(1, 6));
      }
      parsed = StatementParser.parseRows(rows, mapping, true);
      if (data.mapeo && data.guardar_mapeo !== false) mappingToSave = { firma, mapeo: mapping };
    }
    if (parsed.movimientos.length === 0) {
      return this.fail(importId, 'No se encontraron movimientos válidos en el archivo');
    }

    // Duplicados contra lo ya registrado y dentro del propio archivo (RF-IMP-05)
    const existing = await db.query<any>(`SELECT huella, eliminada FROM transaccion WHERE usuario_id = $1 AND cuenta_id = $2`, [userId, data.cuenta_id]);
    const known = new Set(existing.rows.filter((r) => !r.eliminada && r.huella).map((r) => r.huella as string));
    const seen = new Set<string>();

    const client = await db.getClient();
    try {
      await client.query('BEGIN');
      for (const m of parsed.movimientos) {
        const huella = FinancialCalculator.generateFingerprint(data.cuenta_id, m.fecha, m.monto, m.descripcion);
        const dup = known.has(huella) || seen.has(huella);
        seen.add(huella);
        const cls = await this.categorization.classify(userId, m.descripcion, m.sentido === 'entrada' ? 'ingreso' : 'gasto');
        await client.query(
          `INSERT INTO movimiento_importado
             (importacion_id, fecha, monto, sentido, descripcion, huella, duplicado_potencial, categoria_sugerida_id, confianza, decision)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
          [importId, m.fecha, m.monto, m.sentido, m.descripcion, huella, dup, cls.categoria_id, cls.confianza || null, dup ? 'excluido' : 'aprobado']
        );
      }
      await client.query(
        `UPDATE importacion SET estado = 'lista_revision', mapeo_columnas = $1, eliminar_documento_en = $2 WHERE id = $3`,
        [mappingToSave ? JSON.stringify(mappingToSave) : null, DateUtils.addDays(DateRules.todayIn(env.TIMEZONE), REVERT_DAYS), importId]
      );
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      await db.query(`UPDATE importacion SET estado = 'fallida', motivo_fallo = $1 WHERE id = $2`, ['Error interno al guardar los movimientos', importId]);
      throw err;
    } finally {
      client.release();
    }
    await NotificationService.notify(userId, 'importacion_lista', `Tu importación "${data.nombre_archivo}" está lista para revisión.`, `imp:${importId}`);
    return { ...(await this.get(userId, importId)), filas_con_error: parsed.errores };
  }

  public async list(userId: string) {
    const res = await db.query<any>(
      `SELECT id, cuenta_id, nombre_archivo, tipo_archivo, estado, motivo_fallo, creada_en, confirmada_en FROM importacion
       WHERE usuario_id = $1 ORDER BY creada_en DESC LIMIT 100`,
      [userId]
    );
    return res.rows.map((r) => ({ ...r, creada_en: new Date(r.creada_en) }));
  }

  private mapMovement(r: any): ImportMovement {
    return {
      id: r.id,
      fecha: DateUtils.toDateStr(r.fecha),
      monto: Number(r.monto),
      sentido: r.sentido,
      descripcion: r.descripcion,
      duplicado_potencial: Boolean(r.duplicado_potencial),
      categoria_sugerida_id: r.categoria_sugerida_id,
      confianza: r.confianza !== null ? Number(r.confianza) : null,
      decision: r.decision,
      transaccion_id: r.transaccion_id,
    };
  }

  /** Estado de la importación y resumen previo a confirmar (RF-IMP-04/06). */
  public async get(userId: string, id: string) {
    const imp = await db.query<any>(`SELECT * FROM importacion WHERE id = $1 AND usuario_id = $2`, [id, userId]);
    if (imp.rowCount === 0) throw new NotFoundError('Importación no encontrada');
    const mov = await db.query<any>(`SELECT * FROM movimiento_importado WHERE importacion_id = $1 ORDER BY fecha ASC, descripcion ASC`, [id]);
    const movimientos = mov.rows.map((r) => this.mapMovement(r));
    const aprobados = movimientos.filter((m) => m.decision === 'aprobado');
    const i = imp.rows[0];
    return {
      importacion: {
        id: i.id,
        cuenta_id: i.cuenta_id,
        nombre_archivo: i.nombre_archivo,
        tipo_archivo: i.tipo_archivo,
        estado: i.estado,
        motivo_fallo: i.motivo_fallo,
        creada_en: new Date(i.creada_en),
        confirmada_en: i.confirmada_en ? new Date(i.confirmada_en) : null,
      },
      resumen: {
        detectados: movimientos.length,
        duplicados_potenciales: movimientos.filter((m) => m.duplicado_potencial).length,
        sin_categoria_sugerida: movimientos.filter((m) => !m.categoria_sugerida_id).length,
        aprobados: aprobados.length,
        excluidos: movimientos.filter((m) => m.decision === 'excluido').length,
        total_entradas: FinancialCalculator.roundMoney(aprobados.filter((m) => m.sentido === 'entrada').reduce((s, m) => s + m.monto, 0)),
        total_salidas: FinancialCalculator.roundMoney(aprobados.filter((m) => m.sentido === 'salida').reduce((s, m) => s + m.monto, 0)),
      },
      movimientos,
    };
  }

  private async assertReviewable(userId: string, id: string) {
    const imp = await db.query<any>(`SELECT * FROM importacion WHERE id = $1 AND usuario_id = $2`, [id, userId]);
    if (imp.rowCount === 0) throw new NotFoundError('Importación no encontrada');
    if (!ESTADOS_REVISION.includes(imp.rows[0].estado)) {
      throw new ValidationError(`La importación está en estado "${imp.rows[0].estado}" y ya no se puede modificar`);
    }
    return imp.rows[0];
  }

  /** Edita, excluye o aprueba un movimiento antes de guardar (RF-IMP-06). */
  public async updateMovement(
    userId: string,
    importId: string,
    movementId: string,
    data: { decision?: 'aprobado' | 'excluido'; fecha?: string; monto?: number; descripcion?: string; categoria_id?: string | null }
  ) {
    const imp = await this.assertReviewable(userId, importId);
    const cur = await db.query<any>(`SELECT * FROM movimiento_importado WHERE id = $1 AND importacion_id = $2`, [movementId, importId]);
    if (cur.rowCount === 0) throw new NotFoundError('Movimiento no encontrado');
    const m = cur.rows[0];
    const fecha = data.fecha ?? DateUtils.toDateStr(m.fecha);
    const monto = data.monto ?? Number(m.monto);
    const descripcion = (data.descripcion ?? m.descripcion).trim();
    if (!DateRules.isRealDate(fecha)) throw new ValidationError('La fecha no es válida');
    if (!(monto > 0)) throw new ValidationError('El monto debe ser mayor que cero');
    if (!descripcion) throw new ValidationError('La descripción no puede estar vacía');
    if (data.categoria_id) {
      const c = await db.query<any>(`SELECT tipo FROM categoria WHERE id = $1 AND (usuario_id = $2 OR usuario_id IS NULL) AND archivada = FALSE`, [data.categoria_id, userId]);
      if (c.rowCount === 0) throw new NotFoundError('La categoría no existe');
      if (c.rows[0].tipo !== (m.sentido === 'entrada' ? 'ingreso' : 'gasto')) throw new ValidationError('La categoría no coincide con el sentido del movimiento');
    }
    const huella = FinancialCalculator.generateFingerprint(imp.cuenta_id, fecha, monto, descripcion);
    await db.query(
      `UPDATE movimiento_importado SET fecha = $1, monto = $2, descripcion = $3, huella = $4, categoria_sugerida_id = $5, decision = $6 WHERE id = $7`,
      [
        fecha,
        FinancialCalculator.roundMoney(monto),
        descripcion,
        huella,
        data.categoria_id === undefined ? m.categoria_sugerida_id : data.categoria_id,
        data.decision ?? m.decision,
        movementId,
      ]
    );
    return this.get(userId, importId);
  }

  public async cancel(userId: string, id: string) {
    await this.assertReviewable(userId, id);
    await db.query(`UPDATE importacion SET estado = 'cancelada' WHERE id = $1`, [id]);
    return this.get(userId, id);
  }

  /** Guarda todos los movimientos aprobados o ninguno (RF-IMP-07). */
  public async confirm(userId: string, id: string) {
    const imp = await this.assertReviewable(userId, id);
    const approved = await db.query<any>(`SELECT * FROM movimiento_importado WHERE importacion_id = $1 AND decision = 'aprobado' ORDER BY fecha ASC`, [id]);
    if (approved.rowCount === 0) throw new ValidationError('No hay movimientos aprobados para guardar');

    const client = await db.getClient();
    const touched: { categoria: string | null; fecha: string; sentido: string }[] = [];
    try {
      await client.query('BEGIN');
      for (const m of approved.rows) {
        const sentido = m.sentido as 'entrada' | 'salida';
        const categoria = m.categoria_sugerida_id as string | null;
        const t = await insertLedgerEntry(client, {
          usuario_id: userId,
          cuenta_id: imp.cuenta_id,
          categoria_id: categoria,
          tipo: sentido === 'entrada' ? 'ingreso' : 'gasto',
          sentido,
          monto: Number(m.monto),
          fecha: DateUtils.toDateStr(m.fecha),
          descripcion: m.descripcion,
          importacion_id: id,
          estado_categoria: categoria ? 'categorizada' : 'sin_categoria',
          confianza: m.confianza !== null ? Number(m.confianza) : null,
        });
        await client.query(`UPDATE movimiento_importado SET transaccion_id = $1 WHERE id = $2`, [t.id, m.id]);
        touched.push({ categoria, fecha: DateUtils.toDateStr(m.fecha), sentido });
      }
      await client.query(`UPDATE importacion SET estado = 'confirmada', confirmada_en = now() WHERE id = $1`, [id]);
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK'); // ningún movimiento queda parcial
      throw new ValidationError('No se pudo guardar la importación; no se registró ningún movimiento. Inténtalo de nuevo');
    } finally {
      client.release();
    }
    await AuditService.log(userId, 'importacion_confirmada', 'exito', { importacion_id: id, movimientos: approved.rowCount });
    for (const t of touched) if (t.sentido === 'salida') await this.budgets.checkAfterChange(userId, t.categoria, t.fecha);
    return this.get(userId, id);
  }

  /** Deshace una importación confirmada dentro de los 30 días siguientes (RF-IMP-08). */
  public async revert(userId: string, id: string) {
    const imp = await db.query<any>(`SELECT * FROM importacion WHERE id = $1 AND usuario_id = $2`, [id, userId]);
    if (imp.rowCount === 0) throw new NotFoundError('Importación no encontrada');
    const i = imp.rows[0];
    if (i.estado !== 'confirmada') throw new ValidationError('Solo se puede deshacer una importación confirmada');
    const days = (Date.now() - new Date(i.confirmada_en).getTime()) / 86_400_000;
    if (days > REVERT_DAYS) throw new ValidationError(`Solo se puede deshacer dentro de los ${REVERT_DAYS} días siguientes a la confirmación`);
    const client = await db.getClient();
    try {
      await client.query('BEGIN');
      await client.query(`UPDATE transaccion SET eliminada = TRUE, eliminada_en = now() WHERE importacion_id = $1 AND usuario_id = $2 AND eliminada = FALSE`, [id, userId]);
      await client.query(`UPDATE importacion SET estado = 'revertida' WHERE id = $1`, [id]);
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
    await AuditService.log(userId, 'importacion_revertida', 'exito', { importacion_id: id });
    return this.get(userId, id);
  }
}
