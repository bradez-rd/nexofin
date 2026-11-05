import type pg from 'pg';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';

export interface LedgerEntry {
  usuario_id: string;
  cuenta_id: string;
  categoria_id?: string | null;
  tipo: 'ingreso' | 'gasto' | 'transferencia' | 'ajuste' | 'aporte_meta';
  sentido: 'entrada' | 'salida';
  monto: number;
  fecha: string;
  descripcion?: string | null;
  recurrente_id?: string | null;
  importacion_id?: string | null;
  estado_categoria?: 'categorizada' | 'pendiente_revision' | 'sin_categoria';
  confianza?: number | null;
}

/**
 * Inserta un movimiento dentro de una transacción SQL ya abierta, de modo que los módulos que
 * necesitan atomicidad (pago de deuda, aporte a meta, importación) comparten una única escritura.
 */
export async function insertLedgerEntry(client: pg.PoolClient, e: LedgerEntry): Promise<any> {
  const monto = FinancialCalculator.roundMoney(e.monto);
  const huella = FinancialCalculator.generateFingerprint(e.cuenta_id, e.fecha, monto, e.descripcion || '');
  const res = await client.query(
    `INSERT INTO transaccion (
       usuario_id, cuenta_id, categoria_id, tipo, sentido, monto, fecha, descripcion,
       recurrente_id, importacion_id, estado_categoria, confianza, huella
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING *`,
    [
      e.usuario_id,
      e.cuenta_id,
      e.categoria_id ?? null,
      e.tipo,
      e.sentido,
      monto,
      e.fecha,
      e.descripcion ?? null,
      e.recurrente_id ?? null,
      e.importacion_id ?? null,
      e.estado_categoria ?? (e.categoria_id ? 'categorizada' : 'sin_categoria'),
      e.confianza ?? null,
      huella,
    ]
  );
  return res.rows[0];
}

/** Categorías del sistema con identificador fijo (ver db/seeds.sql). */
export const SYSTEM_CATEGORY = {
  pagoDeuda: 'b0000000-0000-4000-8000-000000000009',
  aporteMeta: 'b0000000-0000-4000-8000-000000000010',
  otrosGastos: 'b0000000-0000-4000-8000-000000000011',
  otrosIngresos: 'a0000000-0000-4000-8000-000000000005',
} as const;
