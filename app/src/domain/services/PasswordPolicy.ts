import { ValidationError } from '../errors/DomainError.js';

/** Contraseñas muy comunes que no se aceptan aunque cumplan la longitud (RF-AUT-01). */
const COMMON = new Set([
  '1234567890', '12345678910', '0123456789', 'password12', 'password123', 'password1234', 'contrasena1',
  'contrasena123', 'qwertyuiop', 'qwerty12345', 'abc1234567', 'abcdefghij', 'iloveyou123', 'admin12345',
  'administrator', 'welcome123', 'letmein123', 'nexofin123', 'nexofin1234', 'passw0rd123', '1q2w3e4r5t',
  'qazwsxedc1', 'monkey1234', 'dragon1234', 'football123', 'baseball123', 'superman123', '1111111111',
  '0000000000', 'aaaaaaaaaa', 'contrasenaa', 'clave12345', 'clave123456', 'mipassword1', 'mipassword12',
]);

export class PasswordPolicy {
  public static readonly MIN_LENGTH = 10;

  public static problems(password: string): string[] {
    const out: string[] = [];
    if (!password || password.length < this.MIN_LENGTH) {
      out.push(`La contraseña debe tener al menos ${this.MIN_LENGTH} caracteres`);
    }
    if (password && COMMON.has(password.toLowerCase())) {
      out.push('La contraseña es demasiado común; elige otra');
    }
    if (password && /^(.)\1+$/.test(password)) {
      out.push('La contraseña no puede repetir un mismo carácter');
    }
    return out;
  }

  public static assert(password: string): void {
    const problems = this.problems(password);
    if (problems.length > 0) throw new ValidationError(problems[0], problems);
  }
}
