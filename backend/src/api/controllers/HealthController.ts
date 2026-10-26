import { Request, Response, NextFunction } from 'express';
import { db } from '../../infrastructure/database/db.js';
import { env } from '../../config/env.js';

export class HealthController {
  public check = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const startTime = Date.now();
      // Verificación de conexión SQL activa
      const result = await db.query('SELECT 1 as alive');
      const latencyMs = Date.now() - startTime;

      res.status(200).json({
        status: 'UP',
        timestamp: new Date().toISOString(),
        environment: env.NODE_ENV,
        database: {
          connected: result.rows.length > 0 && result.rows[0].alive === 1,
          engine: db.isMemory() ? 'pg-mem (PostgreSQL 16 In-Memory Engine)' : 'PostgreSQL 16',
          latencyMs,
        },
        uptimeSeconds: Math.floor(process.uptime()),
        service: 'NexoFin AI - Financial API REST',
        version: '1.0.0',
      });
    } catch (err: any) {
      res.status(503).json({
        status: 'DOWN',
        timestamp: new Date().toISOString(),
        error: err.message,
      });
    }
  };
}
