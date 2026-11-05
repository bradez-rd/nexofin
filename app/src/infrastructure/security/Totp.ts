import crypto from 'crypto';

const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/** TOTP (RFC 6238) con HMAC-SHA1, 6 dígitos y paso de 30 s, compatible con Google Authenticator. */
export class Totp {
  public static generateSecret(bytes = 20): string {
    return this.base32Encode(crypto.randomBytes(bytes));
  }

  public static base32Encode(buf: Buffer): string {
    let bits = '';
    for (const b of buf) bits += b.toString(2).padStart(8, '0');
    let out = '';
    for (let i = 0; i < bits.length; i += 5) {
      out += ALPHABET[parseInt(bits.slice(i, i + 5).padEnd(5, '0'), 2)];
    }
    return out;
  }

  public static base32Decode(text: string): Buffer {
    let bits = '';
    for (const ch of text.replace(/=+$/, '').toUpperCase()) {
      const idx = ALPHABET.indexOf(ch);
      if (idx < 0) throw new Error('Secreto base32 inválido');
      bits += idx.toString(2).padStart(5, '0');
    }
    const bytes: number[] = [];
    for (let i = 0; i + 8 <= bits.length; i += 8) bytes.push(parseInt(bits.slice(i, i + 8), 2));
    return Buffer.from(bytes);
  }

  public static code(secret: string, atMs: number = Date.now(), stepSeconds = 30): string {
    const counter = Math.floor(atMs / 1000 / stepSeconds);
    const msg = Buffer.alloc(8);
    msg.writeBigUInt64BE(BigInt(counter));
    const hmac = crypto.createHmac('sha1', this.base32Decode(secret)).update(msg).digest();
    const offset = hmac[hmac.length - 1] & 0xf;
    const bin =
      ((hmac[offset] & 0x7f) << 24) |
      (hmac[offset + 1] << 16) |
      (hmac[offset + 2] << 8) |
      hmac[offset + 3];
    return String(bin % 1_000_000).padStart(6, '0');
  }

  /** Acepta el código del paso actual y el anterior/siguiente para tolerar desfase de reloj. */
  public static verify(secret: string, code: string, atMs: number = Date.now()): boolean {
    if (!/^\d{6}$/.test(code)) return false;
    for (const drift of [-1, 0, 1]) {
      if (this.code(secret, atMs + drift * 30_000) === code) return true;
    }
    return false;
  }

  public static otpauthUrl(secret: string, account: string, issuer = 'NexoFin'): string {
    return `otpauth://totp/${encodeURIComponent(issuer)}:${encodeURIComponent(account)}?secret=${secret}&issuer=${encodeURIComponent(issuer)}&algorithm=SHA1&digits=6&period=30`;
  }
}
