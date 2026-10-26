import pg from '../../../node_modules/@types/pg/index.js';
import fs from 'fs';
import path from 'path';
import { newDb, DataType } from 'pg-mem';
import crypto from 'crypto';
import { env } from '../../config/env.js';

const { Pool } = pg;

export interface QueryResult<T = any> {
  rows: T[];
  rowCount: number;
}

export interface IDatabaseClient {
  query<T = any>(text: string, params?: any[]): Promise<QueryResult<T>>;
  release(): void;
}

class DatabaseManager {
  private pool: pg.Pool | null = null;
  private isFallbackMemory: boolean = false;
  private initialized: boolean = false;

  public async getPool(): Promise<pg.Pool> {
    if (this.pool) return this.pool;

    try {
      // 1. Intento de conexión con PostgreSQL real
      const testPool = new Pool({
        connectionString: env.DATABASE_URL,
        ssl: env.DB_SSL ? { rejectUnauthorized: false } : false,
        connectionTimeoutMillis: 2500,
      });

      const client = await testPool.connect();
      client.release();
      this.pool = testPool;
      this.isFallbackMemory = false;
      console.log('[Database] Conexión establecida exitosamente con PostgreSQL en: ' + env.DATABASE_URL.split('@')[1] || 'localhost');
      return this.pool;
    } catch (err: any) {
      if (!env.USE_MEMORY_DB_FALLBACK) {
        throw new Error(`[Database] Error conectando a PostgreSQL y fallback desactivado: ${err.message}`);
      }

      console.warn('[Database] Servidor PostgreSQL local no disponible (' + err.message + ').');
      console.log('[Database] Inicializando motor PostgreSQL en memoria compatible (pg-mem) para ejecución inmediata...');

      this.pool = this.createMemoryPool();
      this.isFallbackMemory = true;
      return this.pool;
    }
  }

  private createMemoryPool(): pg.Pool {
    const memDb = newDb();

    // Registrar funciones esenciales de PostgreSQL
    memDb.public.registerFunction({
      name: 'gen_random_uuid',
      returns: DataType.text,
      impure: true,
      implementation: () => crypto.randomUUID(),
    });

    const { Pool: MemPool } = memDb.adapters.createPg();
    return new MemPool();
  }

  public async initSchema(): Promise<void> {
    const pool = await this.getPool();

    // Rutas de archivos SQL
    const schemaPath = path.resolve(__dirname, '../../../db/schema.sql');
    const seedsPath = path.resolve(__dirname, '../../../db/seeds.sql');

    let schemaSql = '';
    let seedsSql = '';

    if (fs.existsSync(schemaPath)) {
      schemaSql = fs.readFileSync(schemaPath, 'utf-8');
    }
    if (fs.existsSync(seedsPath)) {
      seedsSql = fs.readFileSync(seedsPath, 'utf-8');
    }

    if (this.isFallbackMemory) {
      // Remover CREATE EXTENSION para compatibilidad con pg-mem
      schemaSql = schemaSql.replace(/CREATE EXTENSION[^\;]+;/gi, '');
    }

    try {
      if (schemaSql) {
        await pool.query(schemaSql);
        console.log('[Database] Esquema relacional (24 tablas y vistas) aplicado.');
      }
      if (seedsSql) {
        await pool.query(seedsSql);
        console.log('[Database] Semillas de categorías del sistema cargadas.');
      }
      this.initialized = true;
    } catch (error: any) {
      console.error('[Database] Error aplicando esquema/semillas:', error.message);
      throw error;
    }
  }

  public async query<T = any>(text: string, params: any[] = []): Promise<QueryResult<T>> {
    const pool = await this.getPool();
    const result = await pool.query(text, params);
    return {
      rows: result.rows as T[],
      rowCount: result.rowCount || 0,
    };
  }

  public async getClient(): Promise<pg.PoolClient> {
    const pool = await this.getPool();
    return await pool.connect();
  }

  public isMemory(): boolean {
    return this.isFallbackMemory;
  }

  public async close(): Promise<void> {
    if (this.pool) {
      await this.pool.end();
      this.pool = null;
      this.initialized = false;
    }
  }
}

export const db = new DatabaseManager();
