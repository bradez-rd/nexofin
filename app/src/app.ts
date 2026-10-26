import express, { Request, Response } from 'express';
import cors from 'cors';
import { env } from './config/env.js';
import apiRoutes from './api/routes/index.js';
import { errorHandler } from './api/middlewares/error.middleware.js';
import { NotFoundError } from './domain/errors/DomainError.js';

export const app = express();

// Middlewares globales de seguridad y formato
app.use(cors({ origin: env.CORS_ORIGIN }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Ruta raíz: Directorio y metadatos del servicio REST API
app.get('/', (_req: Request, res: Response) => {
  res.status(200).json({
    name: 'NexoFin AI API',
    description: 'Plataforma de gestión financiera determinística con asistente IA',
    version: '1.0.0',
    documentation: '/api/v1/health',
    endpoints: {
      health: 'GET /api/v1/health',
      auth: {
        register: 'POST /api/v1/auth/register',
        login: 'POST /api/v1/auth/login',
        profile: 'GET /api/v1/auth/profile',
      },
      accounts: {
        list: 'GET /api/v1/accounts',
        create: 'POST /api/v1/accounts',
        summary: 'GET /api/v1/accounts/summary/balances',
      },
      transactions: {
        list: 'GET /api/v1/transactions',
        create: 'POST /api/v1/transactions',
        transfer: 'POST /api/v1/transactions/transfer',
        monthlySummary: 'GET /api/v1/transactions/summary/monthly',
      },
      categories: {
        list: 'GET /api/v1/categories',
      },
    },
  });
});

// Rutas API v1
app.use('/api/v1', apiRoutes);

// Manejador 404 para rutas inexistentes
app.use((req: Request, res: Response, next) => {
  next(new NotFoundError(`Ruta no encontrada: ${req.method} ${req.originalUrl}`));
});

// Manejador global de errores
app.use(errorHandler);
