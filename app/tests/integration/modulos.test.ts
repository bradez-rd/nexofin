import request from 'supertest';
import { app } from '../../src/app.js';
import { db } from '../../src/infrastructure/database/db.js';
import { DateRules } from '../../src/domain/services/DateRules.js';
import { DateUtils } from '../../src/domain/services/DateUtils.js';
import { env } from '../../src/config/env.js';

/**
 * Pruebas de integración de los módulos de nivel 1 completados en el Entregable 5:
 * deudas, recurrentes, presupuestos, metas, categorización, notificaciones y auditoría.
 */

const PASSWORD = 'ClaveDePrueba2026!';
const TODAY = DateRules.todayIn(env.TIMEZONE);
let counter = 0;

async function registerUser(tag = 'mod') {
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
const del = (t: string, url: string) => request(app).delete(`/api/v1${url}`).set(auth(t));

async function newAccount(t: string, saldo = 100000, tipo = 'bancaria', extra: object = {}) {
  const r = await post(t, '/accounts', { nombre: `Cuenta ${Math.random().toString(36).slice(2, 6)}`, tipo, saldo_inicial: saldo, ...extra });
  expect(r.status).toBe(201);
  return r.body.data.account.id as string;
}
async function balance(t: string, id: string) {
  const r = await get(t, '/accounts');
  return Number(r.body.data.accounts.find((a: any) => a.id === id).saldo_actual);
}
async function category(t: string, nombre: string) {
  const r = await get(t, '/categories');
  return r.body.data.categories.find((c: any) => c.nombre.startsWith(nombre)).id as string;
}

beforeAll(async () => {
  await db.initSchema();
});

afterAll(async () => {
  await db.close();
});

describe('Deudas (RF-CTA-06/07/08/09)', () => {
  it('MD-01 · registra una deuda y genera su calendario de cuotas con interés', async () => {
    const u = await registerUser();
    const r = await post(u.token, '/debts', {
      acreedor: 'Banco Popular',
      monto_original: 120000,
      tasa_anual: 12,
      num_cuotas: 12,
      fecha_primera_cuota: DateUtils.addDays(TODAY, 10),
    });
    expect(r.status).toBe(201);
    const { deuda, cuotas } = r.body.data;
    expect(cuotas).toHaveLength(12);
    expect(cuotas[0].monto).toBeCloseTo(10661.85, 2);
    const capital = cuotas.reduce((s: number, c: any) => s + c.capital, 0);
    expect(Math.round(capital * 100) / 100).toBe(120000);
    expect(deuda.cuotas_restantes).toBe(12);
    expect(deuda.proxima_cuota.numero).toBe(1);
  });

  it('MD-02 · un pago genera un gasto, baja el saldo de la cuenta y reduce lo pendiente', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 50000);
    const d = await post(u.token, '/debts', {
      acreedor: 'Cooperativa', monto_original: 12000, tasa_anual: 0, num_cuotas: 4, fecha_primera_cuota: DateUtils.addDays(TODAY, 5),
    });
    const id = d.body.data.deuda.id;
    const pay = await post(u.token, `/debts/${id}/payments`, { monto: 4500, fecha: TODAY, cuenta_id: cuenta });
    expect(pay.status).toBe(201);
    expect(await balance(u.token, cuenta)).toBe(45500);
    expect(pay.body.data.deuda.saldo_pendiente).toBe(7500);
    expect(pay.body.data.deuda.cuotas_restantes).toBe(3); // 1 cuota pagada y 1 parcial
    const det = await get(u.token, `/debts/${id}`);
    expect(det.body.data.cuotas[0].estado).toBe('pagada');
    expect(det.body.data.cuotas[1].estado).toBe('parcial');
  });

  it('MD-03 · rechaza pagos mayores al saldo pendiente y deudas inválidas', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 50000);
    const d = await post(u.token, '/debts', { acreedor: 'Amigo', monto_original: 1000, num_cuotas: 2, fecha_primera_cuota: DateUtils.addDays(TODAY, 3) });
    const id = d.body.data.deuda.id;
    const over = await post(u.token, `/debts/${id}/payments`, { monto: 1500, fecha: TODAY, cuenta_id: cuenta });
    expect(over.status).toBe(400);
    expect(await balance(u.token, cuenta)).toBe(50000);
    expect((await post(u.token, '/debts', { acreedor: 'X', monto_original: -5, num_cuotas: 2, fecha_primera_cuota: TODAY })).status).toBe(400);
    expect((await post(u.token, '/debts', { acreedor: 'Xy', monto_original: 5, num_cuotas: 0, fecha_primera_cuota: TODAY })).status).toBe(400);
  });

  it('MD-04 · al pagar todo la deuda queda saldada y otro usuario no puede verla', async () => {
    const u = await registerUser();
    const other = await registerUser();
    const cuenta = await newAccount(u.token, 50000);
    const d = await post(u.token, '/debts', { acreedor: 'Tienda', monto_original: 3000, num_cuotas: 3, fecha_primera_cuota: DateUtils.addDays(TODAY, 3) });
    const id = d.body.data.deuda.id;
    const pay = await post(u.token, `/debts/${id}/payments`, { monto: 3000, fecha: TODAY, cuenta_id: cuenta });
    expect(pay.body.data.deuda.estado).toBe('saldada');
    expect((await get(other.token, `/debts/${id}`)).status).toBe(404);
  });

  it('MD-05 · el calendario de 60 días ordena cuotas, tarjetas y recurrentes de gasto', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 50000);
    await newAccount(u.token, -2000, 'tarjeta', { limite_credito: 50000, dia_corte: 5, dia_pago: 20 });
    await post(u.token, '/debts', { acreedor: 'Préstamo', monto_original: 6000, num_cuotas: 6, fecha_primera_cuota: DateUtils.addDays(TODAY, 8) });
    await post(u.token, '/recurring', { cuenta_id: cuenta, tipo: 'gasto', monto: 900, descripcion: 'Netflix', frecuencia: 'mensual', fecha_inicio: DateUtils.addDays(TODAY, 1) });
    const cal = await get(u.token, '/debts/calendar?dias=60');
    expect(cal.status).toBe(200);
    const tipos = new Set(cal.body.data.items.map((i: any) => i.tipo));
    expect(tipos.has('cuota_deuda')).toBe(true);
    expect(tipos.has('pago_tarjeta')).toBe(true);
    const fechas = cal.body.data.items.map((i: any) => i.fecha);
    expect([...fechas].sort()).toEqual(fechas);
  });
});

