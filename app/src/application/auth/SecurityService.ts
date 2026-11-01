import crypto from 'crypto';
import { db } from '../../infrastructure/database/db.js';
import { PasswordHasher } from '../../infrastructure/security/PasswordHasher.js';
import { SessionService } from '../../infrastructure/security/SessionService.js';
import { Totp } from '../../infrastructure/security/Totp.js';
import { AuditService } from '../audit/AuditService.js';
import { PasswordPolicy } from '../../domain/services/PasswordPolicy.js';
import { NotFoundError, UnauthorizedError, ValidationError } from '../../domain/errors/DomainError.js';
import { env } from '../../config/env.js';

const RESET_MINUTES = 30;
const VERIFY_HOURS = 24;

function sha256(text: string): string {
  return crypto.createHash('sha256').update(text).digest('hex');
}

/**
 * Seguridad de la cuenta: restablecer y cambiar contraseña, verificación de correo, segundo
 * factor, baja de la cuenta, exportación de datos y consentimiento (RF-AUT-02/05/06/07/09/10).
 */
export class SecurityService {
  // ---- Restablecer contraseña (RF-AUT-05) -----------------------------------------------------

  /**
   * Siempre responde igual exista o no el correo (no revela cuentas). En desarrollo devuelve el
   * enlace para poder probar sin servidor de correo; en producción solo se "envía".
   */
  public async requestPasswordReset(email: string): Promise<{ enlace_demo?: string }> {
    const user = await db.query<any>(`SELECT id, email FROM usuario WHERE email = $1`, [email.trim().toLowerCase()]);
    if (user.rowCount === 0) return {};
    const raw = crypto.randomBytes(32).toString('hex');
    await db.query(`UPDATE token_verificacion SET usado_en = now() WHERE usuario_id = $1 AND tipo = 'reset' AND usado_en IS NULL`, [user.rows[0].id]);
    await db.query(
      `INSERT INTO token_verificacion (usuario_id, tipo, token_hash, expira_en) VALUES ($1,'reset',$2,$3)`,
      [user.rows[0].id, sha256(raw), new Date(Date.now() + RESET_MINUTES * 60_000)]
    );
    await AuditService.log(user.rows[0].id, 'password_reset_solicitud');
    return env.NODE_ENV === 'production' ? {} : { enlace_demo: `nexofin://reset?token=${raw}` };
  }

  public async resetPassword(rawToken: string, newPassword: string): Promise<void> {
    PasswordPolicy.assert(newPassword);
    const row = await db.query<any>(
      `SELECT id, usuario_id, expira_en, usado_en FROM token_verificacion WHERE token_hash = $1 AND tipo = 'reset'`,
      [sha256(rawToken)]
    );
    const t = row.rows[0];
    if (!t || t.usado_en || new Date(t.expira_en) < new Date()) {
      throw new ValidationError('El enlace de restablecimiento no es válido o expiró');
    }
    const hash = await PasswordHasher.hash(newPassword);
    await db.query(`UPDATE usuario SET password_hash = $1, intentos_fallidos = 0, bloqueado_hasta = NULL WHERE id = $2`, [hash, t.usuario_id]);
    await db.query(`UPDATE token_verificacion SET usado_en = now() WHERE id = $1`, [t.id]);
    await SessionService.revokeAll(t.usuario_id);
    await AuditService.log(t.usuario_id, 'password_reset');
  }

  // ---- Cambiar contraseña (RF-AUT-06) ---------------------------------------------------------

  public async changePassword(userId: string, currentToken: string, current: string, next: string): Promise<void> {
    const user = await db.query<any>(`SELECT password_hash FROM usuario WHERE id = $1`, [userId]);
    if (user.rowCount === 0) throw new NotFoundError('Usuario no encontrado');
    if (!(await PasswordHasher.compare(current, user.rows[0].password_hash))) {
      await AuditService.log(userId, 'password_cambio', 'fallo');
      throw new UnauthorizedError('La contraseña actual no es correcta');
    }
    PasswordPolicy.assert(next);
    if (current === next) throw new ValidationError('La contraseña nueva debe ser distinta de la actual');
    await db.query(`UPDATE usuario SET password_hash = $1 WHERE id = $2`, [await PasswordHasher.hash(next), userId]);
    await SessionService.revokeAll(userId, currentToken);
    await AuditService.log(userId, 'password_cambio');
  }

  // ---- Verificación de correo (RF-AUT-02) -----------------------------------------------------

