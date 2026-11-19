import { db } from '../../infrastructure/database/db.js';
import { DateUtils } from '../../domain/services/DateUtils.js';

export type AuditAction =
  | 'login'
  | 'logout'
  | 'registro'
  | 'password_cambio'
  | 'password_reset_solicitud'
  | 'password_reset'
  | 'dos_factores'
  | 'cuenta_saldo_editado'
  | 'transaccion_eliminada'
  | 'importacion_confirmada'
  | 'importacion_revertida'
  | 'exportacion'
  | 'cuenta_eliminada'
  | 'consentimiento_ia';

export interface AuditEntry {
  id: number;
  accion: string;
  resultado: 'exito' | 'fallo';
  detalle: Record<string, unknown> | null;
  fecha: Date;
}

const SENSITIVE_KEYS = /pass|token|secret|clave|hash/i;

/**
 * Bitácora de auditoría (RF-AUD-01). Solo se agrega: no existe ninguna operación de
 * actualización ni de borrado. Los detalles se limpian para no guardar datos sensibles en claro.
 */
export class AuditService {
  public static sanitize(detalle?: Record<string, unknown>): Record<string, unknown> | null {
    if (!detalle) return null;
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(detalle)) {
      out[k] = SENSITIVE_KEYS.test(k) ? '[omitido]' : v;
    }
    return out;
  }

  /** Registra una acción. Un fallo de auditoría nunca debe romper la operación principal. */
  public static async log(
    usuarioId: string | null,
    accion: AuditAction,
    resultado: 'exito' | 'fallo' = 'exito',
    detalle?: Record<string, unknown>
  ): Promise<void> {
    try {
      await db.query(
        `INSERT INTO bitacora_auditoria (usuario_id, accion, resultado, detalle) VALUES ($1, $2, $3, $4)`,
        [usuarioId, accion, resultado, detalle ? JSON.stringify(this.sanitize(detalle)) : null]
      );
    } catch (err: any) {
      console.error('[Audit] No se pudo registrar la acción:', err.message);
    }
  }

  /** Actividad reciente de la cuenta (RF-AUD-02): inicios de sesión y cambios de seguridad. */
  public static async recentActivity(usuarioId: string, limit = 20): Promise<AuditEntry[]> {
    const res = await db.query<any>(
      `SELECT id, accion, resultado, detalle, fecha FROM bitacora_auditoria
       WHERE usuario_id = $1 ORDER BY fecha DESC, id DESC LIMIT $2`,
      [usuarioId, Math.min(Math.max(limit, 1), 100)]
    );
    return res.rows.map((r) => ({
      id: Number(r.id),
      accion: r.accion,
      resultado: r.resultado,
      detalle: typeof r.detalle === 'string' ? JSON.parse(r.detalle) : r.detalle,
      fecha: new Date(r.fecha),
    }));
  }

  public static today(): string {
    return DateUtils.toDateStr(new Date());
  }
}