describe('Transacciones recurrentes (RF-TRX-06)', () => {
  it('MD-06 · genera las ocurrencias vencidas una sola vez (idempotente)', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 0);
    const inicio = DateUtils.addMonths(TODAY, -3);
    const r = await post(u.token, '/recurring', { cuenta_id: cuenta, tipo: 'ingreso', monto: 25000, descripcion: 'Nómina', frecuencia: 'mensual', fecha_inicio: inicio });
    expect(r.status).toBe(201);
    expect(r.body.data.generadas).toBe(4);
    const again = await post(u.token, '/recurring/generate');
    expect(again.body.data.generadas).toBe(0);
    expect(await balance(u.token, cuenta)).toBe(100000);
  });

  it('MD-07 · pausar detiene la generación sin alterar lo ya generado y finalizar es definitivo', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 0);
    const inicio = DateUtils.addMonths(TODAY, -1);
    const r = await post(u.token, '/recurring', { cuenta_id: cuenta, tipo: 'gasto', monto: 500, descripcion: 'Gimnasio', frecuencia: 'mensual', fecha_inicio: inicio });
    const id = r.body.data.recurrente.id;
    const antes = await balance(u.token, cuenta);
    await put(u.token, `/recurring/${id}`, { estado: 'pausada' });
    await post(u.token, '/recurring/generate');
    expect(await balance(u.token, cuenta)).toBe(antes);
    await del(u.token, `/recurring/${id}`);
    const reopen = await put(u.token, `/recurring/${id}`, { estado: 'activa' });
    expect(reopen.status).toBe(400);
  });
});

