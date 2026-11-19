import request from 'supertest';
import jwt from 'jsonwebtoken';
import { app } from '../../src/app.js';
import { db } from '../../src/infrastructure/database/db.js';
import { env } from '../../src/config/env.js';

/**
 * Pruebas de integración de procesos completos (API + dominio + base de datos PostgreSQL/pg-mem).
 * Cada prueba usa usuarios nuevos, por lo que son independientes entre sí.
 */

const PASSWORD = 'ClaveDePrueba2026!';
let counter = 0;

async function registerUser(tag = 'user') {
  counter += 1;
  const email = `${tag}.${Date.now()}.${counter}@prueba.nexofin.test`;
  const res = await request(app)
    .post('/api/v1/auth/register')
    .send({ nombre: `Usuario ${tag}`, email, password: PASSWORD });
  expect(res.status).toBe(201);
  return { email, token: res.body.data.token as string, id: res.body.data.user.id as string };
}

const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

async function createAccount(token: string, body: Record<string, unknown>) {
  const res = await request(app).post('/api/v1/accounts').set(auth(token)).send(body);
  expect(res.status).toBe(201);
  return res.body.data.account as { id: string; saldo_actual?: number };
}

async function balanceOf(token: string, accountId: string): Promise<number> {
  const res = await request(app).get('/api/v1/accounts').set(auth(token));
  const acc = res.body.data.accounts.find((a: any) => a.id === accountId);
  return Number(acc.saldo_actual);
}

async function totalBalance(token: string): Promise<number> {
  const res = await request(app).get('/api/v1/accounts').set(auth(token));
  return res.body.data.accounts.reduce((s: number, a: any) => s + Number(a.saldo_actual), 0);
}

async function addTx(token: string, body: Record<string, unknown>) {
  return request(app).post('/api/v1/transactions').set(auth(token)).send(body);
}

// Fecha de hoy en la zona horaria del sistema (America/Santo_Domingo), igual que la regla RN-DAT-03 del servidor
const today = () => new Date().toLocaleDateString('en-CA', { timeZone: env.TIMEZONE });

beforeAll(async () => {
  await db.initSchema();
});

afterAll(async () => {
  await db.close();
});

describe('Flujo 1 · Ciclo de vida de una transacción (RF-TRX-01, 03, 04, 05; RN-CTA-01; RN-DAT-04)', () => {
  it('IT-01 · registrar, editar y eliminar un gasto mantiene los saldos exactos y deja historial y baja lógica', async () => {
    const u = await registerUser('ciclo');
    const cuenta = await createAccount(u.token, { nombre: 'Cuenta Nómina', tipo: 'bancaria', saldo_inicial: 10000 });

    // 1. Registrar un gasto de 1,500 -> saldo 8,500
    const created = await addTx(u.token, {
      cuenta_id: cuenta.id, tipo: 'gasto', monto: 1500, fecha: today(), descripcion: 'Supermercado',
    });
    expect(created.status).toBe(201);
    const txId = created.body.data.transaction.id as string;
    expect(await balanceOf(u.token, cuenta.id)).toBe(8500);

    // 2. Editar el monto a 2,000 -> saldo 8,000 y se guarda el valor anterior
    const edited = await request(app).put(`/api/v1/transactions/${txId}`).set(auth(u.token)).send({ monto: 2000 });
    expect(edited.status).toBe(200);
    expect(await balanceOf(u.token, cuenta.id)).toBe(8000);
    const hist = await db.query('SELECT valores_anteriores FROM transaccion_historial WHERE transaccion_id = $1', [txId]);
    expect(hist.rows.length).toBe(1);
    expect(JSON.stringify(hist.rows[0].valores_anteriores)).toContain('1500');

    // 3. Eliminar -> el saldo se recupera, no aparece en el historial y la fila sigue existiendo (baja lógica)
    const removed = await request(app).delete(`/api/v1/transactions/${txId}`).set(auth(u.token));
    expect(removed.status).toBe(200);
    expect(await balanceOf(u.token, cuenta.id)).toBe(10000);
    const list = await request(app).get('/api/v1/transactions').set(auth(u.token));
    expect(list.body.data.transactions.map((t: any) => t.id)).not.toContain(txId);
    const row = await db.query('SELECT eliminada FROM transaccion WHERE id = $1', [txId]);
    expect(row.rows[0].eliminada).toBe(true);
  });
});

