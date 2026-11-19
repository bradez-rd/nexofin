import ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';
import { db } from '../../infrastructure/database/db.js';
import { PostgresTransactionRepository } from '../../infrastructure/repositories/PostgresTransactionRepository.js';
import { SimulationEngine } from '../../domain/services/SimulationEngine.js';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';
import { DateUtils } from '../../domain/services/DateUtils.js';
import { DateRules } from '../../domain/services/DateRules.js';
import { ValidationError } from '../../domain/errors/DomainError.js';
import { SnapshotService } from '../simulation/SnapshotService.js';
import { AuditService } from '../audit/AuditService.js';
import { TransactionFilter } from '../../domain/repositories/index.js';
import { env } from '../../config/env.js';

const r2 = (n: number) => FinancialCalculator.roundMoney(n);

export interface ExportFile {
  buffer: Buffer;
  contentType: string;
  filename: string;
}

/** Balance, posición financiera, distribución, tendencia y reportes (RF-DAS-01 a 05). */
export class DashboardService {
  constructor(
    private readonly snapshots = new SnapshotService(),
    private readonly transactions = new PostgresTransactionRepository()
  ) {}

  private assertRange(desde: string, hasta: string): void {
    if (!DateRules.isRealDate(desde) || !DateRules.isRealDate(hasta)) throw new ValidationError('Las fechas del periodo no son válidas');
    if (desde > hasta) throw new ValidationError('La fecha inicial no puede ser posterior a la final');
  }

  /** Ingresos, gastos y neto del periodo; las transferencias no cuentan (RF-DAS-01). */
  public async summary(userId: string, desde: string, hasta: string) {
    this.assertRange(desde, hasta);
    const res = await db.query<any>(
      `SELECT tipo, COALESCE(SUM(monto), 0) AS total, COUNT(*)::text AS n FROM transaccion
       WHERE usuario_id = $1 AND eliminada = FALSE AND fecha >= $2 AND fecha <= $3
         AND tipo IN ('ingreso','gasto','aporte_meta') GROUP BY tipo`,
      [userId, desde, hasta]
    );
    const get = (t: string) => res.rows.find((r) => r.tipo === t);
    const ingresos = r2(Number(get('ingreso')?.total ?? 0));
    const gastos = r2(Number(get('gasto')?.total ?? 0));
    return {
      desde,
      hasta,
      ingresos,
      gastos,
      saldo_neto: r2(ingresos - gastos),
      aportes_a_metas: r2(Number(get('aporte_meta')?.total ?? 0)),
      transacciones: parseInt(get('ingreso')?.n ?? '0', 10) + parseInt(get('gasto')?.n ?? '0', 10),
      nota: 'Las transferencias entre cuentas no se cuentan como ingreso ni como gasto',
    };
  }

  /** Posición financiera con el desglose de cada cifra (RF-DAS-02). */
  public async position(userId: string) {
    const hoy = DateRules.todayIn(env.TIMEZONE);
    const snap = await this.snapshots.build(userId, hoy);
    const fin = DateUtils.monthEnd(hoy);
    const proy = SimulationEngine.project(snap, hoy, fin);
    const libre = SimulationEngine.freeBalance(snap, proy);
    const cuentas = await db.query<any>(
      `SELECT c.id, c.nombre, c.tipo, COALESCE(v.saldo_actual, c.saldo_inicial) AS saldo FROM cuenta c
       LEFT JOIN vista_saldo_cuenta v ON v.cuenta_id = c.id WHERE c.usuario_id = $1 AND c.archivada = FALSE ORDER BY c.creada_en`,
      [userId]
    );
    return {
      fecha: hoy,
      saldo_disponible: snap.saldo_disponible,
      deuda_total: r2(snap.deuda_tarjetas + snap.deuda_prestamos),
      saldo_libre_proyectado: libre.libre,
      cierre_de_mes: fin,
      desglose: {
        saldo_disponible: cuentas.rows
          .filter((c) => c.tipo !== 'tarjeta')
          .map((c) => ({ cuenta: c.nombre, saldo: r2(Number(c.saldo)) })),
        deuda: { tarjetas: snap.deuda_tarjetas, prestamos: snap.deuda_prestamos },
        proyeccion: {
          ingresos_esperados: proy.ingresos,
          gastos_fijos: proy.gastos_fijos,
          cuotas_de_deuda: proy.cuotas_deuda,
          gasto_variable_estimado: proy.gasto_variable_estimado,
          compromiso_metas: proy.compromiso_metas,
          saldo_proyectado_antes_de_metas: libre.proyectado,
          fuente_ingresos: proy.fuente_ingresos,
        },
        formula: 'saldo libre = saldo disponible + ingresos esperados − gastos proyectados − compromiso de metas',
      },
    };
  }