describe('Presupuestos (RF-PRE-01/02) y notificaciones (RF-NOT)', () => {
  it('MD-08 · muestra el porcentaje consumido y se actualiza al registrar y eliminar gastos', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 100000);
    const comida = await category(u.token, 'Alimentación');
    const b = await post(u.token, '/budgets', { categoria_id: comida, mes: TODAY.slice(0, 7), monto_limite: 10000 });
    if (b.status !== 201) console.log(JSON.stringify(b.body));
    expect(b.status).toBe(201);
    expect(b.body.data.budget.porcentaje).toBe(0);
    const t = await post(u.token, '/transactions', { cuenta_id: cuenta, tipo: 'gasto', monto: 2500, fecha: TODAY, categoria_id: comida, descripcion: 'Súper' });
    let list = await get(u.token, `/budgets?mes=${TODAY.slice(0, 7)}`);
    expect(list.body.data.budgets[0].porcentaje).toBe(25);
    await del(u.token, `/transactions/${t.body.data.transaction.id}`);
    list = await get(u.token, `/budgets?mes=${TODAY.slice(0, 7)}`);
    expect(list.body.data.budgets[0].consumido).toBe(0);
  });

  it('MD-09 · alerta al llegar al umbral y al superar el 100 %, sin duplicar avisos', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 100000);
    const comida = await category(u.token, 'Alimentación');
    await post(u.token, '/budgets', { categoria_id: comida, mes: TODAY.slice(0, 7), monto_limite: 1000 });
    await post(u.token, '/transactions', { cuenta_id: cuenta, tipo: 'gasto', monto: 850, fecha: TODAY, categoria_id: comida, descripcion: 'a' });
    await post(u.token, '/transactions', { cuenta_id: cuenta, tipo: 'gasto', monto: 10, fecha: TODAY, categoria_id: comida, descripcion: 'b' });
    let n = await get(u.token, '/notifications');
    expect(n.body.data.notifications.filter((x: any) => x.tipo === 'presupuesto_umbral')).toHaveLength(1);
    await post(u.token, '/transactions', { cuenta_id: cuenta, tipo: 'gasto', monto: 300, fecha: TODAY, categoria_id: comida, descripcion: 'c' });
    n = await get(u.token, '/notifications');
    expect(n.body.data.notifications.some((x: any) => x.tipo === 'presupuesto_superado')).toBe(true);
    expect(n.body.data.no_leidas).toBeGreaterThan(0);
    await post(u.token, '/notifications/read-all');
    n = await get(u.token, '/notifications');
    expect(n.body.data.no_leidas).toBe(0);
  });

  it('MD-10 · una notificación desactivada no se genera', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 100000);
    const comida = await category(u.token, 'Alimentación');
    const off = await put(u.token, '/notifications/preferences/presupuesto_superado', { canal_app: false, canal_correo: false });
    expect(off.status).toBe(200);
    await post(u.token, '/budgets', { categoria_id: comida, mes: TODAY.slice(0, 7), monto_limite: 100 });
    await post(u.token, '/transactions', { cuenta_id: cuenta, tipo: 'gasto', monto: 500, fecha: TODAY, categoria_id: comida, descripcion: 'x' });
    const n = await get(u.token, '/notifications');
    expect(n.body.data.notifications.some((x: any) => x.tipo === 'presupuesto_superado')).toBe(false);
  });

  it('MD-11 · valida presupuestos: solo gastos, sin duplicar y monto positivo', async () => {
    const u = await registerUser();
    const sueldo = await category(u.token, 'Salario');
    const comida = await category(u.token, 'Alimentación');
    const mes = TODAY.slice(0, 7);
    expect((await post(u.token, '/budgets', { categoria_id: sueldo, mes, monto_limite: 100 })).status).toBe(400);
    expect((await post(u.token, '/budgets', { categoria_id: comida, mes, monto_limite: 0 })).status).toBe(400);
    expect((await post(u.token, '/budgets', { categoria_id: comida, mes, monto_limite: 100 })).status).toBe(201);
    expect((await post(u.token, '/budgets', { categoria_id: comida, mes, monto_limite: 200 })).status).toBe(409);
  });
});

