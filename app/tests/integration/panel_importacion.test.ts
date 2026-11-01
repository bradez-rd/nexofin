import request from 'supertest';
import ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';
import { app } from '../../src/app.js';
import { db } from '../../src/infrastructure/database/db.js';
import { DateRules } from '../../src/domain/services/DateRules.js';
import { DateUtils } from '../../src/domain/services/DateUtils.js';
import { env } from '../../src/config/env.js';

/** Dashboard y reportes (RF-DAS), importación de estados de cuenta (RF-IMP) y notificaciones asociadas. */

const PASSWORD = 'ClaveDePrueba2026!';
const TODAY = DateRules.todayIn(env.TIMEZONE);
let counter = 0;

async function registerUser(tag = 'pan') {
  counter += 1;
  const email = `${tag}.${Date.now()}.${counter}@prueba.nexofin.test`;
  const res = await request(app).post('/api/v1/auth/register').send({ nombre: `Usuario ${tag}`, email, password: PASSWORD });
  expect(res.status).toBe(201);
  return { email, token: res.body.data.token as string, id: res.body.data.user.id as string };
}
const auth = (t: string) => ({ Authorization: `Bearer ${t}` });
const get = (t: string, url: string) => request(app).get(`/api/v1${url}`).set(auth(t));
const post = (t: string, url: string, body: object = {}) => request(app).post(`/api/v1${url}`).set(auth(t)).send(body);
const put = (t: string, url: string, body: object = {}) => request(app).put(`/api/v1${url}`).set(auth(t)).send(body);

async function account(t: string, saldo = 0, tipo = 'bancaria') {
  const r = await post(t, '/accounts', { nombre: `Cuenta ${Math.random().toString(36).slice(2, 6)}`, tipo, saldo_inicial: saldo });
  return r.body.data.account.id as string;
}
async function balance(t: string, id: string) {
  const r = await get(t, '/accounts');
  return Number(r.body.data.accounts.find((a: any) => a.id === id).saldo_actual);
}
const b64 = (s: string | Buffer) => Buffer.from(s).toString('base64');
const upload = (t: string, cuenta_id: string, nombre_archivo: string, contenido: string | Buffer, extra: object = {}) =>
  post(t, '/imports', { cuenta_id, nombre_archivo, contenido_base64: b64(contenido), ...extra });

const CSV = [
  'Fecha,Descripcion,Monto',
  `${DateUtils.addDays(TODAY, -10)},Supermercado Nacional,-2500.50`,
  `${DateUtils.addDays(TODAY, -8)},Nomina empresa,45000.00`,
  `${DateUtils.addDays(TODAY, -5)},Farmacia Carol,-780.00`,
  `${DateUtils.addDays(TODAY, -3)},Compra rara xyz,-120.00`,
].join('\n');

beforeAll(async () => {
  await db.initSchema();
});
afterAll(async () => {
  await db.close();
});

