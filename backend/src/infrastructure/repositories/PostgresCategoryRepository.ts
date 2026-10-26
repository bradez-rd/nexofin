import { ICategoryRepository } from '../../domain/repositories/index.js';
import { Category } from '../../domain/models/index.js';
import { db } from '../database/db.js';

export class PostgresCategoryRepository implements ICategoryRepository {
  public async findById(id: string): Promise<Category | null> {
    const res = await db.query<any>(
      `SELECT * FROM categoria WHERE id = $1 LIMIT 1`,
      [id]
    );
    if (res.rows.length === 0) return null;
    return this.mapRowToCategory(res.rows[0]);
  }

  public async findAllForUser(
    usuarioId: string,
    tipo?: 'ingreso' | 'gasto'
  ): Promise<Category[]> {
    let sql = `
      SELECT * FROM categoria
      WHERE (usuario_id = $1 OR usuario_id IS NULL) AND archivada = FALSE
    `;
    const params: any[] = [usuarioId];

    if (tipo) {
      sql += ` AND tipo = $2`;
      params.push(tipo);
    }

    sql += ` ORDER BY es_sistema DESC, nombre ASC`;

    const res = await db.query<any>(sql, params);
    return res.rows.map((row) => this.mapRowToCategory(row));
  }

  public async create(
    usuarioId: string,
    nombre: string,
    tipo: 'ingreso' | 'gasto',
    icono?: string,
    color?: string
  ): Promise<Category> {
    const res = await db.query<any>(
      `INSERT INTO categoria (
        usuario_id,
        nombre,
        tipo,
        icono,
        color,
        es_sistema,
        archivada
      ) VALUES ($1, $2, $3, $4, $5, FALSE, FALSE)
      RETURNING *`,
      [usuarioId, nombre, tipo, icono || 'category', color || '#6B7280']
    );

    return this.mapRowToCategory(res.rows[0]);
  }

  private mapRowToCategory(row: any): Category {
    return {
      id: row.id,
      usuario_id: row.usuario_id,
      nombre: row.nombre,
      tipo: row.tipo,
      icono: row.icono,
      color: row.color,
      es_sistema: Boolean(row.es_sistema),
      archivada: Boolean(row.archivada),
    };
  }
}