describe('Metas de ahorro (RF-PRE-03 a 06)', () => {
  it('MD-12 · calcula el monto mensual necesario y el progreso con los aportes', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 100000);
    const g = await post(u.token, '/goals', { nombre: 'Viaje', monto_objetivo: 60000, fecha_limite: DateUtils.addMonths(TODAY, 6) });
    expect(g.status).toBe(201);
    expect(g.body.data.goal.monto_mensual_necesario).toBe(10000);
    const id = g.body.data.goal.id;
    const ap = await post(u.token, `/goals/${id}/contributions`, { monto: 15000, fecha: TODAY, cuenta_id: cuenta });
    expect(ap.status).toBe(201);
    expect(await balance(u.token, cuenta)).toBe(85000);
    const meta = ap.body.data.meta;
    expect(meta.acumulado).toBe(15000);
    expect(meta.porcentaje).toBe(25);
    expect(meta.monto_mensual_necesario).toBe(7500);
    expect(meta.fecha_estimada_cumplimiento).not.toBeNull();
  });

  it('MD-13 · al completar el objetivo la meta queda alcanzada, avisa y no admite más aportes', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 100000);
    const g = await post(u.token, '/goals', { nombre: 'Laptop', monto_objetivo: 20000, fecha_limite: DateUtils.addMonths(TODAY, 2) });
    const id = g.body.data.goal.id;
    const ap = await post(u.token, `/goals/${id}/contributions`, { monto: 20000, fecha: TODAY, cuenta_id: cuenta });
    expect(ap.body.data.meta.estado).toBe('alcanzada');
    const n = await get(u.token, '/notifications');
    expect(n.body.data.notifications.some((x: any) => x.tipo === 'meta_alcanzada')).toBe(true);
    expect((await post(u.token, `/goals/${id}/contributions`, { monto: 10, fecha: TODAY, cuenta_id: cuenta })).status).toBe(400);
  });

  it('MD-14 · una meta pausada o cerrada se puede editar y valida fecha y monto', async () => {
    const u = await registerUser();
    expect((await post(u.token, '/goals', { nombre: 'Pasada', monto_objetivo: 1000, fecha_limite: DateUtils.addDays(TODAY, -1) })).status).toBe(400);
    expect((await post(u.token, '/goals', { nombre: 'Cero', monto_objetivo: 0, fecha_limite: DateUtils.addDays(TODAY, 30) })).status).toBe(400);
    const g = await post(u.token, '/goals', { nombre: 'Auto', monto_objetivo: 5000, fecha_limite: DateUtils.addDays(TODAY, 90) });
    const id = g.body.data.goal.id;
    const p = await put(u.token, `/goals/${id}`, { estado: 'pausada', nombre: 'Auto nuevo' });
    expect(p.body.data.goal.estado).toBe('pausada');
    expect(p.body.data.goal.nombre).toBe('Auto nuevo');
  });
});