describe('Flujo 2 · Transferencias y pago de tarjeta (RF-TRX-02, RN-CTA-02, RN-TRX-03)', () => {
  it('IT-02 · una transferencia mueve el dinero exacto y el total consolidado no cambia', async () => {
    const u = await registerUser('transfer');
    const a = await createAccount(u.token, { nombre: 'Banco', tipo: 'bancaria', saldo_inicial: 5000 });
    const b = await createAccount(u.token, { nombre: 'Efectivo', tipo: 'efectivo', saldo_inicial: 200.5 });
    const before = await totalBalance(u.token);

    const res = await request(app).post('/api/v1/transactions/transfer').set(auth(u.token)).send({
      cuenta_origen_id: a.id, cuenta_destino_id: b.id, monto: 1234.56, fecha: today(),
    });
    expect(res.status).toBe(201);
    expect(res.body.data.salida.transferencia_vinculada_id).toBe(res.body.data.entrada.id);
    expect(res.body.data.entrada.transferencia_vinculada_id).toBe(res.body.data.salida.id);

    expect(await balanceOf(u.token, a.id)).toBe(3765.44);
    expect(await balanceOf(u.token, b.id)).toBe(1435.06);
    expect(await totalBalance(u.token)).toBeCloseTo(before, 2);
  });

  it('IT-03 · pagar una tarjeta es una transferencia: baja la deuda y NO cuenta como gasto del mes', async () => {
    const u = await registerUser('tarjeta');
    const banco = await createAccount(u.token, { nombre: 'Banco', tipo: 'bancaria', saldo_inicial: 50000 });
    const visa = await createAccount(u.token, {
      nombre: 'Visa', tipo: 'tarjeta', saldo_inicial: 0, limite_credito: 80000, dia_corte: 25, dia_pago: 15,
    });
    // Compra con tarjeta de 8,700 -> deuda de 8,700 (saldo -8,700)
    await addTx(u.token, { cuenta_id: visa.id, tipo: 'gasto', monto: 8700, fecha: today(), descripcion: 'Compra' });
    expect(await balanceOf(u.token, visa.id)).toBe(-8700);

    // Abono total desde el banco
    const pay = await request(app).post('/api/v1/transactions/transfer').set(auth(u.token)).send({
      cuenta_origen_id: banco.id, cuenta_destino_id: visa.id, monto: 8700, fecha: today(), descripcion: 'Pago de tarjeta',
    });
    expect(pay.status).toBe(201);
    expect(await balanceOf(u.token, visa.id)).toBe(0);
    expect(await balanceOf(u.token, banco.id)).toBe(41300);

    // El resumen del mes solo ve el gasto de la compra, no el abono
    const now = new Date();
    const summary = await request(app)
      .get(`/api/v1/transactions/summary/monthly?year=${now.getFullYear()}&month=${now.getMonth() + 1}`)
      .set(auth(u.token));
    expect(summary.status).toBe(200);
    expect(summary.body.data.totalGastos).toBe(8700);
    expect(summary.body.data.totalIngresos).toBe(0);
  });

  it('IT-04 · el resumen mensual excluye transferencias y calcula ingresos, gastos y balance neto', async () => {
    const u = await registerUser('resumen');
    const a = await createAccount(u.token, { nombre: 'Cuenta A', tipo: 'bancaria', saldo_inicial: 0 });
    const b = await createAccount(u.token, { nombre: 'Cuenta B', tipo: 'efectivo', saldo_inicial: 0 });
    await addTx(u.token, { cuenta_id: a.id, tipo: 'ingreso', monto: 1000, fecha: today() });
    await addTx(u.token, { cuenta_id: a.id, tipo: 'gasto', monto: 300, fecha: today() });
    await request(app).post('/api/v1/transactions/transfer').set(auth(u.token)).send({
      cuenta_origen_id: a.id, cuenta_destino_id: b.id, monto: 500, fecha: today(),
    });
    const res = await request(app).get('/api/v1/transactions/summary/monthly').set(auth(u.token));
    expect(res.body.data).toMatchObject({ totalIngresos: 1000, totalGastos: 300, balanceNeto: 700 });
  });

  it('IT-05 · un ajuste aumenta o disminuye el saldo según el sentido elegido (RN-TRX-01)', async () => {
    const u = await registerUser('ajuste');
    const a = await createAccount(u.token, { nombre: 'Cuenta A', tipo: 'bancaria', saldo_inicial: 1000 });
    await addTx(u.token, { cuenta_id: a.id, tipo: 'ajuste', sentido: 'entrada', monto: 50, fecha: today() });
    expect(await balanceOf(u.token, a.id)).toBe(1050);
    await addTx(u.token, { cuenta_id: a.id, tipo: 'ajuste', sentido: 'salida', monto: 75.25, fecha: today() });
    expect(await balanceOf(u.token, a.id)).toBe(974.75);
  });
});