  /** Distribución del gasto por categoría del mes indicado (RF-DAS-03). */
  public async spendingDistribution(userId: string, mes: string) {
    if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(mes)) throw new ValidationError('El mes debe tener el formato AAAA-MM');
    const start = `${mes}-01`;
    const res = await db.query<any>(
      `SELECT t.categoria_id, COALESCE(c.nombre, 'Sin categoría') AS nombre, c.color, SUM(t.monto) AS total
       FROM transaccion t LEFT JOIN categoria c ON c.id = t.categoria_id
       WHERE t.usuario_id = $1 AND t.tipo = 'gasto' AND t.eliminada = FALSE AND t.fecha >= $2 AND t.fecha <= $3
       GROUP BY t.categoria_id, c.nombre, c.color ORDER BY SUM(t.monto) DESC`,
      [userId, start, DateUtils.monthEnd(start)]
    );
    const total = r2(res.rows.reduce((s, r) => s + Number(r.total), 0));
    return {
      mes,
      total_gastos: total,
      categorias: res.rows.map((r) => ({
        categoria_id: r.categoria_id,
        nombre: r.nombre,
        color: r.color,
        monto: r2(Number(r.total)),
        porcentaje: total > 0 ? Math.round((Number(r.total) / total) * 1000) / 10 : 0,
      })),
    };
  }

  /** Ingresos y gastos de los últimos N meses, de más antiguo a más reciente (RF-DAS-04). */
  public async trend(userId: string, meses = 6) {
    const n = Math.min(Math.max(meses, 2), 24);
    const hoy = DateRules.todayIn(env.TIMEZONE);
    const first = DateUtils.addMonths(DateUtils.monthStart(hoy), -(n - 1));
    const res = await db.query<any>(
      `SELECT fecha, tipo, monto FROM transaccion
       WHERE usuario_id = $1 AND eliminada = FALSE AND tipo IN ('ingreso','gasto') AND fecha >= $2 AND fecha <= $3`,
      [userId, first, hoy]
    );
    const buckets = new Map<string, { ingresos: number; gastos: number; n: number }>();
    for (let i = 0; i < n; i++) buckets.set(DateUtils.addMonths(first, i).slice(0, 7), { ingresos: 0, gastos: 0, n: 0 });
    for (const t of res.rows) {
      const b = buckets.get(DateUtils.toDateStr(t.fecha).slice(0, 7));
      if (!b) continue;
      if (t.tipo === 'ingreso') b.ingresos += Number(t.monto);
      else b.gastos += Number(t.monto);
      b.n++;
    }
    return {
      meses: [...buckets.entries()].map(([mes, v]) => ({
        mes,
        ingresos: r2(v.ingresos),
        gastos: r2(v.gastos),
        neto: r2(v.ingresos - v.gastos),
        con_datos: v.n > 0,
      })),
    };
  }

  // ---- Exportación (RF-DAS-05) -------------------------------------------------------------------------

  public async export(
    userId: string,
    formato: 'csv' | 'xlsx' | 'pdf',
    filtros: TransactionFilter & { desde?: string; hasta?: string }
  ): Promise<ExportFile> {
    const filter: TransactionFilter = {
      cuenta_id: filtros.cuenta_id,
      categoria_id: filtros.categoria_id,
      tipo: filtros.tipo,
      busqueda: filtros.busqueda,
      fecha_inicio: filtros.fecha_inicio ?? filtros.desde,
      fecha_fin: filtros.fecha_fin ?? filtros.hasta,
      limit: 100000,
      offset: 0,
    };
    const { transactions } = await this.transactions.findByUser(userId, filter);
    const names = await db.query<any>(
      `SELECT id, nombre FROM categoria WHERE usuario_id = $1 OR usuario_id IS NULL`,
      [userId]
    );
    const accounts = await db.query<any>(`SELECT id, nombre FROM cuenta WHERE usuario_id = $1`, [userId]);
    const cat = new Map(names.rows.map((r) => [r.id as string, r.nombre as string]));
    const acc = new Map(accounts.rows.map((r) => [r.id as string, r.nombre as string]));
    const rows = transactions.map((t) => ({
      fecha: t.fecha,
      tipo: t.tipo,
      cuenta: acc.get(t.cuenta_id) ?? '',
      categoria: t.categoria_id ? cat.get(t.categoria_id) ?? '' : 'Sin categoría',
      descripcion: t.descripcion ?? '',
      monto: t.monto,
      sentido: t.sentido,
    }));
    const ingresos = r2(rows.filter((r) => r.tipo === 'ingreso').reduce((s, r) => s + r.monto, 0));
    const gastos = r2(rows.filter((r) => r.tipo === 'gasto').reduce((s, r) => s + r.monto, 0));
    const periodo = `${filter.fecha_inicio ?? 'inicio'} a ${filter.fecha_fin ?? 'hoy'}`;
    const stamp = DateRules.todayIn(env.TIMEZONE);

    let file: ExportFile;
    if (formato === 'csv') file = this.toCsv(rows, stamp);
    else if (formato === 'xlsx') file = await this.toXlsx(rows, { ingresos, gastos, periodo }, stamp);
    else file = await this.toPdf(rows, { ingresos, gastos, periodo }, stamp);

    await AuditService.log(userId, 'exportacion', 'exito', { formato, filas: rows.length, periodo });
    return file;
  }

  private toCsv(rows: Record<string, unknown>[], stamp: string): ExportFile {
    const cols = ['fecha', 'tipo', 'cuenta', 'categoria', 'descripcion', 'monto', 'sentido'];
    const esc = (v: unknown) => {
      const s = String(v ?? '');
      return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
    };
    const body = [cols.join(','), ...rows.map((r) => cols.map((c) => esc(r[c])).join(','))].join('\r\n');
    return { buffer: Buffer.from('﻿' + body, 'utf-8'), contentType: 'text/csv; charset=utf-8', filename: `nexofin_transacciones_${stamp}.csv` };
  }

  private async toXlsx(rows: Record<string, any>[], sum: { ingresos: number; gastos: number; periodo: string }, stamp: string): Promise<ExportFile> {
    const wb = new ExcelJS.Workbook();
    wb.creator = 'NexoFin';
    const ws = wb.addWorksheet('Transacciones');
    ws.columns = [
      { header: 'Fecha', key: 'fecha', width: 12 },
      { header: 'Tipo', key: 'tipo', width: 14 },
      { header: 'Cuenta', key: 'cuenta', width: 22 },
      { header: 'Categoría', key: 'categoria', width: 28 },
      { header: 'Descripción', key: 'descripcion', width: 34 },
      { header: 'Monto (RD$)', key: 'monto', width: 14, style: { numFmt: '#,##0.00' } },
    ];
    ws.getRow(1).font = { bold: true };
    rows.forEach((r) => ws.addRow(r));
    const rs = wb.addWorksheet('Resumen');
    rs.addRows([
      ['Periodo', sum.periodo],
      ['Ingresos', sum.ingresos],
      ['Gastos', sum.gastos],
      ['Saldo neto', r2(sum.ingresos - sum.gastos)],
      ['Transacciones', rows.length],
    ]);
    rs.getColumn(1).font = { bold: true };
    rs.getColumn(1).width = 18;
    rs.getColumn(2).width = 24;
    const buffer = Buffer.from(await wb.xlsx.writeBuffer());
    return { buffer, contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', filename: `nexofin_reporte_${stamp}.xlsx` };
  }

  private toPdf(rows: Record<string, any>[], sum: { ingresos: number; gastos: number; periodo: string }, stamp: string): Promise<ExportFile> {
    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const chunks: Buffer[] = [];
      doc.on('data', (c: Buffer) => chunks.push(c));
      doc.on('error', reject);
      doc.on('end', () => resolve({ buffer: Buffer.concat(chunks), contentType: 'application/pdf', filename: `nexofin_reporte_${stamp}.pdf` }));

      const money = (n: number) => `RD$ ${n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
      doc.fontSize(18).text('NexoFin · Reporte de transacciones');
      doc.moveDown(0.3).fontSize(10).fillColor('#555').text(`Periodo: ${sum.periodo}   ·   Generado: ${stamp}`);
      doc.moveDown(0.8).fillColor('#000').fontSize(11);
      doc.text(`Ingresos: ${money(sum.ingresos)}`);
      doc.text(`Gastos: ${money(sum.gastos)}`);
      doc.text(`Saldo neto: ${money(r2(sum.ingresos - sum.gastos))}`);
      doc.text(`Transacciones: ${rows.length}`);
      doc.moveDown();

      const x = [40, 105, 175, 285, 440];
      const header = () => {
        doc.fontSize(9).fillColor('#000');
        const y = doc.y;
        ['Fecha', 'Tipo', 'Categoría', 'Descripción', 'Monto'].forEach((h, i) => doc.text(h, x[i], y, { width: 100, lineBreak: false }));
        doc.moveTo(40, y + 13).lineTo(555, y + 13).stroke('#999');
        doc.y = y + 18;
      };
      header();
      for (const r of rows) {
        if (doc.y > 770) {
          doc.addPage();
          header();
        }
        const y = doc.y;
        doc.fontSize(8.5).fillColor('#222');
        doc.text(r.fecha, x[0], y, { width: 60, lineBreak: false });
        doc.text(r.tipo, x[1], y, { width: 65, lineBreak: false });
        doc.text(String(r.categoria).slice(0, 22), x[2], y, { width: 105, lineBreak: false });
        doc.text(String(r.descripcion).slice(0, 34), x[3], y, { width: 150, lineBreak: false });
        doc.text(money(r.monto), x[4], y, { width: 115, align: 'right', lineBreak: false });
        doc.y = y + 14;
      }
      doc.end();
    });
  }
}