describe('Categorización automática (RF-CAT-01/02/03/05/06)', () => {
  it('MD-15 · asigna categoría por palabras clave y deja "sin categoría" cuando nada coincide', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 100000);
    const a = await post(u.token, '/transactions', { cuenta_id: cuenta, tipo: 'gasto', monto: 300, fecha: TODAY, descripcion: 'Farmacia Carol' });
    expect(a.body.data.transaction.estado_categoria).toBe('categorizada');
    expect(a.body.data.transaction.categoria_id).toBe(await category(u.token, 'Salud'));
    const b = await post(u.token, '/transactions', { cuenta_id: cuenta, tipo: 'gasto', monto: 100, fecha: TODAY, descripcion: 'xyzzy qwerty' });
    expect(b.body.data.transaction.estado_categoria).toBe('sin_categoria');
    expect(b.body.data.transaction.categoria_id).toBeNull();
  });

  it('MD-16 · con baja confianza la transacción va a la bandeja de revisión sin categoría', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 100000);
    const t = await post(u.token, '/transactions', { cuenta_id: cuenta, tipo: 'gasto', monto: 100, fecha: TODAY, descripcion: 'compra' });
    expect(t.body.data.transaction.estado_categoria).toBe('pendiente_revision');
    expect(t.body.data.transaction.categoria_id).toBeNull();
    const inbox = await get(u.token, '/categories/review');
    expect(inbox.body.data.items.map((i: any) => i.id)).toContain(t.body.data.transaction.id);
  });

  it('MD-17 · la corrección manual se conserva, ofrece una regla y las reglas del usuario tienen precedencia', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 100000);
    const entret = await category(u.token, 'Entretenimiento');
    const t = await post(u.token, '/transactions', { cuenta_id: cuenta, tipo: 'gasto', monto: 100, fecha: TODAY, descripcion: 'compra tienda azul' });
    const fix = await post(u.token, `/categories/transactions/${t.body.data.transaction.id}`, { categoria_id: entret, crear_regla: true });
    expect(fix.status).toBe(200);
    expect(fix.body.data.sugerencia_regla.texto_contiene).toBe('compra tienda azul');
    expect(fix.body.data.regla_creada).not.toBeNull();
    const again = await post(u.token, '/categories/reprocess');
    expect(again.status).toBe(200);
    const got = await get(u.token, `/transactions/${t.body.data.transaction.id}`);
    expect(got.body.data.transaction.categoria_id).toBe(entret);
    const next = await post(u.token, '/transactions', { cuenta_id: cuenta, tipo: 'gasto', monto: 50, fecha: TODAY, descripcion: 'Compra tienda azul sucursal' });
    expect(next.body.data.transaction.categoria_id).toBe(entret);
  });

  it('MD-18 · las categorías del sistema no se eliminan y borrar una propia exige reasignar', async () => {
    const u = await registerUser();
    const cuenta = await newAccount(u.token, 100000);
    const sistema = await category(u.token, 'Salud');
    expect((await del(u.token, `/categories/${sistema}`)).status).toBe(400);
    const c = await post(u.token, '/categories', { nombre: 'Mascotas', tipo: 'gasto' });
    const propia = c.body.data.category.id;
    await post(u.token, '/transactions', { cuenta_id: cuenta, tipo: 'gasto', monto: 80, fecha: TODAY, categoria_id: propia, descripcion: 'Veterinario' });
    expect((await del(u.token, `/categories/${propia}`)).status).toBe(400);
    expect((await del(u.token, `/categories/${propia}?reasignar_a=${sistema}`)).status).toBe(200);
    const list = await get(u.token, '/transactions');
    expect(list.body.data.transactions[0].categoria_id).toBe(sistema);
  });
});

describe('Auditoría (RF-AUD-01/02)', () => {
  it('MD-19 · registra inicios de sesión y eliminaciones sin datos sensibles y es solo lectura', async () => {
    const u = await registerUser();
    await request(app).post('/api/v1/auth/login').send({ email: u.email, password: PASSWORD });
    await request(app).post('/api/v1/auth/login').send({ email: u.email, password: 'incorrecta-123' });
    const cuenta = await newAccount(u.token, 1000);
    const t = await post(u.token, '/transactions', { cuenta_id: cuenta, tipo: 'gasto', monto: 10, fecha: TODAY, descripcion: 'x' });
    await del(u.token, `/transactions/${t.body.data.transaction.id}`);
    const a = await get(u.token, '/audit/activity');
    const acciones = a.body.data.activity.map((x: any) => `${x.accion}:${x.resultado}`);
    expect(acciones).toEqual(expect.arrayContaining(['login:exito', 'login:fallo', 'transaccion_eliminada:exito']));
    expect(JSON.stringify(a.body)).not.toContain(PASSWORD);
    expect((await put(u.token, '/audit/activity')).status).toBe(404);
    expect((await del(u.token, '/audit/activity')).status).toBe(404);
  });
});