  public async requestEmailVerification(userId: string): Promise<{ enlace_demo?: string }> {
    const raw = crypto.randomBytes(32).toString('hex');
    await db.query(
      `INSERT INTO token_verificacion (usuario_id, tipo, token_hash, expira_en) VALUES ($1,'verificacion',$2,$3)`,
      [userId, sha256(raw), new Date(Date.now() + VERIFY_HOURS * 3_600_000)]
    );
    return env.NODE_ENV === 'production' ? {} : { enlace_demo: `nexofin://verify?token=${raw}` };
  }

  public async verifyEmail(rawToken: string): Promise<void> {
    const row = await db.query<any>(
      `SELECT id, usuario_id, expira_en, usado_en FROM token_verificacion WHERE token_hash = $1 AND tipo = 'verificacion'`,
      [sha256(rawToken)]
    );
    const t = row.rows[0];
    if (!t || t.usado_en || new Date(t.expira_en) < new Date()) {
      throw new ValidationError('El enlace de verificación no es válido o expiró');
    }
    await db.query(`UPDATE usuario SET email_verificado = TRUE WHERE id = $1`, [t.usuario_id]);
    await db.query(`UPDATE token_verificacion SET usado_en = now() WHERE id = $1`, [t.id]);
  }

  // ---- Autenticación en dos pasos (RF-AUT-07) -------------------------------------------------

  public async twoFactorSetup(userId: string, email: string): Promise<{ secreto: string; otpauth_url: string }> {
    const secret = Totp.generateSecret();
    await db.query(`UPDATE usuario SET secreto_2fa = $1 WHERE id = $2 AND dos_factores_activo = FALSE`, [secret, userId]);
    return { secreto: secret, otpauth_url: Totp.otpauthUrl(secret, email) };
  }

  public async twoFactorEnable(userId: string, code: string): Promise<void> {
    const u = await db.query<any>(`SELECT secreto_2fa, dos_factores_activo FROM usuario WHERE id = $1`, [userId]);
    const secret = u.rows[0]?.secreto_2fa;
    if (!secret) throw new ValidationError('Primero genera el secreto de verificación en dos pasos');
    if (!Totp.verify(secret, code)) throw new ValidationError('El código de verificación no es correcto');
    await db.query(`UPDATE usuario SET dos_factores_activo = TRUE WHERE id = $1`, [userId]);
    await AuditService.log(userId, 'dos_factores', 'exito', { activo: true });
  }

  /** Desactivar exige reautenticación con la contraseña actual. */
  public async twoFactorDisable(userId: string, password: string): Promise<void> {
    const u = await db.query<any>(`SELECT password_hash FROM usuario WHERE id = $1`, [userId]);
    if (!(await PasswordHasher.compare(password, u.rows[0].password_hash))) {
      await AuditService.log(userId, 'dos_factores', 'fallo');
      throw new UnauthorizedError('La contraseña no es correcta');
    }
    await db.query(`UPDATE usuario SET dos_factores_activo = FALSE, secreto_2fa = NULL WHERE id = $1`, [userId]);
    await AuditService.log(userId, 'dos_factores', 'exito', { activo: false });
  }

  public static async verifySecondFactor(userId: string, code: string | undefined): Promise<boolean> {
    if (!code) return false;
    const u = await db.query<any>(`SELECT secreto_2fa FROM usuario WHERE id = $1`, [userId]);
    return Boolean(u.rows[0]?.secreto_2fa) && Totp.verify(u.rows[0].secreto_2fa, code);
  }

  // ---- Consentimiento de IA ---------------------------------------------------------------------

  public async setAiConsent(userId: string, granted: boolean): Promise<Date | null> {
    const res = await db.query<any>(
      `UPDATE usuario SET consentimiento_ia_en = ${granted ? 'now()' : 'NULL'} WHERE id = $1 RETURNING consentimiento_ia_en`,
      [userId]
    );
    await AuditService.log(userId, 'consentimiento_ia', 'exito', { otorgado: granted });
    return res.rows[0].consentimiento_ia_en ? new Date(res.rows[0].consentimiento_ia_en) : null;
  }

  // ---- Exportar datos (RF-AUT-10) ---------------------------------------------------------------

