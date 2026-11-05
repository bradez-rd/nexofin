import jwt from 'jsonwebtoken';
import { PasswordHasher } from '../../src/infrastructure/security/PasswordHasher.js';
import { TokenService } from '../../src/infrastructure/security/TokenService.js';
import { UnauthorizedError } from '../../src/domain/errors/DomainError.js';
import { env } from '../../src/config/env.js';

/**
 * Pruebas unitarias de seguridad (RNF-SEG-02 contraseñas con sal, RNF-SEG-04 sesiones por token).
 */
describe('Seguridad - pruebas unitarias', () => {
  describe('PasswordHasher (RNF-SEG-02)', () => {
    it('UT-13 · nunca guarda la contraseña en claro y la verifica correctamente', async () => {
      const hash = await PasswordHasher.hash('MiClaveSegura2026!');
      expect(hash).not.toContain('MiClaveSegura2026!');
      expect(await PasswordHasher.compare('MiClaveSegura2026!', hash)).toBe(true);
      expect(await PasswordHasher.compare('OtraClave', hash)).toBe(false);
    });

    it('UT-14 · dos usuarios con la misma contraseña obtienen valores almacenados distintos (sal individual)', async () => {
      const h1 = await PasswordHasher.hash('ClaveRepetida2026');
      const h2 = await PasswordHasher.hash('ClaveRepetida2026');
      expect(h1).not.toBe(h2);
    });
  });

  describe('TokenService (RNF-SEG-04)', () => {
    it('UT-15 · emite un token y recupera el mismo usuario al verificarlo', () => {
      const token = TokenService.generateToken({ userId: 'u-1', email: 'a@b.com' });
      const payload = TokenService.verifyToken(token);
      expect(payload.userId).toBe('u-1');
      expect(payload.email).toBe('a@b.com');
    });

    it('UT-16 · rechaza un token manipulado', () => {
      const token = TokenService.generateToken({ userId: 'u-1', email: 'a@b.com' });
      const tampered = token.slice(0, -4) + 'abcd';
      expect(() => TokenService.verifyToken(tampered)).toThrow(UnauthorizedError);
    });

    it('UT-17 · rechaza un token firmado con otra clave', () => {
      const forged = jwt.sign({ userId: 'u-1', email: 'a@b.com' }, 'clave-incorrecta');
      expect(() => TokenService.verifyToken(forged)).toThrow(UnauthorizedError);
    });

    it('UT-18 · rechaza un token expirado', () => {
      const expired = jwt.sign({ userId: 'u-1', email: 'a@b.com' }, env.JWT_SECRET, { expiresIn: -10 });
      expect(() => TokenService.verifyToken(expired)).toThrow(UnauthorizedError);
    });

    it('UT-19 · rechaza un token válido que no trae identificador de usuario', () => {
      const noUser = jwt.sign({ email: 'a@b.com' }, env.JWT_SECRET);
      expect(() => TokenService.verifyToken(noUser)).toThrow(UnauthorizedError);
    });
  });
});
