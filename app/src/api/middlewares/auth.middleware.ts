import { Request, Response, NextFunction } from 'express';
import { TokenService } from '../../infrastructure/security/TokenService.js';
import { UnauthorizedError } from '../../domain/errors/DomainError.js';
import { env } from '../../config/env.js';
import { db } from '../../infrastructure/database/db.js';
import { ForbiddenError } from '../../domain/errors/DomainError.js';
import { SessionService } from '../../infrastructure/security/SessionService.js';

export interface AuthenticatedUser {
  id: string;
  email: string;
  token: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
    }
  }
}

export async function authMiddleware(req: Request, res: Response, next: NextFunction): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return next(new UnauthorizedError('Cabecera Authorization no provista'));
  }

  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return next(new UnauthorizedError('Formato de autorización inválido. Debe ser: Bearer <token>'));
  }

  const token = parts[1];
  try {
    const payload = TokenService.verifyToken(token);
    // La sesión debe seguir vigente: un cierre de sesión invalida el token (RF-AUT-04)
    if (!(await SessionService.isActive(token))) {
      return next(new UnauthorizedError('La sesión fue cerrada o ya no es válida. Inicia sesión de nuevo'));
    }
    // RF-AUT-02: sin correo verificado no se registran datos financieros (opcional por configuración)
    if (env.REQUIRE_EMAIL_VERIFICATION && req.method !== 'GET' && !req.baseUrl.endsWith('/auth')) {
      const u = await db.query<any>(`SELECT email_verificado FROM usuario WHERE id = $1`, [payload.userId]);
      if (!u.rows[0]?.email_verificado) {
        return next(new ForbiddenError('Verifica tu correo electrónico para registrar datos financieros'));
      }
    }
    req.user = {
      id: payload.userId,
      email: payload.email,
      token,
    };
    next();
  } catch (err) {
    next(err);
  }
}
