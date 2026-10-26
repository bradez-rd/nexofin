import {
  ITransactionRepository,
  TransactionFilter,
  CreateTransactionData,
  UpdateTransactionData,
} from '../../domain/repositories/index.js';
import { Transaction } from '../../domain/models/index.js';
import { db } from '../database/db.js';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';

export class PostgresTransactionRepository implements ITransactionRepository {
  public async findById(id: string, usuarioId: string): Promise<Transaction | null> {
    const res = await db.query<any>(
      `SELECT * FROM transaccion 
       WHERE id = $1 AND usuario_id = $2 AND eliminada = FALSE 
       LIMIT 1`,
      [id, usuarioId]
    );

    if (res.rows.length === 0) return null;
    return this.mapRowToTransaction(res.rows[0]);
  }

  public async findByFingerprint(huella: string, usuarioId: string): Promise<Transaction | null> {
    const res = await db.query<any>(
      `SELECT * FROM transaccion 
       WHERE huella = $1 AND usuario_id = $2 AND eliminada = FALSE 
       LIMIT 1`,
      [huella, usuarioId]
    );

    if (res.rows.length === 0) return null;
    return this.mapRowToTransaction(res.rows[0]);
  }

  public async findByUser(
    usuarioId: string,
    filter: TransactionFilter = {}
  ): Promise<{ transactions: Transaction[]; total: number }> {
    const conditions: string[] = ['usuario_id = $1', 'eliminada = FALSE'];
    const params: any[] = [usuarioId];
    let counter = 2;

    if (filter.cuenta_id) {
      conditions.push(`cuenta_id = $${counter++}`);
      params.push(filter.cuenta_id);
    }
    if (filter.categoria_id) {
      conditions.push(`categoria_id = $${counter++}`);
      params.push(filter.categoria_id);
    }
    if (filter.tipo) {
      conditions.push(`tipo = $${counter++}`);
      params.push(filter.tipo);
    }
    if (filter.fecha_inicio) {
      conditions.push(`fecha >= $${counter++}`);
      params.push(filter.fecha_inicio);
    }
    if (filter.fecha_fin) {
      conditions.push(`fecha <= $${counter++}`);
      params.push(filter.fecha_fin);
    }
    if (filter.busqueda) {
      conditions.push(`(LOWER(descripcion) LIKE $${counter} OR LOWER(nota) LIKE $${counter})`);
      params.push(`%${filter.busqueda.toLowerCase()}%`);
      counter++;
    }

    const whereClause = conditions.join(' AND ');

    // Conteo total
    const countRes = await db.query<{ count: string }>(
      `SELECT COUNT(*)::text as count FROM transaccion WHERE ${whereClause}`,
      params
    );
    const total = parseInt(countRes.rows[0]?.count || '0', 10);

    // Consulta de registros paginada
    const limit = filter.limit || 20;
    const offset = filter.offset || 0;
    params.push(limit, offset);

    const querySql = `
      SELECT * FROM transaccion
      WHERE ${whereClause}
      ORDER BY fecha DESC, creada_en DESC
      LIMIT $${counter++} OFFSET $${counter++}
    `;

    const res = await db.query<any>(querySql, params);
    return {
      transactions: res.rows.map((r) => this.mapRowToTransaction(r)),
      total,
    };
  }

  public async create(data: CreateTransactionData): Promise<Transaction> {
    const res = await db.query<any>(
      `INSERT INTO transaccion (
        usuario_id,
        cuenta_id,
        categoria_id,
        tipo,
        sentido,
        monto,
        fecha,
        descripcion,
        nota,
        transferencia_vinculada_id,
        huella
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING *`,
      [
        data.usuario_id,
        data.cuenta_id,
        data.categoria_id || null,
        data.tipo,
        data.sentido,
        FinancialCalculator.roundMoney(data.monto),
        data.fecha,
        data.descripcion || null,
        data.nota || null,
        data.transferencia_vinculada_id || null,
        data.huella || null,
      ]
    );

    return this.mapRowToTransaction(res.rows[0]);
  }