describe('Dashboard y reportes (RF-DAS-01 a 05)', () => {
  async function userWithData() {
    const u = await registerUser();
    const cuenta = await account(u.token, 10000);
    const otra = await account(u.token, 0);
    const tx = (body: object) => post(u.token, '/transactions', { cuenta_id: cuenta, fecha: TODAY, ...body });
    await tx({ tipo: 'ingreso', monto: 30000, descripcion: 'Nómina' });
    await tx({ tipo: 'gasto', monto: 4000, descripcion: 'Supermercado Nacional' });
    await tx({ tipo: 'gasto', monto: 1000, descripcion: 'Cine' });
    await post(u.token, '/transactions/transfer', { cuenta_origen_id: cuenta, cuenta_destino_id: otra, monto: 2000, fecha: TODAY });
    return { ...u, cuenta, otra };
  }

  it('PI-01 · el balance coincide con las transacciones del periodo y excluye las transferencias', async () => {
    const u = await userWithData();
    const r = await get(u.token, `/dashboard/summary?desde=${TODAY.slice(0, 7)}-01&hasta=${TODAY}`);
    expect(r.status).toBe(200);
    expect(r.body.data.ingresos).toBe(30000);
    expect(r.body.data.gastos).toBe(5000);
    expect(r.body.data.saldo_neto).toBe(25000);
    expect((await get(u.token, '/dashboard/summary?desde=2026-12-01&hasta=2026-01-01')).status).toBe(400);
  });

  it('PI-02 · la posición muestra saldo disponible, deuda total y saldo libre con su desglose', async () => {
    const u = await userWithData();
    await post(u.token, '/debts', { acreedor: 'Banco', monto_original: 12000, num_cuotas: 6, fecha_primera_cuota: DateUtils.addDays(TODAY, 5) });
    const r = await get(u.token, '/dashboard/position');
    expect(r.status).toBe(200);
    const d = r.body.data;
    expect(d.saldo_disponible).toBe(10000 + 30000 - 5000);
    expect(d.deuda_total).toBe(12000);
    expect(typeof d.saldo_libre_proyectado).toBe('number');
    expect(d.desglose.saldo_disponible.length).toBe(2);
    expect(d.desglose.formula).toMatch(/saldo libre/);
  });

  it('PI-03 · la distribución del gasto por categoría se actualiza al cambiar las transacciones', async () => {
    const u = await userWithData();
    const mes = TODAY.slice(0, 7);
    let r = await get(u.token, `/dashboard/spending?mes=${mes}`);
    expect(r.body.data.total_gastos).toBe(5000);
    expect(r.body.data.categorias.reduce((s: number, c: any) => s + c.porcentaje, 0)).toBeCloseTo(100, 0);
    await post(u.token, '/transactions', { cuenta_id: u.cuenta, tipo: 'gasto', monto: 5000, fecha: TODAY, descripcion: 'Farmacia' });
    r = await get(u.token, `/dashboard/spending?mes=${mes}`);
    expect(r.body.data.total_gastos).toBe(10000);
    expect((await get(u.token, '/dashboard/spending?mes=2026-13')).status).toBe(400);
  });

  it('PI-04 · la tendencia cubre los últimos seis meses e indica cuáles tienen datos', async () => {
    const u = await userWithData();
    const r = await get(u.token, '/dashboard/trend?meses=6');
    expect(r.body.data.meses).toHaveLength(6);
    const actual = r.body.data.meses[5];
    expect(actual.mes).toBe(TODAY.slice(0, 7));
    expect(actual.ingresos).toBe(30000);
    expect(actual.con_datos).toBe(true);
    expect(r.body.data.meses[0].con_datos).toBe(false);
  });

  it('PI-05 · exporta CSV, Excel y PDF con exactamente los filtros indicados', async () => {
    const u = await userWithData();
    const csv = await get(u.token, `/dashboard/export?formato=csv&tipo=gasto&desde=${TODAY.slice(0, 7)}-01&hasta=${TODAY}`);
    expect(csv.status).toBe(200);
    expect(csv.headers['content-type']).toMatch(/text\/csv/);
    const lines = csv.text.replace(/^﻿/, '').trim().split(/\r?\n/);
    expect(lines).toHaveLength(1 + 2);
    expect(lines.slice(1).every((l) => l.includes(',gasto,'))).toBe(true);

    const xlsx = await request(app).get('/api/v1/dashboard/export?formato=xlsx').set(auth(u.token)).buffer(true).parse((res, cb) => {
      const chunks: Buffer[] = [];
      res.on('data', (c: Buffer) => chunks.push(c));
      res.on('end', () => cb(null, Buffer.concat(chunks)));
    });
    expect(xlsx.status).toBe(200);
    const wb = new ExcelJS.Workbook();
    await wb.xlsx.load(xlsx.body as Buffer);
    expect(wb.getWorksheet('Transacciones')!.rowCount).toBeGreaterThan(1);

    const pdf = await request(app).get('/api/v1/dashboard/export?formato=pdf').set(auth(u.token)).buffer(true).parse((res, cb) => {
      const chunks: Buffer[] = [];
      res.on('data', (c: Buffer) => chunks.push(c));
      res.on('end', () => cb(null, Buffer.concat(chunks)));
    });
    expect(pdf.status).toBe(200);
    expect((pdf.body as Buffer).subarray(0, 5).toString()).toBe('%PDF-');
    expect((await get(u.token, '/dashboard/export?formato=docx')).status).toBe(400);
    const audit = await get(u.token, '/audit/activity');
    expect(audit.body.data.activity.some((a: any) => a.accion === 'exportacion')).toBe(true);
  });
});