describe('Flujo 3 · Seguridad y aislamiento de datos (RNF-SEG-05, RN-SEG-02, RF-AUT-03)', () => {
  it('IT-06 · un usuario no puede ver, editar, eliminar ni usar las cuentas y transacciones de otro', async () => {
    const owner = await registerUser('duenio');
    const intruder = await registerUser('intruso');
    const acc = await createAccount(owner.token, { nombre: 'Privada', tipo: 'bancaria', saldo_inicial: 1000 });
    const tx = await addTx(owner.token, { cuenta_id: acc.id, tipo: 'gasto', monto: 10, fecha: today() });
    const txId = tx.body.data.transaction.id as string;
    const other = await createAccount(intruder.token, { nombre: 'Mía', tipo: 'efectivo', saldo_inicial: 0 });

    expect((await request(app).get(`/api/v1/accounts/${acc.id}`).set(auth(intruder.token))).status).toBe(404);
    expect((await request(app).get(`/api/v1/transactions/${txId}`).set(auth(intruder.token))).status).toBe(404);
    expect((await request(app).put(`/api/v1/transactions/${txId}`).set(auth(intruder.token)).send({ monto: 1 })).status).toBe(404);
    expect((await request(app).delete(`/api/v1/transactions/${txId}`).set(auth(intruder.token))).status).toBe(404);
    expect((await addTx(intruder.token, { cuenta_id: acc.id, tipo: 'gasto', monto: 5, fecha: today() })).status).toBe(404);
    expect(
      (await request(app).post('/api/v1/transactions/transfer').set(auth(intruder.token)).send({
        cuenta_origen_id: other.id, cuenta_destino_id: acc.id, monto: 1, fecha: today(),
      })).status
    ).toBe(404);
    expect((await request(app).delete(`/api/v1/accounts/${acc.id}`).set(auth(intruder.token))).status).toBe(404);

    // Los listados del intruso no incluyen datos del dueño
    const list = await request(app).get('/api/v1/accounts').set(auth(intruder.token));
    expect(list.body.data.accounts.map((a: any) => a.id)).toEqual([other.id]);
    // Y el saldo del dueño no se alteró
    expect(await balanceOf(owner.token, acc.id)).toBe(990);
  });

  it('IT-07 · tras 5 intentos fallidos la cuenta se bloquea, aun con la contraseña correcta (RN-SEG-02)', async () => {
    const u = await registerUser('bloqueo');
    for (let i = 0; i < 5; i++) {
      const bad = await request(app).post('/api/v1/auth/login').send({ email: u.email, password: 'incorrecta-123' });
      expect(bad.status).toBe(401);
      expect(bad.body.error.message).toBe('Credenciales inválidas');
    }
    const locked = await request(app).post('/api/v1/auth/login').send({ email: u.email, password: PASSWORD });
    expect(locked.status).toBe(401);
    expect(locked.body.error.message).toMatch(/bloquead/i);
  });

  it('IT-08 · el error de login es genérico: no revela si el correo existe (RF-AUT-03)', async () => {
    const u = await registerUser('enum');
    const wrongPass = await request(app).post('/api/v1/auth/login').send({ email: u.email, password: 'incorrecta-123' });
    const unknown = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'no.existe@prueba.nexofin.test', password: 'incorrecta-123' });
    expect(wrongPass.status).toBe(unknown.status);
    expect(wrongPass.body.error.message).toBe(unknown.body.error.message);
  });

  it('IT-09 · rutas protegidas rechazan tokens ausentes, manipulados, expirados y de otra firma', async () => {
    const u = await registerUser('token');
    const expired = jwt.sign({ userId: u.id, email: u.email }, env.JWT_SECRET, { expiresIn: -60 });
    const forged = jwt.sign({ userId: u.id, email: u.email }, 'otra-clave');
    const tampered = u.token.slice(0, -3) + 'xyz';
    for (const header of [{}, auth(expired), auth(forged), auth(tampered), { Authorization: 'Basic abc' }]) {
      const res = await request(app).get('/api/v1/accounts').set(header as Record<string, string>);
      expect(res.status).toBe(401);
    }
  });

  it('IT-10 · ninguna respuesta de autenticación expone el hash de la contraseña (RNF-SEG-02)', async () => {
    const u = await registerUser('hash');
    const login = await request(app).post('/api/v1/auth/login').send({ email: u.email, password: PASSWORD });
    const profile = await request(app).get('/api/v1/auth/profile').set(auth(u.token));
    for (const body of [login.body, profile.body]) {
      expect(JSON.stringify(body)).not.toMatch(/password|\$2[aby]\$/i);
    }
  });
});

