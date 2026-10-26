import { Request, Response, NextFunction } from 'express';
import { TokenService } from '../../infrastructure/security/TokenService.js';
import { UnauthorizedError } from '../../domain/errors/DomainError.js';

export interface AuthenticatedUser {
  id: string;
  email: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
    }
  }
}

export function authMiddleware(req: Request, res: Response, next: NextFunction): void {
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
    req.user = {
      id: payload.userId,
      email: payload.email,
    };
    next();
  } catch (err) {
    next(err);
  }
}
