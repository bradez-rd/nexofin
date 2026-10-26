import bcrypt from 'bcryptjs';
import { env } from '../../config/env.js';

export class PasswordHasher {
  public static async hash(password: string): Promise<string> {
    const salt = await bcrypt.genSalt(env.BCRYPT_SALT_ROUNDS);
    return bcrypt.hash(password, salt);
  }

  public static async compare(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }
}