describe('Flujo 4 · Cuentas archivadas y consultas (RN-CTA-03, RF-TRX-05, RF-CTA-05)', () => {
  it('IT-11 · una cuenta archivada no admite movimientos ni transferencias y sale de los listados', async () => {
    const u = await registerUser('archivo');
    const vieja = await createAccount(u.token, { nombre: 'Vieja', tipo: 'bancaria', saldo_inicial: 100 });
    const activa = await createAccount(u.token, { nombre: 'Activa', tipo: 'bancaria', saldo_inicial: 100 });
    expect((await request(app).delete(`/api/v1/accounts/${vieja.id}`).set(auth(u.token))).status).toBe(200);

    expect((await addTx(u.token, { cuenta_id: vieja.id, tipo: 'gasto', monto: 5, fecha: today() })).status).toBe(400);
    expect(
      (await request(app).post('/api/v1/transactions/transfer').set(auth(u.token)).send({
        cuenta_origen_id: activa.id, cuenta_destino_id: vieja.id, monto: 5, fecha: today(),
      })).status
    ).toBe(400);
    const list = await request(app).get('/api/v1/accounts').set(auth(u.token));
    expect(list.body.data.accounts.map((a: any) => a.id)).toEqual([activa.id]);
  });

  it('IT-12 · el historial filtra por tipo, texto y fechas, y pagina con total correcto', async () => {
    const u = await registerUser('filtros');
    const a = await createAccount(u.token, { nombre: 'Cuenta A', tipo: 'bancaria', saldo_inicial: 0 });
    for (let i = 1; i <= 25; i++) {
      await addTx(u.token, {
        cuenta_id: a.id, tipo: 'gasto', monto: 10 + i, fecha: today(), descripcion: i % 5 === 0 ? `Farmacia ${i}` : `Compra ${i}`,
      });
    }
    await addTx(u.token, { cuenta_id: a.id, tipo: 'ingreso', monto: 5000, fecha: '2026-01-15', descripcion: 'Nómina enero' });

    const page1 = await request(app).get('/api/v1/transactions?limit=10&offset=0').set(auth(u.token));
    expect(page1.body.data.total).toBe(26);
    expect(page1.body.data.transactions.length).toBe(10);
    const page3 = await request(app).get('/api/v1/transactions?limit=10&offset=20').set(auth(u.token));
    expect(page3.body.data.transactions.length).toBe(6);

    const ingresos = await request(app).get('/api/v1/transactions?tipo=ingreso').set(auth(u.token));
    expect(ingresos.body.data.total).toBe(1);
    const texto = await request(app).get('/api/v1/transactions?busqueda=Farmacia').set(auth(u.token));
    expect(texto.body.data.total).toBe(5);
    const rango = await request(app)
      .get('/api/v1/transactions?fecha_inicio=2026-01-01&fecha_fin=2026-01-31')
      .set(auth(u.token));
    expect(rango.body.data.total).toBe(1);
  });

  it('IT-13 · el patrimonio consolidado por moneda suma solo las cuentas activas (RF-CTA-05)', async () => {
    const u = await registerUser('consolidado');
    await createAccount(u.token, { nombre: 'Cuenta A', tipo: 'bancaria', saldo_inicial: 1000.5 });
    const b = await createAccount(u.token, { nombre: 'Cuenta B', tipo: 'efectivo', saldo_inicial: 200.25 });
    const c = await createAccount(u.token, { nombre: 'Cuenta C', tipo: 'bancaria', saldo_inicial: 999 });
    await request(app).delete(`/api/v1/accounts/${c.id}`).set(auth(u.token));
    await addTx(u.token, { cuenta_id: b.id, tipo: 'gasto', monto: 50.25, fecha: today() });
    const res = await request(app).get('/api/v1/accounts/summary/balances').set(auth(u.token));
    expect(res.body.data.summary[0]).toMatchObject({ moneda: 'DOP', total_saldo: 1150.5, cantidad_cuentas: 2 });
  });
});

