import { DateRules } from './DateRules.js';
import { FinancialCalculator } from './FinancialCalculator.js';

export interface ColumnMapping {
  fecha: number;
  descripcion: number;
  /** Una sola columna de monto (negativo = débito) */
  monto?: number;
  /** O columnas separadas de débito y crédito */
  debito?: number;
  credito?: number;
  /** Columna opcional con el sentido (DB/CR, débito/crédito) */
  tipo?: number;
}

export interface ParsedMovement {
  fecha: string;
  monto: number;
  sentido: 'entrada' | 'salida';
  descripcion: string;
}

export interface ParseResult {
  movimientos: ParsedMovement[];
  errores: { fila: number; motivo: string }[];
}

const norm = (t: string) =>
  String(t ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim();

/** Lectura de estados de cuenta (RF-IMP-02/03): mapeo de columnas, fechas, montos y sentido. */
export class StatementParser {
  public static parseCsv(text: string): string[][] {
    const clean = text.replace(/^﻿/, '');
    const firstLine = clean.split(/\r?\n/).find((l) => l.trim().length > 0) ?? '';
    const delim = [';', '\t', ','].sort((a, b) => firstLine.split(b).length - firstLine.split(a).length)[0];
    const rows: string[][] = [];
    let row: string[] = [];
    let cell = '';
    let quoted = false;
    for (let i = 0; i < clean.length; i++) {
      const ch = clean[i];
      if (quoted) {
        if (ch === '"' && clean[i + 1] === '"') {
          cell += '"';
          i++;
        } else if (ch === '"') quoted = false;
        else cell += ch;
      } else if (ch === '"') quoted = true;
      else if (ch === delim) {
        row.push(cell);
        cell = '';
      } else if (ch === '\n' || ch === '\r') {
        if (ch === '\r' && clean[i + 1] === '\n') i++;
        row.push(cell);
        if (row.some((c) => c.trim() !== '')) rows.push(row.map((c) => c.trim()));
        row = [];
        cell = '';
      } else cell += ch;
    }
    row.push(cell);
    if (row.some((c) => c.trim() !== '')) rows.push(row.map((c) => c.trim()));
    return rows;
  }

  /** Reconoce encabezados habituales; devuelve null si no logra identificar fecha, monto y descripción. */
  public static detectMapping(headers: string[]): ColumnMapping | null {
    const h = headers.map(norm);
    const find = (...names: string[]) => h.findIndex((x) => names.some((n) => x === n || x.includes(n)));
    const fecha = find('fecha', 'date');
    const descripcion = find('descripcion', 'detalle', 'concepto', 'description', 'referencia', 'movimiento');
    const debito = find('debito', 'debit', 'retiro', 'cargo');
    const credito = find('credito', 'credit', 'deposito', 'abono');
    const monto = find('monto', 'importe', 'amount', 'valor');
    const tipo = h.findIndex((x) => x === 'tipo' || x === 'type' || x === 'dc' || x === 'd/c');
    if (fecha < 0 || descripcion < 0) return null;
    if (monto >= 0) return { fecha, descripcion, monto, ...(tipo >= 0 ? { tipo } : {}) };
    if (debito >= 0 || credito >= 0) {
      return { fecha, descripcion, ...(debito >= 0 ? { debito } : {}), ...(credito >= 0 ? { credito } : {}) };
    }
    return null;
  }

  public static parseDate(value: unknown): string | null {
    if (value instanceof Date && !isNaN(value.getTime())) {
      return `${value.getUTCFullYear()}-${String(value.getUTCMonth() + 1).padStart(2, '0')}-${String(value.getUTCDate()).padStart(2, '0')}`;
    }
    const s = String(value ?? '').trim();
    let m = /^(\d{4})[-/](\d{1,2})[-/](\d{1,2})/.exec(s);
    let y: number, mo: number, d: number;
    if (m) [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
    else if ((m = /^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})/.exec(s))) {
      // En República Dominicana el formato habitual es DD/MM/AAAA
      [d, mo, y] = [Number(m[1]), Number(m[2]), Number(m[3])];
      if (y < 100) y += 2000;
      if (mo > 12 && d <= 12) [d, mo] = [mo, d];
    } else return null;
    const iso = `${y}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    return DateRules.isRealDate(iso) ? iso : null;
  }

  /** Acepta 1,234.56 · 1.234,56 · (500.00) · -500 · RD$ 1,200.00 */
  public static parseAmount(value: unknown): number | null {
    if (typeof value === 'number') return Number.isFinite(value) ? value : null;
    let s = String(value ?? '').trim();
    if (!s) return null;
    let negative = false;
    if (/^\(.*\)$/.test(s)) {
      negative = true;
      s = s.slice(1, -1);
    }
    if (/-\s*$/.test(s)) negative = true;
    s = s.replace(/rd\$?|dop|\$|\s/gi, '');
    if (s.startsWith('-')) negative = true;
    s = s.replace(/^[-+]|-$/g, '');
    if (!/^\d[\d.,]*$/.test(s)) return null;
    const lastDot = s.lastIndexOf('.');
    const lastComma = s.lastIndexOf(',');
    if (lastDot >= 0 && lastComma >= 0) {
      s = lastComma > lastDot ? s.replace(/\./g, '').replace(',', '.') : s.replace(/,/g, '');
    } else if (lastComma >= 0) {
      s = /,\d{1,2}$/.test(s) ? s.replace(',', '.') : s.replace(/,/g, '');
    }
    const n = Number(s);
    if (!Number.isFinite(n)) return null;
    return negative ? -n : n;
  }

  private static sentidoFromTipo(raw: string): 'entrada' | 'salida' | null {
    const t = norm(raw);
    if (['db', 'd', 'debito', 'debit', 'retiro', 'cargo'].includes(t)) return 'salida';
    if (['cr', 'c', 'credito', 'credit', 'deposito', 'abono'].includes(t)) return 'entrada';
    return null;
  }

  public static parseRows(rows: unknown[][], mapping: ColumnMapping, hasHeader = true): ParseResult {
    const out: ParseResult = { movimientos: [], errores: [] };
    rows.forEach((row, idx) => {
      if (hasHeader && idx === 0) return;
      const fila = idx + 1;
      if (row.every((c) => String(c ?? '').trim() === '')) return;
      const fecha = this.parseDate(row[mapping.fecha]);
      const descripcion = String(row[mapping.descripcion] ?? '').trim();
      if (!fecha) return void out.errores.push({ fila, motivo: 'Fecha no reconocida' });
      if (!descripcion) return void out.errores.push({ fila, motivo: 'Falta la descripción' });

      let monto: number | null = null;
      let sentido: 'entrada' | 'salida' | null = null;
      if (mapping.monto !== undefined) {
        const v = this.parseAmount(row[mapping.monto]);
        if (v !== null && v !== 0) {
          monto = Math.abs(v);
          sentido = mapping.tipo !== undefined ? this.sentidoFromTipo(String(row[mapping.tipo] ?? '')) : null;
          sentido = sentido ?? (v < 0 ? 'salida' : 'entrada');
        }
      } else {
        const d = mapping.debito !== undefined ? this.parseAmount(row[mapping.debito]) : null;
        const c = mapping.credito !== undefined ? this.parseAmount(row[mapping.credito]) : null;
        if (d && d !== 0) [monto, sentido] = [Math.abs(d), 'salida'];
        else if (c && c !== 0) [monto, sentido] = [Math.abs(c), 'entrada'];
      }
      if (monto === null || sentido === null) return void out.errores.push({ fila, motivo: 'Monto no reconocido' });
      out.movimientos.push({ fecha, monto: FinancialCalculator.roundMoney(monto), sentido, descripcion: descripcion.slice(0, 300) });
    });
    return out;
  }

  /** Extracción heurística desde las líneas de texto de un PDF (RF-IMP-01, nivel 3). */
  public static parsePdfLines(lines: string[]): ParseResult {
    const out: ParseResult = { movimientos: [], errores: [] };
    const dateRe = /^(\d{4}-\d{2}-\d{2}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\s+(.*)$/;
    lines.forEach((raw, idx) => {
      const line = raw.trim();
      const m = dateRe.exec(line);
      if (!m) return;
      const fecha = this.parseDate(m[1]);
      const rest = m[2];
      const tokens = rest.match(/\(?-?\d[\d.,]*\)?-?/g)?.filter((t) => /[.,]\d{2}\)?-?$/.test(t)) ?? [];
      if (!fecha || tokens.length === 0) return void out.errores.push({ fila: idx + 1, motivo: 'Línea del PDF no reconocida' });
      const montoTok = tokens.length >= 2 ? tokens[tokens.length - 2] : tokens[0];
      const v = this.parseAmount(montoTok);
      if (v === null || v === 0) return void out.errores.push({ fila: idx + 1, motivo: 'Monto no reconocido' });
      const desc = rest.slice(0, rest.indexOf(tokens[0])).trim() || rest.replace(/[\d.,()-]+/g, '').trim();
      const t = norm(rest);
      const credit = /(\bcr\b|credito|deposito|abono|nomina|transferencia recibida)/.test(t);
      const debit = /(\bdb\b|debito|retiro|cargo|compra|pago)/.test(t);
      const sentido = v < 0 || (debit && !credit) ? 'salida' : credit ? 'entrada' : 'salida';
      out.movimientos.push({ fecha, monto: FinancialCalculator.roundMoney(Math.abs(v)), sentido, descripcion: (desc || 'Movimiento').slice(0, 300) });
    });
    return out;
  }
}
