import { Request, Response, NextFunction } from 'express';
import { AppError } from '../../domain/errors/DomainError.js';
import { env } from '../../config/env.js';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const timestamp = new Date().toISOString();

  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      success: false,
      error: {
        code: err.name,
        message: err.message,
        details: err.details || null,
        timestamp,
      },
    });
    return;
  }

  // Errores de sintaxis JSON
  if (err instanceof SyntaxError && 'body' in err) {
    res.status(400).json({
      success: false,
      error: {
        code: 'MalformedJsonError',
        message: 'El cuerpo de la petición contiene JSON inválido',
        timestamp,
      },
    });
    return;
  }

  // Error no controlado (500)
  console.error('[Error no controlado]:', err);
  res.status(500).json({
    success: false,
    error: {
      code: 'InternalServerError',
      message: 'Ocurrió un error interno en el servidor',
      ...(env.NODE_ENV === 'development' ? { stack: err.stack } : {}),
      timestamp,
    },
  });
}
