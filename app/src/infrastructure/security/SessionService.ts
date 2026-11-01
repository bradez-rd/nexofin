import crypto from 'crypto';
import { db } from '../database/db.js';

/** Sesiones revocables (RF-AUT-04/05): el JWT solo es válido mientras su sesión no esté revocada. */
export class SessionService {
  public static hash(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  public static async create(userId: string, token: string): Promise<void> {
    await db.query(`INSERT INTO sesion (usuario_id, token_hash) VALUES ($1, $2)`, [userId, this.hash(token)]);
  }

  public static async isActive(token: string): Promise<boolean> {
    const res = await db.query<any>(`SELECT revocada FROM sesion WHERE token_hash = $1 LIMIT 1`, [this.hash(token)]);
    return res.rowCount > 0 && !res.rows[0].revocada;
  }

  public static async revoke(token: string): Promise<void> {
    await db.query(`UPDATE sesion SET revocada = TRUE WHERE token_hash = $1`, [this.hash(token)]);
  }

  /** Revoca todas las sesiones del usuario, salvo la indicada (cambio o restablecimiento de contraseña). */
  public static async revokeAll(userId: string, exceptToken?: string): Promise<void> {
    if (exceptToken) {
      await db.query(`UPDATE sesion SET revocada = TRUE WHERE usuario_id = $1 AND token_hash != $2`, [
        userId,
        this.hash(exceptToken),
      ]);
    } else {
      await db.query(`UPDATE sesion SET revocada = TRUE WHERE usuario_id = $1`, [userId]);
    }
  }
}
