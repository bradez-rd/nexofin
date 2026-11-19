import { db } from '../../infrastructure/database/db.js';
import { SimulationEngine, SimulationResult, FinancialSnapshot } from '../../domain/services/SimulationEngine.js';
import { DateRules } from '../../domain/services/DateRules.js';
import { NotFoundError, ValidationError } from '../../domain/errors/DomainError.js';
import { SnapshotService } from './SnapshotService.js';
import { env } from '../../config/env.js';

export type SimulationType = 'gasto' | 'ahorro_meta' | 'compra_cuotas';

export interface StoredSimulation {
  id: string;
  tipo: SimulationType;
  parametros: Record<string, unknown>;
  datos_usados: FinancialSnapshot;
  resultado: SimulationResult;
  concluyente: boolean;
  guardada: boolean;
  creada_en: Date;
}

const json = (v: unknown) => (typeof v === 'string' ? JSON.parse(v) : v);

/** Ejecuta, registra, guarda y compara simulaciones (RF-SIM-01/07/08). */
export class SimulationService {
  constructor(private readonly snapshots = new SnapshotService()) {}

  public static run(tipo: SimulationType, snapshot: FinancialSnapshot, params: any): SimulationResult {
    switch (tipo) {
      case 'gasto':
        return SimulationEngine.simulateExpense(snapshot, params);
      case 'ahorro_meta':
        return SimulationEngine.simulateSaving(snapshot, params);
      case 'compra_cuotas':
        return SimulationEngine.simulateInstallments(snapshot, params);
      default:
        throw new ValidationError('Tipo de simulación desconocido');
    }
  }

  private map(r: any): StoredSimulation {
    return {
      id: r.id,
      tipo: r.tipo,
      parametros: json(r.parametros),
      datos_usados: json(r.datos_usados),
      resultado: json(r.resultado),
      concluyente: Boolean(r.concluyente),
      guardada: Boolean(r.guardada),
      creada_en: new Date(r.creada_en),
    };
  }

  /** Cada simulación queda registrada con la copia de los datos usados y su resultado (RF-SIM-01). */
  public async simulate(userId: string, tipo: SimulationType, params: Record<string, unknown>, guardar = false): Promise<StoredSimulation> {
    const hoy = DateRules.todayIn(env.TIMEZONE);
    const fecha = typeof params.fecha === 'string' ? params.fecha.slice(0, 7) : hoy.slice(0, 7);
    const meses = [...new Set([hoy.slice(0, 7), fecha])];
    const snapshot = await this.snapshots.build(userId, hoy, meses);
    const resultado = SimulationService.run(tipo, snapshot, params);
    const res = await db.query<any>(
      `INSERT INTO simulacion (usuario_id, tipo, parametros, datos_usados, resultado, concluyente, guardada)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [userId, tipo, JSON.stringify(params), JSON.stringify(snapshot), JSON.stringify(resultado), resultado.concluyente, guardar]
    );
    return this.map(res.rows[0]);
  }

  public async get(userId: string, id: string): Promise<StoredSimulation> {
    const res = await db.query<any>(`SELECT * FROM simulacion WHERE id = $1 AND usuario_id = $2`, [id, userId]);
    if (res.rowCount === 0) throw new NotFoundError('Simulación no encontrada');
    return this.map(res.rows[0]);
  }

  public async list(userId: string, soloGuardadas = true, limit = 50): Promise<StoredSimulation[]> {
    const res = await db.query<any>(
      `SELECT * FROM simulacion WHERE usuario_id = $1 ${soloGuardadas ? 'AND guardada = TRUE' : ''}
       ORDER BY creada_en DESC LIMIT $2`,
      [userId, Math.min(limit, 200)]
    );
    return res.rows.map((r) => this.map(r));
  }

  public async save(userId: string, id: string, guardada = true): Promise<StoredSimulation> {
    await this.get(userId, id);
    await db.query(`UPDATE simulacion SET guardada = $1 WHERE id = $2 AND usuario_id = $3`, [guardada, id, userId]);
    return this.get(userId, id);
  }

  public async remove(userId: string, id: string): Promise<void> {
    const res = await db.query(`DELETE FROM simulacion WHERE id = $1 AND usuario_id = $2 AND id NOT IN (SELECT simulacion_id FROM mensaje WHERE simulacion_id IS NOT NULL) RETURNING id`, [id, userId]);
    if (res.rowCount === 0) {
      await this.get(userId, id);
      await db.query(`UPDATE simulacion SET guardada = FALSE WHERE id = $1`, [id]);
    }
  }

  /** Reabre el resultado original y, a pedido, recalcula con los datos de hoy (RF-SIM-07). */
  public async recalculate(userId: string, id: string): Promise<{ original: StoredSimulation; actual: StoredSimulation }> {
    const original = await this.get(userId, id);
    const params = { ...original.parametros };
    if (typeof params.fecha === 'string' && params.fecha < DateRules.todayIn(env.TIMEZONE)) delete params.fecha;
    const actual = await this.simulate(userId, original.tipo, params, false);
    return { original, actual };
  }

  /** Compara hasta tres escenarios lado a lado (RF-SIM-08). */
  public async compare(userId: string, ids: string[]): Promise<{ escenarios: any[] }> {
    if (ids.length < 2 || ids.length > 3) throw new ValidationError('Compara entre 2 y 3 escenarios');
    const sims = await Promise.all(ids.map((id) => this.get(userId, id)));
    return {
      escenarios: sims.map((s) => {
        const r = s.resultado.resultado as any;
        return {
          id: s.id,
          tipo: s.tipo,
          resumen: s.resultado.resumen,
          concluyente: s.concluyente,
          saldo_libre_despues: r.saldo_libre_despues ?? null,
          efecto_presupuesto: r.efecto_presupuesto ?? null,
          efecto_metas: {
            compromete_metas: r.compromete_metas ?? null,
            ahorro_mensual_requerido: r.ahorro_mensual_requerido ?? null,
          },
          cuota_mensual: r.cuota_mensual ?? null,
          viable: r.viable ?? (r.saldo_libre_despues !== undefined ? r.saldo_libre_despues >= 0 : null),
        };
      }),
    };
  }
}
