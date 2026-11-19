import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { env } from '../../config/env.js';
import { UnauthorizedError } from '../../domain/errors/DomainError.js';

export interface TokenPayload {
  userId: string;
  email: string;
}

export class TokenService {
  public static generateToken(payload: TokenPayload): string {
    return jwt.sign(payload, env.JWT_SECRET, {
      expiresIn: env.JWT_EXPIRES_IN as any,
      jwtid: crypto.randomUUID(), // cada token es único, aunque se emita dos veces en el mismo segundo
    });
  }

  public static verifyToken(token: string): TokenPayload {
    try {
      const decoded = jwt.verify(token, env.JWT_SECRET) as TokenPayload;
      if (!decoded || !decoded.userId) {
        throw new UnauthorizedError('Token JWT inválido o malformado');
      }
      return decoded;
    } catch (err: any) {
      if (err instanceof UnauthorizedError) throw err;
      throw new UnauthorizedError('Token JWT expirado o no válido');
    }
  }
}