  public async exportData(userId: string): Promise<Record<string, unknown[]>> {
    const q = async (sql: string) => (await db.query<any>(sql, [userId])).rows;
    const data = {
      cuentas: await q(`SELECT id, nombre, tipo, moneda, saldo_inicial, limite_credito, dia_corte, dia_pago, archivada, creada_en FROM cuenta WHERE usuario_id = $1`),
      categorias: await q(`SELECT id, nombre, tipo, icono, color, archivada FROM categoria WHERE usuario_id = $1`),
      transacciones: await q(`SELECT id, cuenta_id, categoria_id, tipo, sentido, monto, fecha, descripcion, nota, eliminada FROM transaccion WHERE usuario_id = $1 ORDER BY fecha`),
      presupuestos: await q(`SELECT id, categoria_id, mes, monto_limite, umbral_alerta FROM presupuesto WHERE usuario_id = $1`),
      metas: await q(`SELECT id, nombre, monto_objetivo, fecha_limite, estado FROM meta_ahorro WHERE usuario_id = $1`),
      deudas: await q(`SELECT id, acreedor, monto_original, tasa_anual, num_cuotas, fecha_primera_cuota, estado FROM deuda WHERE usuario_id = $1`),
      recurrentes: await q(`SELECT id, cuenta_id, tipo, monto, descripcion, frecuencia, fecha_inicio, fecha_fin, estado FROM transaccion_recurrente WHERE usuario_id = $1`),
    };
    await AuditService.log(userId, 'exportacion', 'exito', { tipo: 'datos_personales' });
    return data;
  }

  // ---- Baja de la cuenta (RF-AUT-09) ------------------------------------------------------------

  /**
   * Exige la contraseña y la confirmación explícita. Elimina los datos del usuario de inmediato
   * (antes del plazo máximo de 30 días) y deja una constancia de auditoría sin datos personales.
   */
  public async deleteAccount(userId: string, password: string, confirmacion: string): Promise<void> {
    if (confirmacion !== 'ELIMINAR') throw new ValidationError('Escribe ELIMINAR para confirmar la baja de la cuenta');
    const u = await db.query<any>(`SELECT email, password_hash FROM usuario WHERE id = $1`, [userId]);
    if (u.rowCount === 0) throw new NotFoundError('Usuario no encontrado');
    if (!(await PasswordHasher.compare(password, u.rows[0].password_hash))) {
      await AuditService.log(userId, 'cuenta_eliminada', 'fallo');
      throw new UnauthorizedError('La contraseña no es correcta');
    }
    const emailHash = sha256(u.rows[0].email).slice(0, 16);
    const client = await db.getClient();
    try {
      await client.query('BEGIN');
      const del = (sql: string) => client.query(sql, [userId]);
      await del(`DELETE FROM mensaje WHERE conversacion_id IN (SELECT id FROM conversacion WHERE usuario_id = $1)`);
      await del(`DELETE FROM conversacion WHERE usuario_id = $1`);
      await del(`DELETE FROM simulacion WHERE usuario_id = $1`);
      await del(`DELETE FROM aplicacion_pago WHERE pago_id IN (SELECT id FROM pago_deuda WHERE deuda_id IN (SELECT id FROM deuda WHERE usuario_id = $1))`);
      await del(`DELETE FROM pago_deuda WHERE deuda_id IN (SELECT id FROM deuda WHERE usuario_id = $1)`);
      await del(`DELETE FROM cuota_deuda WHERE deuda_id IN (SELECT id FROM deuda WHERE usuario_id = $1)`);
      await del(`DELETE FROM deuda WHERE usuario_id = $1`);
      await del(`DELETE FROM aporte_meta WHERE meta_id IN (SELECT id FROM meta_ahorro WHERE usuario_id = $1)`);
      await del(`DELETE FROM meta_ahorro WHERE usuario_id = $1`);
      await del(`DELETE FROM movimiento_importado WHERE importacion_id IN (SELECT id FROM importacion WHERE usuario_id = $1)`);
      await del(`UPDATE transaccion SET transferencia_vinculada_id = NULL WHERE usuario_id = $1`);
      await del(`DELETE FROM transaccion_historial WHERE usuario_id = $1`);
      await del(`DELETE FROM transaccion WHERE usuario_id = $1`);
      await del(`DELETE FROM importacion WHERE usuario_id = $1`);
      await del(`DELETE FROM transaccion_recurrente WHERE usuario_id = $1`);
      await del(`DELETE FROM presupuesto WHERE usuario_id = $1`);
      await del(`DELETE FROM regla_categorizacion WHERE usuario_id = $1`);
      await del(`DELETE FROM categoria WHERE usuario_id = $1`);
      await del(`DELETE FROM cuenta WHERE usuario_id = $1`);
      await del(`DELETE FROM notificacion WHERE usuario_id = $1`);
      await del(`DELETE FROM preferencia_notificacion WHERE usuario_id = $1`);
      await del(`DELETE FROM sesion WHERE usuario_id = $1`);
      await del(`DELETE FROM token_verificacion WHERE usuario_id = $1`);
      await del(`UPDATE bitacora_auditoria SET usuario_id = NULL WHERE usuario_id = $1`);
      await del(`DELETE FROM usuario WHERE id = $1`);
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
    await AuditService.log(null, 'cuenta_eliminada', 'exito', { referencia: emailHash });
  }
}
