import { db } from '../../infrastructure/database/db.js';
import { NotFoundError, ValidationError } from '../../domain/errors/DomainError.js';
import { DateUtils } from '../../domain/services/DateUtils.js';

export const NOTIFICATION_TYPES = [
  'presupuesto_umbral',
  'presupuesto_superado',
  'cuota_proxima',
  'pago_tarjeta_proximo',
  'importacion_lista',
  'meta_alcanzada',
] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

export interface Notification {
  id: string;
  tipo: string;
  mensaje: string;
  leida: boolean;
  creada_en: Date;
}

export interface NotificationPreference {
  tipo: string;
  canal_app: boolean;
  canal_correo: boolean;
}

const RETENTION_DAYS = 90;
const DEFAULT_LEAD_DAYS = 3;

/**
 * Notificaciones dentro de la aplicación (RF-NOT-01..03). Una notificación de un tipo
 * desactivado por el usuario no se genera (RF-NOT-02). Las de vencimiento son idempotentes:
 * no se repite el mismo aviso para la misma cuota o tarjeta en el mismo ciclo.
 */
export class NotificationService {
  public static async preferences(usuarioId: string): Promise<NotificationPreference[]> {
    const res = await db.query<any>(
      `SELECT tipo, canal_app, canal_correo FROM preferencia_notificacion WHERE usuario_id = $1`,
      [usuarioId]
    );
    const saved = new Map(res.rows.map((r) => [r.tipo as string, r]));
    return NOTIFICATION_TYPES.map((tipo) => {
      const r = saved.get(tipo);
      return {
        tipo,
        canal_app: r ? Boolean(r.canal_app) : true,
        canal_correo: r ? Boolean(r.canal_correo) : false,
      };
    });
  }

  public static async setPreference(
    usuarioId: string,
    tipo: string,
    canalApp: boolean,
    canalCorreo: boolean
  ): Promise<NotificationPreference[]> {
    if (!(NOTIFICATION_TYPES as readonly string[]).includes(tipo)) {
      throw new ValidationError('Tipo de notificación desconocido');
    }
    await db.query(`DELETE FROM preferencia_notificacion WHERE usuario_id = $1 AND tipo = $2`, [usuarioId, tipo]);
    await db.query(
      `INSERT INTO preferencia_notificacion (usuario_id, tipo, canal_app, canal_correo) VALUES ($1, $2, $3, $4)`,
      [usuarioId, tipo, canalApp, canalCorreo]
    );
    return this.preferences(usuarioId);
  }

  /** Crea la notificación si el usuario no desactivó el canal de la aplicación para ese tipo. */
  public static async notify(
    usuarioId: string,
    tipo: NotificationType,
    mensaje: string,
    dedupeKey?: string
  ): Promise<boolean> {
    const prefs = await this.preferences(usuarioId);
    const pref = prefs.find((p) => p.tipo === tipo);
    if (pref && !pref.canal_app && !pref.canal_correo) return false;
    if (pref && !pref.canal_app) return false; // el canal por correo se registra pero no se envía en la demo

    const text = (dedupeKey ? `${mensaje} [${dedupeKey}]` : mensaje).slice(0, 300);
    if (dedupeKey) {
      const dup = await db.query(
        `SELECT 1 FROM notificacion WHERE usuario_id = $1 AND tipo = $2 AND mensaje LIKE $3 LIMIT 1`,
        [usuarioId, tipo, `%[${dedupeKey}]`]
      );
      if (dup.rowCount > 0) return false;
    }
    await db.query(`INSERT INTO notificacion (usuario_id, tipo, mensaje) VALUES ($1, $2, $3)`, [
      usuarioId,
      tipo,
      text,
    ]);
    return true;
  }

