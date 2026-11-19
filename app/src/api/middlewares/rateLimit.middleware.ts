import { Request, Response, NextFunction } from 'express';
import { TooManyRequestsError } from '../../domain/errors/DomainError.js';

export interface RateLimitOptions {
  /** Ventana de tiempo en milisegundos. */
  windowMs: number;
  /** Máximo de peticiones permitidas por origen dentro de la ventana. */
  max: number;
  message?: string;
}

/**
 * Limita la frecuencia de peticiones por origen (RNF-SEG-06): protege el inicio de sesión
 * contra intentos masivos de adivinar contraseñas. Contador en memoria, suficiente para un solo servidor.
 */
export function rateLimit(options: RateLimitOptions) {
  const hits = new Map<string, { count: number; resetAt: number }>();
  const message = options.message ?? 'Demasiados intentos. Espera un momento antes de volver a intentarlo.';

  return (req: Request, res: Response, next: NextFunction): void => {
    const now = Date.now();
    const key = req.ip || req.socket?.remoteAddress || 'desconocido';

    // Limpieza ocasional para que el mapa no crezca sin control
    if (hits.size > 5000) {
      for (const [k, v] of hits) if (v.resetAt <= now) hits.delete(k);
    }

    const entry = hits.get(key);
    if (!entry || entry.resetAt <= now) {
      hits.set(key, { count: 1, resetAt: now + options.windowMs });
      return next();
    }

    entry.count += 1;
    if (entry.count > options.max) {
      res.setHeader('Retry-After', String(Math.ceil((entry.resetAt - now) / 1000)));
      return next(new TooManyRequestsError(message));
    }
    next();
  };
}