describe('Flujo 5 · Reglas de negocio y validaciones de extremo a extremo (RN-TRX-01/02, RN-DAT-01)', () => {
  let token: string;
  let accountId: string;
  let otherId: string;

  beforeAll(async () => {
    const u = await registerUser('reglas');
    token = u.token;
    accountId = (await createAccount(token, { nombre: 'Principal', tipo: 'bancaria', saldo_inicial: 1000 })).id;
    otherId = (await createAccount(token, { nombre: 'Secundaria', tipo: 'efectivo', saldo_inicial: 0 })).id;
  });

  it('IT-14 · rechaza monto cero o negativo con error 400', async () => {
    expect((await addTx(token, { cuenta_id: accountId, tipo: 'gasto', monto: 0, fecha: today() })).status).toBe(400);
    expect((await addTx(token, { cuenta_id: accountId, tipo: 'gasto', monto: -20, fecha: today() })).status).toBe(400);
  });

  it('IT-15 · rechaza una transferencia a la misma cuenta, con monto cero o hacia una cuenta inexistente', async () => {
    const send = (b: Record<string, unknown>) =>
      request(app).post('/api/v1/transactions/transfer').set(auth(token)).send({ fecha: today(), ...b });
    expect((await send({ cuenta_origen_id: accountId, cuenta_destino_id: accountId, monto: 10 })).status).toBe(400);
    expect((await send({ cuenta_origen_id: accountId, cuenta_destino_id: otherId, monto: 0 })).status).toBe(400);
    expect(
      (await send({ cuenta_origen_id: accountId, cuenta_destino_id: '99999999-9999-4999-8999-999999999999', monto: 10 })).status
    ).toBe(404);
  });

  it('IT-16 · redondea montos con tres decimales a 2 con "mitad hacia arriba" (RN-DAT-01)', async () => {
    const res = await addTx(token, { cuenta_id: accountId, tipo: 'ingreso', monto: 2.135, fecha: today() });
    expect(res.status).toBe(201);
    expect(Number(res.body.data.transaction.monto)).toBe(2.14);
  });

  it('IT-17 · rechaza una fecha futura en una transacción manual (RN-TRX-02)', async () => {
    const res = await addTx(token, { cuenta_id: accountId, tipo: 'gasto', monto: 10, fecha: '2999-01-01' });
    expect(res.status).toBe(400);
  });

  it('IT-18 · rechaza una fecha inexistente como 2026-02-30 con 400 y no con error interno 500', async () => {
    const res = await addTx(token, { cuenta_id: accountId, tipo: 'gasto', monto: 10, fecha: '2026-02-30' });
    expect(res.status).toBe(400);
  });

  it('IT-19 · eliminar una pata de una transferencia no deja el dinero descuadrado (RF-TRX-02, RNF-CON-05)', async () => {
    const u = await registerUser('patas');
    const a = await createAccount(u.token, { nombre: 'Cuenta A', tipo: 'bancaria', saldo_inicial: 1000 });
    const b = await createAccount(u.token, { nombre: 'Cuenta B', tipo: 'efectivo', saldo_inicial: 0 });
    const t = await request(app).post('/api/v1/transactions/transfer').set(auth(u.token)).send({
      cuenta_origen_id: a.id, cuenta_destino_id: b.id, monto: 400, fecha: today(),
    });
    const totalBefore = await totalBalance(u.token);
    await request(app).delete(`/api/v1/transactions/${t.body.data.salida.id}`).set(auth(u.token));
    // Una transferencia mueve dinero entre cuentas propias: el total consolidado debe seguir igual
    expect(await totalBalance(u.token)).toBeCloseTo(totalBefore, 2);
  });

  it('IT-21 · una transferencia no se puede editar (solo eliminar y volver a registrar)', async () => {
    const u = await registerUser('editarpata');
    const a = await createAccount(u.token, { nombre: 'Cuenta A', tipo: 'bancaria', saldo_inicial: 1000 });
    const b = await createAccount(u.token, { nombre: 'Cuenta B', tipo: 'efectivo', saldo_inicial: 0 });
    const t = await request(app).post('/api/v1/transactions/transfer').set(auth(u.token)).send({
      cuenta_origen_id: a.id, cuenta_destino_id: b.id, monto: 100, fecha: today(),
    });
    const edit = await request(app).put(`/api/v1/transactions/${t.body.data.salida.id}`).set(auth(u.token)).send({ monto: 999 });
    expect(edit.status).toBe(400);
    expect(await balanceOf(u.token, a.id)).toBe(900);
    expect(await balanceOf(u.token, b.id)).toBe(100);
  });

  it('IT-22 · eliminar una transferencia da de baja las dos patas y devuelve los saldos originales', async () => {
    const u = await registerUser('bajapar');
    const a = await createAccount(u.token, { nombre: 'Cuenta A', tipo: 'bancaria', saldo_inicial: 1000 });
    const b = await createAccount(u.token, { nombre: 'Cuenta B', tipo: 'efectivo', saldo_inicial: 50 });
    const t = await request(app).post('/api/v1/transactions/transfer').set(auth(u.token)).send({
      cuenta_origen_id: a.id, cuenta_destino_id: b.id, monto: 400, fecha: today(),
    });
    const del = await request(app).delete(`/api/v1/transactions/${t.body.data.entrada.id}`).set(auth(u.token));
    expect(del.status).toBe(200);
    expect(await balanceOf(u.token, a.id)).toBe(1000);
    expect(await balanceOf(u.token, b.id)).toBe(50);
    const list = await request(app).get('/api/v1/transactions').set(auth(u.token));
    expect(list.body.data.total).toBe(0);
  });

  it('IT-20 · el login con muchos intentos rápidos de un mismo origen es limitado con 429 (RNF-SEG-06)', async () => {
    const statuses: number[] = [];
    for (let i = 0; i < 40; i++) {
      const r = await request(app).post('/api/v1/auth/login').send({ email: `nadie${i}@prueba.nexofin.test`, password: 'x-incorrecta' });
      statuses.push(r.status);
    }
    expect(statuses).toContain(429);
  });
});