  public async createTransfer(
    usuarioId: string,
    cuentaOrigenId: string,
    cuentaDestinoId: string,
    monto: number,
    fecha: string,
    descripcion?: string
  ): Promise<{ salida: Transaction; entrada: Transaction }> {
    const client = await db.getClient();
    const roundedMonto = FinancialCalculator.roundMoney(monto);
    const descSalida = descripcion || 'Transferencia enviada';
    const descEntrada = descripcion || 'Transferencia recibida';

    try {
      await client.query('BEGIN');

      // 1. Salida de la cuenta origen
      const huellaSalida = FinancialCalculator.generateFingerprint(cuentaOrigenId, fecha, roundedMonto, descSalida);
      const salidaRes = await client.query<any>(
        `INSERT INTO transaccion (
          usuario_id, cuenta_id, tipo, sentido, monto, fecha, descripcion, huella
        ) VALUES ($1, $2, 'transferencia', 'salida', $3, $4, $5, $6)
        RETURNING *`,
        [usuarioId, cuentaOrigenId, roundedMonto, fecha, descSalida, huellaSalida]
      );
      const salidaRow = salidaRes.rows[0];

      // 2. Entrada a la cuenta destino
      const huellaEntrada = FinancialCalculator.generateFingerprint(cuentaDestinoId, fecha, roundedMonto, descEntrada);
      const entradaRes = await client.query<any>(
        `INSERT INTO transaccion (
          usuario_id, cuenta_id, tipo, sentido, monto, fecha, descripcion, transferencia_vinculada_id, huella
        ) VALUES ($1, $2, 'transferencia', 'entrada', $3, $4, $5, $6, $7)
        RETURNING *`,
        [usuarioId, cuentaDestinoId, roundedMonto, fecha, descEntrada, salidaRow.id, huellaEntrada]
      );
      const entradaRow = entradaRes.rows[0];

      // 3. Vincular salida con entrada
      await client.query(
        `UPDATE transaccion SET transferencia_vinculada_id = $1 WHERE id = $2`,
        [entradaRow.id, salidaRow.id]
      );
      salidaRow.transferencia_vinculada_id = entradaRow.id;

      await client.query('COMMIT');

      return {
        salida: this.mapRowToTransaction(salidaRow),
        entrada: this.mapRowToTransaction(entradaRow),
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  public async update(
    id: string,
    usuarioId: string,
    data: UpdateTransactionData,
    oldValuesSnapshot: Record<string, unknown>
  ): Promise<Transaction> {
    const client = await db.getClient();

    try {
      await client.query('BEGIN');

      // 1. Registrar histórico anterior (RF-TRX-03 / RN-DAT-04)
      await client.query(
        `INSERT INTO transaccion_historial (transaccion_id, usuario_id, valores_anteriores)
         VALUES ($1, $2, $3)`,
        [id, usuarioId, JSON.stringify(oldValuesSnapshot)]
      );

      // 2. Aplicar actualización
      const fields: string[] = [];
      const values: any[] = [];
      let counter = 1;

      if (data.categoria_id !== undefined) {
        fields.push(`categoria_id = $${counter++}`);
        values.push(data.categoria_id);
      }
      if (data.monto !== undefined) {
        fields.push(`monto = $${counter++}`);
        values.push(FinancialCalculator.roundMoney(data.monto));
      }
      if (data.fecha !== undefined) {
        fields.push(`fecha = $${counter++}`);
        values.push(data.fecha);
      }
      if (data.descripcion !== undefined) {
        fields.push(`descripcion = $${counter++}`);
        values.push(data.descripcion);
      }
      if (data.nota !== undefined) {
        fields.push(`nota = $${counter++}`);
        values.push(data.nota);
      }

      values.push(id, usuarioId);
      const sql = `
        UPDATE transaccion
        SET ${fields.join(', ')}
        WHERE id = $${counter++} AND usuario_id = $${counter++} AND eliminada = FALSE
        RETURNING *
      `;

      const res = await client.query<any>(sql, values);
      if (res.rows.length === 0) {
        throw new Error('Transacción no encontrada o no pertenece al usuario');
      }

      await client.query('COMMIT');
      return this.mapRowToTransaction(res.rows[0]);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  public async softDelete(id: string, usuarioId: string): Promise<void> {
    const res = await db.query(
      `UPDATE transaccion 
       SET eliminada = TRUE, eliminada_en = now() 
       WHERE id = $1 AND usuario_id = $2 AND eliminada = FALSE`,
      [id, usuarioId]
    );

    if (res.rowCount === 0) {
      throw new Error('Transacción no encontrada o ya eliminada');
    }
  }

  public async getMonthlySummary(
    usuarioId: string,
    year: number,
    month: number
  ): Promise<{ totalIngresos: number; totalGastos: number; balanceNeto: number }> {
    const startDate = `${year}-${String(month).padStart(2, '0')}-01`;
    // Último día del mes
    const nextMonth = month === 12 ? 1 : month + 1;
    const nextYear = month === 12 ? year + 1 : year;
    const endDate = `${nextYear}-${String(nextMonth).padStart(2, '0')}-01`;

    const res = await db.query<any>(
      `SELECT 
        COALESCE(SUM(CASE WHEN tipo = 'ingreso' THEN monto ELSE 0 END), 0.00)::numeric AS total_ingresos,
        COALESCE(SUM(CASE WHEN tipo = 'gasto' THEN monto ELSE 0 END), 0.00)::numeric AS total_gastos
      FROM transaccion
      WHERE usuario_id = $1 
        AND fecha >= $2 
        AND fecha < $3 
        AND eliminada = FALSE`,
      [usuarioId, startDate, endDate]
    );

    const totalIngresos = FinancialCalculator.roundMoney(Number(res.rows[0]?.total_ingresos || 0));
    const totalGastos = FinancialCalculator.roundMoney(Number(res.rows[0]?.total_gastos || 0));
    const balanceNeto = FinancialCalculator.roundMoney(totalIngresos - totalGastos);

    return { totalIngresos, totalGastos, balanceNeto };
  }

  private mapRowToTransaction(row: any): Transaction {
    // Manejo de fecha formato YYYY-MM-DD
    let fechaStr = row.fecha;
    if (row.fecha instanceof Date) {
      fechaStr = row.fecha.toISOString().split('T')[0];
    } else if (typeof row.fecha === 'string' && row.fecha.includes('T')) {
      fechaStr = row.fecha.split('T')[0];
    }

    return {
      id: row.id,
      usuario_id: row.usuario_id,
      cuenta_id: row.cuenta_id,
      categoria_id: row.categoria_id,
      tipo: row.tipo,
      sentido: row.sentido,
      monto: FinancialCalculator.roundMoney(Number(row.monto)),
      fecha: fechaStr,
      descripcion: row.descripcion,
      nota: row.nota,
      estado_categoria: row.estado_categoria || 'categorizada',
      confianza: row.confianza !== null && row.confianza !== undefined ? Number(row.confianza) : null,
      categoria_manual: Boolean(row.categoria_manual),
      transferencia_vinculada_id: row.transferencia_vinculada_id,
      recurrente_id: row.recurrente_id,
      importacion_id: row.importacion_id,
      huella: row.huella,
      eliminada: Boolean(row.eliminada),
      eliminada_en: row.eliminada_en ? new Date(row.eliminada_en) : null,
      creada_en: new Date(row.creada_en),
    };
  }
}
