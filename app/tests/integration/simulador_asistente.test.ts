import request from 'supertest';
import { app } from '../../src/app.js';
import { db } from '../../src/infrastructure/database/db.js';
import { DateRules } from '../../src/domain/services/DateRules.js';
import { DateUtils } from '../../src/domain/services/DateUtils.js';
import { Totp } from '../../src/infrastructure/security/Totp.js';
import { env } from '../../src/config/env.js';

/** Simulador (RF-SIM), asistente (RF-ASI) y seguridad de la cuenta (RF-AUT) de punta a punta. */

const PASSWORD = 'ClaveDePrueba2026!';
const TODAY = DateRules.todayIn(env.TIMEZONE);
let counter = 0;

async function registerUser(tag = 'sim') {
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
const del = (t: string, url: string, body?: object) => request(app).delete(`/api/v1${url}`).set(auth(t)).send(body);

async function account(t: string, saldo: number, tipo = 'bancaria', nombre?: string) {
  const r = await post(t, '/accounts', { nombre: nombre ?? `Cuenta ${Math.random().toString(36).slice(2, 6)}`, tipo, saldo_inicial: saldo });
  expect(r.status).toBe(201);
  return r.body.data.account.id as string;
}
async function category(t: string, nombre: string) {
  const r = await get(t, '/categories');
  return r.body.data.categories.find((c: any) => c.nombre.startsWith(nombre)).id as string;
}

/** Usuario con historial suficiente: nómina mensual, gastos de los últimos meses y una cuenta con fondos. */
async function richUser() {
  const u = await registerUser('rico');
  const cuenta = await account(u.token, 80000, 'bancaria', 'Cuenta principal');
  const inicio = DateUtils.addMonths(TODAY, -3);
  await post(u.token, '/recurring', { cuenta_id: cuenta, tipo: 'ingreso', monto: 60000, descripcion: 'Nómina', frecuencia: 'mensual', fecha_inicio: inicio });
  for (let i = 1; i <= 6; i++) {
    await post(u.token, '/transactions', {
      cuenta_id: cuenta, tipo: 'gasto', monto: 4000 + i * 100, fecha: DateUtils.addDays(TODAY, -i * 9),
      descripcion: i % 2 ? 'Supermercado Nacional' : 'Restaurante',
    });
  }
  return { ...u, cuenta };
}

beforeAll(async () => {
  await db.initSchema();
});
afterAll(async () => {
  await db.close();
});

describe('Simulador (RF-SIM-01 a 08)', () => {
  it('SA-01 · simula un gasto con saldo libre antes y después y deja registro de los datos usados', async () => {
    const u = await richUser();
    const r = await post(u.token, '/simulations/expense', { monto: 10000 });
    expect(r.status).toBe(201);
    const s = r.body.data.simulacion;
    expect(s.concluyente).toBe(true);
    const res = s.resultado.resultado;
    expect(res.saldo_libre_antes - res.saldo_libre_despues).toBeCloseTo(10000, 2);
    expect(s.datos_usados.saldo_disponible).toBeGreaterThan(0);
    expect(s.resultado.supuestos.fuente_ingresos).toBe('recurrentes');
    expect(s.resultado.aviso).toMatch(/no garantiza/i);
  });

  it('SA-02 · con datos insuficientes lo declara y no presenta cifras como exactas', async () => {
    const u = await registerUser('vacio');
    const r = await post(u.token, '/simulations/expense', { monto: 1000 });
    const s = r.body.data.simulacion;
    expect(s.concluyente).toBe(false);
    expect(s.resultado.faltantes.length).toBeGreaterThan(0);
    expect(s.resultado.resultado.saldo_libre_despues).toBeUndefined();
    expect(s.resultado.resumen).toMatch(/datos suficientes/i);
  });

  it('SA-03 · un gasto que deja el saldo en negativo propone alternativas calculadas', async () => {
    const u = await richUser();
    const r = await post(u.token, '/simulations/expense', { monto: 9_000_000 });
    const s = r.body.data.simulacion;
    expect(s.resultado.resultado.saldo_negativo).toBe(true);
    const tipos = s.resultado.alternativas.map((a: any) => a.tipo);
    expect(tipos).toEqual(expect.arrayContaining(['reducir_monto', 'posponer']));
    const reducir = s.resultado.alternativas.find((a: any) => a.tipo === 'reducir_monto');
    expect(reducir.efecto.monto_sugerido).toBeLessThan(9_000_000);
  });

  it('SA-04 · mide el efecto en el presupuesto de la categoría', async () => {
    const u = await richUser();
    const ropa = await category(u.token, 'Ropa');
    await post(u.token, '/budgets', { categoria_id: ropa, mes: TODAY.slice(0, 7), monto_limite: 3000 });
    const r = await post(u.token, '/simulations/expense', { monto: 4000, categoria_id: ropa });
    const e = r.body.data.simulacion.resultado.resultado.efecto_presupuesto;
    expect(e.supera_presupuesto).toBe(true);
    expect(e.porcentaje_despues).toBeCloseTo(133.3, 1);
  });

  it('SA-05 · calcula el ahorro mensual necesario para una meta y si es viable', async () => {
    const u = await richUser();
    const viable = await post(u.token, '/simulations/saving', { monto_objetivo: 60000, fecha_limite: DateUtils.addMonths(TODAY, 6) });
    expect(viable.body.data.simulacion.resultado.resultado.ahorro_mensual_requerido).toBe(10000);
    const imposible = await post(u.token, '/simulations/saving', { monto_objetivo: 6_000_000, fecha_limite: DateUtils.addMonths(TODAY, 6) });
    expect(imposible.body.data.simulacion.resultado.resultado.viable).toBe(false);
    expect(imposible.body.data.simulacion.resultado.alternativas.length).toBeGreaterThan(0);
  });

  it('SA-06 · simula una compra a cuotas con cuota, costo total e intereses', async () => {
    const u = await richUser();
    const r = await post(u.token, '/simulations/installments', { monto: 120000, tasa_anual: 12, num_cuotas: 12 });
    const res = r.body.data.simulacion.resultado.resultado;
    expect(res.cuota_mensual).toBeCloseTo(10661.85, 2);
    expect(res.costo_total).toBeCloseTo(res.cuota_mensual * 12, 0);
    expect(res.intereses_pagados).toBeCloseTo(res.costo_total - 120000, 2);
  });

  it('SA-07 · guarda, reabre con el resultado original y recalcula con los datos actuales', async () => {
    const u = await richUser();
    const r = await post(u.token, '/simulations/expense', { monto: 5000, guardar: true });
    const id = r.body.data.simulacion.id;
    const antes = r.body.data.simulacion.resultado.resultado.saldo_libre_antes;
    await post(u.token, '/transactions', { cuenta_id: u.cuenta, tipo: 'ingreso', monto: 20000, fecha: TODAY, descripcion: 'Bono' });
    const reopened = await get(u.token, `/simulations/${id}`);
    expect(reopened.body.data.simulacion.resultado.resultado.saldo_libre_antes).toBe(antes);
    const re = await post(u.token, `/simulations/${id}/recalculate`);
    expect(re.body.data.actual.resultado.resultado.saldo_libre_antes).toBeCloseTo(antes + 20000, 2);
    const hist = await get(u.token, '/simulations');
    expect(hist.body.data.simulaciones.map((s: any) => s.id)).toContain(id);
  });

  it('SA-08 · compara de dos a tres escenarios lado a lado', async () => {
    const u = await richUser();
    const a = (await post(u.token, '/simulations/expense', { monto: 5000 })).body.data.simulacion.id;
    const b = (await post(u.token, '/simulations/expense', { monto: 25000 })).body.data.simulacion.id;
    const cmp = await post(u.token, '/simulations/compare', { ids: [a, b] });
    expect(cmp.status).toBe(200);
    expect(cmp.body.data.escenarios).toHaveLength(2);
    expect(cmp.body.data.escenarios[0].saldo_libre_despues).toBeGreaterThan(cmp.body.data.escenarios[1].saldo_libre_despues);
    expect((await post(u.token, '/simulations/compare', { ids: [a] })).status).toBe(400);
  });

  it('SA-09 · valida entradas y aísla las simulaciones por usuario', async () => {
    const u = await richUser();
    const other = await registerUser('otro');
    expect((await post(u.token, '/simulations/expense', { monto: -5 })).status).toBe(400);
    expect((await post(u.token, '/simulations/expense', { monto: 100, fecha: DateUtils.addDays(TODAY, -3) })).status).toBe(400);
    expect((await post(u.token, '/simulations/saving', { monto_objetivo: 100, fecha_limite: DateUtils.addDays(TODAY, -1) })).status).toBe(400);
    const id = (await post(u.token, '/simulations/expense', { monto: 100 })).body.data.simulacion.id;
    expect((await get(other.token, `/simulations/${id}`)).status).toBe(404);
  });
});

describe('Asistente conversacional (RF-ASI-01 a 08)', () => {
  async function consenting() {
    const u = await richUser();
    const c = await put(u.token, '/auth/consent-ai', { otorgado: true });
    expect(c.status).toBe(200);
    return u;
  }
  const ask = (t: string, mensaje: string, conversacion_id?: string) => post(t, '/assistant/messages', { mensaje, conversacion_id });

  it('SA-10 · exige el consentimiento antes de responder', async () => {
    const u = await richUser();
    expect((await ask(u.token, 'hola')).status).toBe(403);
  });

  it('SA-11 · responde con cifras de cálculo que indican su origen y el detalle', async () => {
    const u = await consenting();
    const r = await ask(u.token, '¿Cuánto tengo?');
    const resp = r.body.data.respuesta;
    expect(resp.tipo_contenido).toBe('calculo');
    expect(resp.cifras.length).toBeGreaterThan(0);
    expect(resp.cifras.every((c: any) => c.origen && c.origen.length > 5)).toBe(true);
    expect(resp.contenido).toMatch(/RD\$/);
  });

  it('SA-12 · simula un gasto desde una pregunta natural y lo etiqueta como estimación con aviso', async () => {
    const u = await consenting();
    const r = await ask(u.token, '¿Puedo gastar 5,000 en ropa?');
    const resp = r.body.data.respuesta;
    expect(resp.tipo_contenido).toBe('estimacion');
    expect(resp.simulacion_id).toBeTruthy();
    expect(resp.contenido).toMatch(/no garantiza/i);
    const sim = await get(u.token, `/simulations/${resp.simulacion_id}`);
    expect(sim.body.data.simulacion.parametros.monto).toBe(5000);
  });

  it('SA-13 · pide los datos que faltan antes de simular y no asume valores', async () => {
    const u = await consenting();
    const r1 = await ask(u.token, 'Quiero comprar a cuotas');
    expect(r1.body.data.respuesta.simulacion_id).toBeNull();
    expect(r1.body.data.respuesta.contenido).toMatch(/monto/i);
    const conv = r1.body.data.conversacion_id;
    const r2 = await ask(u.token, '60000', conv);
    expect(r2.body.data.respuesta.contenido).toMatch(/cuotas/i);
    const r3 = await ask(u.token, '12', conv);
    expect(r3.body.data.respuesta.contenido).toMatch(/interés/i);
    const r4 = await ask(u.token, '18%', conv);
    expect(r4.body.data.respuesta.tipo_contenido).toBe('estimacion');
    const sim = await get(u.token, `/simulations/${r4.body.data.respuesta.simulacion_id}`);
    expect(sim.body.data.simulacion.parametros).toMatchObject({ monto: 60000, num_cuotas: 12, tasa_anual: 18 });
  });

  it('SA-14 · resuelve una pregunta de seguimiento con el contexto anterior', async () => {
    const u = await consenting();
    const r1 = await ask(u.token, '¿Puedo gastar 3,000 en ropa?');
    const conv = r1.body.data.conversacion_id;
    const r2 = await ask(u.token, '¿Y si fueran 20 mil?', conv);
    expect(r2.body.data.respuesta.tipo_contenido).toBe('estimacion');
    const sim = await get(u.token, `/simulations/${r2.body.data.respuesta.simulacion_id}`);
    expect(sim.body.data.simulacion.parametros.monto).toBe(20000);
  });

  it('SA-15 · rechaza consultas ajenas a las finanzas sin ejecutar operaciones', async () => {
    const u = await consenting();
    const r = await ask(u.token, '¿Cuál es la capital de Francia?');
    expect(r.body.data.respuesta.contenido).toMatch(/fuera de mi ámbito/i);
    expect(r.body.data.respuesta.simulacion_id).toBeNull();
  });

  it('SA-16 · no modifica datos sin confirmación explícita y registra solo tras el "sí"', async () => {
    const u = await consenting();
    const antes = (await get(u.token, '/transactions')).body.data.total;
    const r1 = await ask(u.token, 'Registra un gasto de 750 en farmacia');
    expect(r1.body.data.respuesta.requiere_confirmacion).toBe(true);
    expect((await get(u.token, '/transactions')).body.data.total).toBe(antes);
    const conv = r1.body.data.conversacion_id;
    await ask(u.token, 'sí', conv);
    expect((await get(u.token, '/transactions')).body.data.total).toBe(antes + 1);

    const r2 = await ask(u.token, 'Registra un gasto de 100 en café');
    await ask(u.token, 'no', r2.body.data.conversacion_id);
    expect((await get(u.token, '/transactions')).body.data.total).toBe(antes + 1);
    const del1 = await ask(u.token, 'Elimina todas mis transacciones');
    expect(del1.body.data.respuesta.contenido).toMatch(/no creo, modifico ni elimino/i);
    expect((await get(u.token, '/transactions')).body.data.total).toBe(antes + 1);
  });

  it('SA-17 · explica conceptos como contenido educativo', async () => {
    const u = await consenting();
    const r = await ask(u.token, '¿Qué es un presupuesto?');
    expect(r.body.data.respuesta.tipo_contenido).toBe('educativo');
  });

  it('SA-18 · lista y borra conversaciones sin dejar copia accesible', async () => {
    const u = await consenting();
    const r = await ask(u.token, '¿Puedo gastar 1,000 en comida?');
    const conv = r.body.data.conversacion_id;
    const simId = r.body.data.respuesta.simulacion_id;
    expect((await get(u.token, '/assistant/conversations')).body.data.conversaciones.length).toBe(1);
    const msgs = await get(u.token, `/assistant/conversations/${conv}/messages`);
    expect(msgs.body.data.mensajes).toHaveLength(2);
    expect((await del(u.token, `/assistant/conversations/${conv}`)).status).toBe(200);
    expect((await get(u.token, `/assistant/conversations/${conv}/messages`)).status).toBe(404);
    expect((await get(u.token, `/simulations/${simId}`)).status).toBe(404);
  });
});

describe('Seguridad de la cuenta (RF-AUT-04/05/06/07/09/10)', () => {
  it('SA-19 · cerrar sesión invalida el token y no se puede reutilizar', async () => {
    const u = await registerUser('logout');
    expect((await get(u.token, '/accounts')).status).toBe(200);
    expect((await post(u.token, '/auth/logout')).status).toBe(200);
    expect((await get(u.token, '/accounts')).status).toBe(401);
  });

  it('SA-20 · restablecer la contraseña usa un enlace de un solo uso y cierra las sesiones', async () => {
    const u = await registerUser('reset');
    const f = await request(app).post('/api/v1/auth/forgot-password').send({ email: u.email });
    expect(f.status).toBe(200);
    const token = String(f.body.data.enlace_demo).split('token=')[1];
    const ghost = await request(app).post('/api/v1/auth/forgot-password').send({ email: 'nadie@prueba.nexofin.test' });
    expect(ghost.status).toBe(200);
    expect(ghost.body.data.enlace_demo).toBeUndefined();
    const nueva = 'OtraClaveSegura#2026';
    expect((await request(app).post('/api/v1/auth/reset-password').send({ token, password: nueva })).status).toBe(200);
    expect((await request(app).post('/api/v1/auth/reset-password').send({ token, password: nueva })).status).toBe(400);
    expect((await get(u.token, '/accounts')).status).toBe(401);
    expect((await request(app).post('/api/v1/auth/login').send({ email: u.email, password: nueva })).status).toBe(200);
  });

  it('SA-21 · el enlace expirado de restablecimiento se rechaza', async () => {
    const u = await registerUser('expira');
    const f = await request(app).post('/api/v1/auth/forgot-password').send({ email: u.email });
    const token = String(f.body.data.enlace_demo).split('token=')[1];
    await db.query(`UPDATE token_verificacion SET expira_en = $1 WHERE usuario_id = $2`, [new Date(Date.now() - 60_000), u.id]);
    expect((await request(app).post('/api/v1/auth/reset-password').send({ token, password: 'OtraClaveSegura#2026' })).status).toBe(400);
  });

  it('SA-22 · cambiar la contraseña exige la actual y cierra las demás sesiones', async () => {
    const u = await registerUser('cambio');
    const login2 = await request(app).post('/api/v1/auth/login').send({ email: u.email, password: PASSWORD });
    const otra = login2.body.data.token as string;
    const bad = await post(u.token, '/auth/change-password', { password_actual: 'incorrecta123', password_nueva: 'NuevaClave#2026x' });
    expect(bad.status).toBe(401);
    const ok = await post(u.token, '/auth/change-password', { password_actual: PASSWORD, password_nueva: 'NuevaClave#2026x' });
    expect(ok.status).toBe(200);
    expect((await get(u.token, '/accounts')).status).toBe(200);
    expect((await get(otra, '/accounts')).status).toBe(401);
  });

  it('SA-23 · la verificación en dos pasos exige el segundo factor al iniciar sesión', async () => {
    const u = await registerUser('2fa');
    const setup = await post(u.token, '/auth/2fa/setup');
    const secreto = setup.body.data.secreto as string;
    expect((await post(u.token, '/auth/2fa/enable', { codigo: '000000' })).status).toBe(400);
    expect((await post(u.token, '/auth/2fa/enable', { codigo: Totp.code(secreto) })).status).toBe(200);
    const sin = await request(app).post('/api/v1/auth/login').send({ email: u.email, password: PASSWORD });
    expect(sin.status).toBe(401);
    expect(sin.body.error.message).toMatch(/dos pasos/i);
    const mal = await request(app).post('/api/v1/auth/login').send({ email: u.email, password: PASSWORD, codigo_2fa: '123456' });
    expect(mal.status).toBe(401);
    const bien = await request(app).post('/api/v1/auth/login').send({ email: u.email, password: PASSWORD, codigo_2fa: Totp.code(secreto) });
    expect(bien.status).toBe(200);
    expect(JSON.stringify(bien.body)).not.toContain(secreto);
    expect((await post(u.token, '/auth/2fa/disable', { password: 'incorrecta' })).status).toBe(401);
    expect((await post(u.token, '/auth/2fa/disable', { password: PASSWORD })).status).toBe(200);
  });

  it('SA-24 · rechaza contraseñas comunes aunque cumplan la longitud', async () => {
    const r = await request(app).post('/api/v1/auth/register').send({ nombre: 'Prueba', email: `comun.${Date.now()}@prueba.nexofin.test`, password: 'password123' });
    expect(r.status).toBe(400);
  });

  it('SA-25 · exporta solo los datos propios y la baja de la cuenta los elimina', async () => {
    const u = await registerUser('baja');
    const other = await registerUser('vecino');
    const c = await account(u.token, 1000);
    await account(other.token, 9999);
    await post(u.token, '/transactions', { cuenta_id: c, tipo: 'gasto', monto: 50, fecha: TODAY, descripcion: 'Café' });
    const exp = await get(u.token, '/auth/export');
    expect(exp.body.data.cuentas).toHaveLength(1);
    expect(exp.body.data.transacciones).toHaveLength(1);
    expect(JSON.stringify(exp.body)).not.toContain('9999');

    expect((await del(u.token, '/auth/account', { password: PASSWORD, confirmacion: 'no' })).status).toBe(400);
    expect((await del(u.token, '/auth/account', { password: 'mala-clave-1', confirmacion: 'ELIMINAR' })).status).toBe(401);
    expect((await del(u.token, '/auth/account', { password: PASSWORD, confirmacion: 'ELIMINAR' })).status).toBe(200);
    const gone = await db.query(`SELECT 1 FROM usuario WHERE id = $1`, [u.id]);
    expect(gone.rowCount).toBe(0);
    const left = await db.query(`SELECT 1 FROM cuenta WHERE usuario_id = $1`, [u.id]);
    expect(left.rowCount).toBe(0);
    expect((await get(other.token, '/accounts')).body.data.total).toBe(1);
    const audit = await db.query<any>(`SELECT detalle FROM bitacora_auditoria WHERE accion = 'cuenta_eliminada' AND resultado = 'exito' ORDER BY id DESC LIMIT 1`);
    expect(JSON.stringify(audit.rows[0].detalle)).not.toContain(u.email);
  });
});
