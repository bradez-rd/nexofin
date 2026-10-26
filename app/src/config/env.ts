import dotenv from 'dotenv';
import path from 'path';

// Cargar variables de entorno desde app/.env o raíz
dotenv.config();
dotenv.config({ path: path.resolve(process.cwd(), '.env') });
dotenv.config({ path: path.resolve(process.cwd(), 'app/.env') });

export const env = {
  PORT: parseInt(process.env.PORT || '3000', 10),
  NODE_ENV: process.env.NODE_ENV || 'development',
  DATABASE_URL: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/nexofin_db',
  DB_SSL: process.env.DB_SSL === 'true',
  USE_MEMORY_DB_FALLBACK: process.env.USE_MEMORY_DB_FALLBACK !== 'false',
  JWT_SECRET: process.env.JWT_SECRET || 'nexofin_default_dev_secret_key_12345',
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '7d',
  BCRYPT_SALT_ROUNDS: parseInt(process.env.BCRYPT_SALT_ROUNDS || '10', 10),
  DEFAULT_CURRENCY: process.env.DEFAULT_CURRENCY || 'DOP',
  TIMEZONE: process.env.TIMEZONE || 'America/Santo_Domingo',
  CORS_ORIGIN: process.env.CORS_ORIGIN || '*',
};
