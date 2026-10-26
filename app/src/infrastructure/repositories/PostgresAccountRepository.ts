import {
  IAccountRepository,
  CreateAccountData,
  UpdateAccountData,
} from '../../domain/repositories/index.js';
import { Account } from '../../domain/models/index.js';
import { db } from '../database/db.js';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';

export class PostgresAccountRepository implements IAccountRepository {
  public async findById(id: string, usuarioId: string): Promise<Account | null> {
    const res = await db.query<any>(
      `SELECT 
        c.*,
        v.saldo_actual
      FROM cuenta c
      LEFT JOIN vista_saldo_cuenta v ON v.cuenta_id = c.id
      WHERE c.id = $1 AND c.usuario_id = $2
      LIMIT 1`,
      [id, usuarioId]
    );

    if (res.rows.length === 0) return null;
    return this.mapRowToAccount(res.rows[0]);
  }

  public async findByUser(usuarioId: string, includeArchived: boolean = false): Promise<Account[]> {
    let sql = `
      SELECT 
        c.*,
        COALESCE(v.saldo_actual, c.saldo_inicial) as saldo_actual
      FROM cuenta c
      LEFT JOIN vista_saldo_cuenta v ON v.cuenta_id = c.id
      WHERE c.usuario_id = $1
    `;
    const params: any[] = [usuarioId];

    if (!includeArchived) {
      sql += ` AND c.archivada = FALSE`;
    }

    sql += ` ORDER BY c.creada_en ASC`;

    const res = await db.query<any>(sql, params);
    return res.rows.map((row) => this.mapRowToAccount(row));
  }

  public async create(data: CreateAccountData): Promise<Account> {
    const res = await db.query<any>(
      `INSERT INTO cuenta (
        usuario_id,
        nombre,
        tipo,
        moneda,
        saldo_inicial,
        limite_credito,
        dia_corte,
        dia_pago
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *`,
      [
        data.usuario_id,
        data.nombre,
        data.tipo,
        data.moneda || 'DOP',
        FinancialCalculator.roundMoney(data.saldo_inicial || 0),
        data.limite_credito ? FinancialCalculator.roundMoney(data.limite_credito) : null,
        data.dia_corte || null,
        data.dia_pago || null,
      ]
    );

    const created = res.rows[0];
    created.saldo_actual = Number(created.saldo_inicial);
    return this.mapRowToAccount(created);
  }

  public async update(id: string, usuarioId: string, data: UpdateAccountData): Promise<Account> {
    const fields: string[] = [];
    const values: any[] = [];
    let counter = 1;

    if (data.nombre !== undefined) {
      fields.push(`nombre = $${counter++}`);
      values.push(data.nombre);
    }
    if (data.saldo_inicial !== undefined) {
      fields.push(`saldo_inicial = $${counter++}`);
      values.push(FinancialCalculator.roundMoney(data.saldo_inicial));
    }
    if (data.limite_credito !== undefined) {
      fields.push(`limite_credito = $${counter++}`);
      values.push(data.limite_credito ? FinancialCalculator.roundMoney(data.limite_credito) : null);
    }
    if (data.dia_corte !== undefined) {
      fields.push(`dia_corte = $${counter++}`);
      values.push(data.dia_corte);
    }
    if (data.dia_pago !== undefined) {
      fields.push(`dia_pago = $${counter++}`);
      values.push(data.dia_pago);
    }
    if (data.archivada !== undefined) {
      fields.push(`archivada = $${counter++}`);
      values.push(data.archivada);
    }

    values.push(id, usuarioId);
    const sql = `
      UPDATE cuenta 
      SET ${fields.join(', ')} 
      WHERE id = $${counter++} AND usuario_id = $${counter++} 
      RETURNING *
    `;

    const res = await db.query<any>(sql, values);
    if (res.rows.length === 0) {
      throw new Error('Cuenta no encontrada o no pertenece al usuario');
    }

    // Obtener con saldo recalculado
    return (await this.findById(id, usuarioId))!;
  }

  public async archive(id: string, usuarioId: string): Promise<Account> {
    return this.update(id, usuarioId, { archivada: true });
  }

  public async getBalancesSummary(
    usuarioId: string
  ): Promise<{ moneda: string; total_saldo: number; cantidad_cuentas: number }[]> {
    const res = await db.query<any>(
      `SELECT 
        c.moneda,
        COUNT(c.id)::int AS cantidad_cuentas,
        COALESCE(SUM(v.saldo_actual), 0.00)::numeric AS total_saldo
      FROM cuenta c
      LEFT JOIN vista_saldo_cuenta v ON v.cuenta_id = c.id
      WHERE c.usuario_id = $1 AND c.archivada = FALSE
      GROUP BY c.moneda`,
      [usuarioId]
    );

    return res.rows.map((row) => ({
      moneda: row.moneda,
      total_saldo: FinancialCalculator.roundMoney(Number(row.total_saldo)),
      cantidad_cuentas: Number(row.cantidad_cuentas),
    }));
  }

  private mapRowToAccount(row: any): Account {
    return {
      id: row.id,
      usuario_id: row.usuario_id,
      nombre: row.nombre,
      tipo: row.tipo,
      moneda: row.moneda,
      saldo_inicial: Number(row.saldo_inicial),
      limite_credito: row.limite_credito !== null ? Number(row.limite_credito) : null,
      dia_corte: row.dia_corte !== null ? Number(row.dia_corte) : null,
      dia_pago: row.dia_pago !== null ? Number(row.dia_pago) : null,
      archivada: Boolean(row.archivada),
      creada_en: new Date(row.creada_en),
      saldo_actual: row.saldo_actual !== undefined ? FinancialCalculator.roundMoney(Number(row.saldo_actual)) : undefined,
    };
  }
}
