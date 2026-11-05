import ExcelJS from 'exceljs';
import { ValidationError } from '../../domain/errors/DomainError.js';
import { StatementParser } from '../../domain/services/StatementParser.js';

export type StatementKind = 'csv' | 'xlsx' | 'pdf';

export interface RawStatement {
  kind: StatementKind;
  /** Filas de tabla (CSV y Excel). */
  rows?: unknown[][];
  /** Líneas de texto (PDF). */
  lines?: string[];
}

/** Convierte el archivo recibido en filas o líneas, rechazando formatos no soportados o corruptos. */
export class DocumentReader {
  public static kindOf(filename: string): StatementKind {
    const ext = filename.toLowerCase().split('.').pop() ?? '';
    if (ext === 'csv' || ext === 'txt') return 'csv';
    if (ext === 'xlsx') return 'xlsx';
    if (ext === 'pdf') return 'pdf';
    if (ext === 'xls') {
      throw new ValidationError('El formato XLS antiguo no es compatible: guarda el archivo como XLSX o CSV e inténtalo de nuevo');
    }
    throw new ValidationError('Formato no soportado: sube un archivo CSV, XLSX o PDF');
  }

  public static async read(filename: string, content: Buffer): Promise<RawStatement> {
    const kind = this.kindOf(filename);
    if (content.length === 0) throw new ValidationError('El archivo está vacío');
    try {
      if (kind === 'csv') {
        const text = content.toString('utf-8');
        if (text.includes('\u0000')) throw new Error('binario');
        return { kind, rows: StatementParser.parseCsv(text) };
      }
      if (kind === 'xlsx') {
        if (content.subarray(0, 2).toString('latin1') !== 'PK') throw new Error('firma xlsx inválida');
        const wb = new ExcelJS.Workbook();
        await wb.xlsx.load(content as any);
        const ws = wb.worksheets[0];
        if (!ws) throw new Error('sin hojas');
        const rows: unknown[][] = [];
        ws.eachRow({ includeEmpty: false }, (row) => {
          const values = (row.values as unknown[]).slice(1).map((v: any) =>
            v && typeof v === 'object' && !(v instanceof Date) && 'result' in v ? v.result : v && typeof v === 'object' && 'text' in v ? v.text : v
          );
          rows.push(values);
        });
        return { kind, rows };
      }
      if (content.subarray(0, 5).toString('latin1') !== '%PDF-') throw new Error('firma pdf inválida');
      // Se importa el módulo interno para evitar el archivo de prueba que carga el índice de pdf-parse
      const mod: any = await import('pdf-parse/lib/pdf-parse.js');
      const pdfParse = (mod.default ?? mod) as (b: Buffer) => Promise<{ text: string }>;
      // La versión de pdf.js que incluye pdf-parse falla con "bad XRef entry" en los primeros intentos
      // de un proceso nuevo aunque el archivo sea válido; se reintenta con una copia de memoria propia.
      let parsed: { text: string } | null = null;
      let lastError: unknown;
      for (let attempt = 0; attempt < 4 && !parsed; attempt++) {
        try {
          const own = Buffer.alloc(content.length);
          content.copy(own);
          parsed = await pdfParse(own);
        } catch (e) {
          lastError = e;
        }
      }
      if (!parsed) throw lastError;
      return { kind, lines: parsed.text.split(/\r?\n/) };
    } catch (err: any) {
      if (err instanceof ValidationError) throw err;
      throw new ValidationError('El archivo está dañado o no se puede leer. Descarga de nuevo el estado de cuenta e inténtalo otra vez');
    }
  }
}