  public static clean(mensaje: string): string {
    return mensaje.replace(/\s*\[[^\]]+\]$/, '');
  }

  public static async list(
    usuarioId: string,
    opts: { soloNoLeidas?: boolean; limit?: number } = {}
  ): Promise<{ notifications: Notification[]; no_leidas: number }> {
    const cutoff = DateUtils.addDays(DateUtils.toDateStr(new Date()), -RETENTION_DAYS);
    const res = await db.query<any>(
      `SELECT id, tipo, mensaje, leida, creada_en FROM notificacion
       WHERE usuario_id = $1 AND creada_en >= $2 ${opts.soloNoLeidas ? 'AND leida = FALSE' : ''}
       ORDER BY creada_en DESC LIMIT $3`,
      [usuarioId, cutoff, Math.min(opts.limit ?? 50, 200)]
    );
    const unread = await db.query<any>(
      `SELECT COUNT(*)::text AS n FROM notificacion WHERE usuario_id = $1 AND leida = FALSE`,
      [usuarioId]
    );
    return {
      notifications: res.rows.map((r) => ({
        id: r.id,
        tipo: r.tipo,
        mensaje: this.clean(r.mensaje),
        leida: Boolean(r.leida),
        creada_en: new Date(r.creada_en),
      })),
      no_leidas: parseInt(unread.rows[0]?.n ?? '0', 10),
    };
  }

  public static async markRead(usuarioId: string, id: string): Promise<void> {
    const res = await db.query(
      `UPDATE notificacion SET leida = TRUE WHERE id = $1 AND usuario_id = $2 RETURNING id`,
      [id, usuarioId]
    );
    if (res.rowCount === 0) throw new NotFoundError('Notificación no encontrada');
  }

  public static async markAllRead(usuarioId: string): Promise<void> {
    await db.query(`UPDATE notificacion SET leida = TRUE WHERE usuario_id = $1`, [usuarioId]);
  }

  /**
   * Genera los avisos de vencimiento (cuotas de deuda y pago de tarjeta) con la anticipación
   * configurada (3 días por defecto). Se invoca al consultar el centro de notificaciones.
   */
  public static async refreshDueAlerts(
    usuarioId: string,
    today: string,
    leadDays: number = DEFAULT_LEAD_DAYS
  ): Promise<number> {
    let created = 0;
    const limit = DateUtils.addDays(today, leadDays);

    const cuotas = await db.query<any>(
      `SELECT c.id, c.numero, c.vencimiento, c.monto, c.monto_pagado, d.acreedor
       FROM cuota_deuda c JOIN deuda d ON d.id = c.deuda_id
       WHERE d.usuario_id = $1 AND d.estado = 'activa' AND c.estado != 'pagada'`,
      [usuarioId]
    );
    for (const c of cuotas.rows) {
      const venc = DateUtils.toDateStr(c.vencimiento);
      if (venc >= today && venc <= limit) {
        const pendiente = Number(c.monto) - Number(c.monto_pagado);
        const ok = await this.notify(
          usuarioId,
          'cuota_proxima',
          `La cuota ${c.numero} de ${c.acreedor} (RD$ ${pendiente.toFixed(2)}) vence el ${venc}.`,
          `cuota:${c.id}`
        );
        if (ok) created++;
      }
    }

    const tarjetas = await db.query<any>(
      `SELECT id, nombre, dia_pago FROM cuenta
       WHERE usuario_id = $1 AND tipo = 'tarjeta' AND archivada = FALSE AND dia_pago IS NOT NULL`,
      [usuarioId]
    );
    for (const t of tarjetas.rows) {
      const { y, m } = DateUtils.parse(today);
      const day = Math.min(Number(t.dia_pago), DateUtils.daysInMonth(y, m));
      const fecha = DateUtils.format(y, m, day);
      if (fecha >= today && fecha <= limit) {
        const ok = await this.notify(
          usuarioId,
          'pago_tarjeta_proximo',
          `El pago de la tarjeta ${t.nombre} vence el ${fecha}.`,
          `tarjeta:${t.id}:${fecha}`
        );
        if (ok) created++;
      }
    }
    return created;
  }
}
