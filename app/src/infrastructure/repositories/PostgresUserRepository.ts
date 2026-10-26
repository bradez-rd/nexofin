import {
  IUserRepository,
  CreateUserData,
  UpdateUserData,
} from '../../domain/repositories/index.js';
import { User } from '../../domain/models/index.js';
import { db } from '../database/db.js';

export class PostgresUserRepository implements IUserRepository {
  public async findById(id: string): Promise<User | null> {
    const res = await db.query<User>(
      `SELECT * FROM usuario WHERE id = $1 LIMIT 1`,
      [id]
    );
    return res.rows[0] || null;
  }

  public async findByEmail(email: string): Promise<User | null> {
    const res = await db.query<User>(
      `SELECT * FROM usuario WHERE LOWER(email) = LOWER($1) LIMIT 1`,
      [email]
    );
    return res.rows[0] || null;
  }

  public async create(data: CreateUserData): Promise<User> {
    const res = await db.query<User>(
      `INSERT INTO usuario (
        nombre,
        email,
        password_hash,
        moneda_predeterminada,
        zona_horaria
      ) VALUES ($1, LOWER($2), $3, $4, $5)
      RETURNING *`,
      [
        data.nombre,
        data.email,
        data.password_hash,
        data.moneda_predeterminada || 'DOP',
        data.zona_horaria || 'America/Santo_Domingo',
      ]
    );
    return res.rows[0];
  }

  public async update(id: string, data: UpdateUserData): Promise<User> {
    const fields: string[] = [];
    const values: any[] = [];
    let counter = 1;

    if (data.nombre !== undefined) {
      fields.push(`nombre = $${counter++}`);
      values.push(data.nombre);
    }
    if (data.foto_url !== undefined) {
      fields.push(`foto_url = $${counter++}`);
      values.push(data.foto_url);
    }
    if (data.moneda_predeterminada !== undefined) {
      fields.push(`moneda_predeterminada = $${counter++}`);
      values.push(data.moneda_predeterminada);
    }
    if (data.zona_horaria !== undefined) {
      fields.push(`zona_horaria = $${counter++}`);
      values.push(data.zona_horaria);
    }

    values.push(id);
    const sql = `UPDATE usuario SET ${fields.join(', ')} WHERE id = $${counter} RETURNING *`;
    const res = await db.query<User>(sql, values);
    return res.rows[0];
  }

  public async updateFailedAttempts(id: string, attempts: number, lockUntil?: Date | null): Promise<void> {
    await db.query(
      `UPDATE usuario SET intentos_fallidos = $1, bloqueado_hasta = $2 WHERE id = $3`,
      [attempts, lockUntil || null, id]
    );
  }

  public async resetFailedAttempts(id: string): Promise<void> {
    await db.query(
      `UPDATE usuario SET intentos_fallidos = 0, bloqueado_hasta = NULL WHERE id = $1`,
      [id]
    );
  }
}