describe('Importación de estados de cuenta (RF-IMP-01 a 08)', () => {
  it('PI-06 · importa un CSV, muestra el resumen para revisión y guarda al confirmar', async () => {
    const u = await registerUser('imp');
    const cuenta = await account(u.token, 0);
    const r = await upload(u.token, cuenta, 'estado_enero.csv', CSV);
    expect(r.status).toBe(201);
    expect(r.body.data.importacion.estado).toBe('lista_revision');
    expect(r.body.data.resumen.detectados).toBe(4);
    expect(r.body.data.resumen.duplicados_potenciales).toBe(0);
    expect(r.body.data.resumen.total_entradas).toBe(45000);
    expect(await balance(u.token, cuenta)).toBe(0); // aún nada guardado
    const id = r.body.data.importacion.id;
    const notif = await get(u.token, '/notifications');
    expect(notif.body.data.notifications.some((n: any) => n.tipo === 'importacion_lista')).toBe(true);

    const conf = await post(u.token, `/imports/${id}/confirm`);
    expect(conf.status).toBe(200);
    expect(conf.body.data.importacion.estado).toBe('confirmada');
    expect(await balance(u.token, cuenta)).toBeCloseTo(45000 - 2500.5 - 780 - 120, 2);
    const list = await get(u.token, '/transactions');
    const farmacia = list.body.data.transactions.find((t: any) => t.descripcion === 'Farmacia Carol');
    expect(farmacia.estado_categoria).toBe('categorizada');
    const rara = list.body.data.transactions.find((t: any) => t.descripcion === 'Compra rara xyz');
    expect(rara.categoria_id).toBeNull();
  });

  it('PI-07 · importar dos veces el mismo archivo no crea duplicados silenciosos', async () => {
    const u = await registerUser('dup');
    const cuenta = await account(u.token, 0);
    const first = await upload(u.token, cuenta, 'a.csv', CSV);
    const c1 = await post(u.token, `/imports/${first.body.data.importacion.id}/confirm`);
    const second = await upload(u.token, cuenta, 'a_otra_vez.csv', CSV);
    expect(second.body.data.resumen.duplicados_potenciales).toBe(4);
    expect(second.body.data.resumen.aprobados).toBe(0);
    expect(second.body.data.movimientos.every((m: any) => m.duplicado_potencial && m.decision === 'excluido')).toBe(true);
    expect((await post(u.token, `/imports/${second.body.data.importacion.id}/confirm`)).status).toBe(400);
    const lst = await get(u.token, '/transactions');
    expect(lst.body.data.total).toBe(4);
  });

  it('PI-08 · el usuario puede editar, excluir y aprobar movimientos antes de guardar', async () => {
    const u = await registerUser('rev');
    const cuenta = await account(u.token, 0);
    const r = await upload(u.token, cuenta, 'b.csv', CSV);
    const id = r.body.data.importacion.id;
    const [m1, m2] = r.body.data.movimientos;
    await put(u.token, `/imports/${id}/movements/${m1.id}`, { decision: 'excluido' });
    const edited = await put(u.token, `/imports/${id}/movements/${m2.id}`, { monto: 50000, descripcion: 'Nómina corregida' });
    expect(edited.body.data.movimientos.find((m: any) => m.id === m2.id).monto).toBe(50000);
    expect((await put(u.token, `/imports/${id}/movements/${m2.id}`, { monto: -3 })).status).toBe(400);
    await post(u.token, `/imports/${id}/confirm`);
    expect((await get(u.token, '/transactions')).body.data.total).toBe(3);
    expect((await put(u.token, `/imports/${id}/movements/${m2.id}`, { decision: 'excluido' })).status).toBe(400);
  });

  it('PI-09 · rechaza archivos corruptos, de formato no soportado o demasiado grandes sin afectar la sesión', async () => {
    const u = await registerUser('mal');
    const cuenta = await account(u.token, 0);
    const corrupto = await upload(u.token, cuenta, 'roto.xlsx', 'esto no es un excel');
    expect(corrupto.status).toBe(400);
    expect(corrupto.body.error.message).toMatch(/dañado|leer/i);
    expect((await upload(u.token, cuenta, 'foto.png', 'x')).status).toBe(400);
    expect((await upload(u.token, cuenta, 'viejo.xls', 'x')).body.error.message).toMatch(/XLSX/);
    expect((await upload(u.token, cuenta, 'grande.csv', Buffer.alloc(5 * 1024 * 1024 + 10, 'a'))).status).toBe(400);
    const list = await get(u.token, '/imports');
    const fallida = list.body.data.importaciones.find((i: any) => i.nombre_archivo === 'roto.xlsx');
    expect(fallida.estado).toBe('fallida');
    expect(fallida.motivo_fallo).toBeTruthy();
    expect((await get(u.token, '/accounts')).status).toBe(200);
  });

  it('PI-10 · pide el mapeo cuando no reconoce las columnas y lo reutiliza en el mismo formato', async () => {
    const u = await registerUser('map');
    const cuenta = await account(u.token, 0);
    const raro = ['Dia;Texto;Cantidad', `${DateUtils.addDays(TODAY, -2)};Pago luz Edesur;-1500`, `${DateUtils.addDays(TODAY, -1)};Deposito;8000`].join('\n');
    const sin = await upload(u.token, cuenta, 'raro.csv', raro);
    expect(sin.status).toBe(422);
    expect(sin.body.error.necesita_mapeo).toBe(true);
    expect(sin.body.error.columnas).toEqual(['Dia', 'Texto', 'Cantidad']);
    const con = await upload(u.token, cuenta, 'raro.csv', raro, { mapeo: { fecha: 0, descripcion: 1, monto: 2 } });
    expect(con.status).toBe(201);
    expect(con.body.data.resumen.detectados).toBe(2);
    const otro = ['Dia;Texto;Cantidad', `${DateUtils.addDays(TODAY, -4)};Netflix;-600`].join('\n');
    const reuse = await upload(u.token, cuenta, 'raro_febrero.csv', otro);
    expect(reuse.status).toBe(201);
    expect(reuse.body.data.movimientos[0].sentido).toBe('salida');
  });

  it('PI-11 · lee archivos Excel (XLSX) con columnas de débito y crédito', async () => {
    const u = await registerUser('xls');
    const cuenta = await account(u.token, 0);
    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet('Movimientos');
    ws.addRow(['Fecha', 'Descripción', 'Débito', 'Crédito']);
    ws.addRow([new Date(Date.UTC(2026, 9, 5)), 'Pago Altice internet', 1800, null]);
    ws.addRow([new Date(Date.UTC(2026, 9, 6)), 'Depósito nómina', null, 32000]);
    const buf = Buffer.from(await wb.xlsx.writeBuffer());
    const r = await upload(u.token, cuenta, 'banco.xlsx', buf);
    expect(r.status).toBe(201);
    expect(r.body.data.resumen.total_entradas).toBe(32000);
    expect(r.body.data.resumen.total_salidas).toBe(1800);
    expect(r.body.data.movimientos.find((m: any) => m.descripcion.includes('Altice')).fecha).toBe('2026-10-05');
  });

  it('PI-12 · extrae movimientos de un PDF (nivel 3)', async () => {
    const u = await registerUser('pdf');
    const cuenta = await account(u.token, 0);
    const buf: Buffer = await new Promise((resolve) => {
      const doc = new PDFDocument();
      const chunks: Buffer[] = [];
      doc.on('data', (c: Buffer) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.fontSize(11).text('Estado de cuenta');
      doc.text('05/10/2026 Compra Supermercado Nacional 2,500.00 47,500.00');
      doc.text('06/10/2026 Deposito nomina 30,000.00 77,500.00');
      doc.end();
    });
    const r = await upload(u.token, cuenta, 'estado.pdf', buf);
    expect(r.status).toBe(201);
    expect(r.body.data.resumen.detectados).toBe(2);
    const sal = r.body.data.movimientos.find((m: any) => m.descripcion.includes('Supermercado'));
    expect(sal).toMatchObject({ monto: 2500, sentido: 'salida', fecha: '2026-10-05' });
  });

  it('PI-13 · deshacer una importación confirmada da de baja sus movimientos y recalcula los saldos', async () => {
    const u = await registerUser('rev2');
    const cuenta = await account(u.token, 1000);
    const r = await upload(u.token, cuenta, 'c.csv', CSV);
    const id = r.body.data.importacion.id;
    expect((await post(u.token, `/imports/${id}/revert`)).status).toBe(400); // aún no confirmada
    await post(u.token, `/imports/${id}/confirm`);
    expect(await balance(u.token, cuenta)).not.toBe(1000);
    const rev = await post(u.token, `/imports/${id}/revert`);
    expect(rev.status).toBe(200);
    expect(rev.body.data.importacion.estado).toBe('revertida');
    expect(await balance(u.token, cuenta)).toBe(1000);
    await db.query(`UPDATE importacion SET estado = 'confirmada', confirmada_en = $1 WHERE id = $2`, [new Date(Date.now() - 31 * 86_400_000), id]);
    expect((await post(u.token, `/imports/${id}/revert`)).status).toBe(400);
  });

  it('PI-14 · cancelar descarta la importación y no deja movimientos; otros usuarios no la ven', async () => {
    const u = await registerUser('can');
    const other = await registerUser('ajeno');
    const cuenta = await account(u.token, 0);
    const r = await upload(u.token, cuenta, 'd.csv', CSV);
    const id = r.body.data.importacion.id;
    expect((await get(other.token, `/imports/${id}`)).status).toBe(404);
    expect((await post(u.token, `/imports/${id}/cancel`)).body.data.importacion.estado).toBe('cancelada');
    expect((await post(u.token, `/imports/${id}/confirm`)).status).toBe(400);
    expect((await get(u.token, '/transactions')).body.data.total).toBe(0);
  });
});

describe('Alertas de vencimiento (RF-NOT-01)', () => {
  it('PI-15 · avisa de las cuotas próximas con 3 días de anticipación sin repetir el aviso', async () => {
    const u = await registerUser('venc');
    await post(u.token, '/debts', { acreedor: 'Financiera', monto_original: 3000, num_cuotas: 3, fecha_primera_cuota: DateUtils.addDays(TODAY, 2) });
    await post(u.token, '/debts', { acreedor: 'Lejana', monto_original: 3000, num_cuotas: 3, fecha_primera_cuota: DateUtils.addDays(TODAY, 20) });
    const n1 = await get(u.token, '/notifications');
    const cuotas = n1.body.data.notifications.filter((n: any) => n.tipo === 'cuota_proxima');
    expect(cuotas).toHaveLength(1);
    expect(cuotas[0].mensaje).toMatch(/Financiera/);
    const n2 = await get(u.token, '/notifications');
    expect(n2.body.data.notifications.filter((n: any) => n.tipo === 'cuota_proxima')).toHaveLength(1);
  });
});
