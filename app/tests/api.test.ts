import request from 'supertest';
import { app } from '../src/app.js';
import { db } from '../src/infrastructure/database/db.js';

describe('NexoFin AI API - Integration Tests', () => {
  let authToken: string;
  let userId: string;
  let account1Id: string;
  let account2Id: string;
  let transactionId: string;

  beforeAll(async () => {
    // Inicializar esquema de base de datos antes de las pruebas
    await db.initSchema();
  });

  afterAll(async () => {
    await db.close();
  });

  describe('1. Health & Database Connectivity', () => {
    it('GET /api/v1/health debería responder 200 y confirmar base de datos operativa', async () => {
      const res = await request(app).get('/api/v1/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('UP');
      expect(res.body.database.connected).toBe(true);
      expect(res.body.service).toBe('NexoFin AI - Financial API REST');
    });

    it('GET / debería devolver metadatos del servicio', async () => {
      const res = await request(app).get('/');
      expect(res.status).toBe(200);
      expect(res.body.name).toBe('NexoFin AI API');
    });
  });

  describe('2. Módulo de Autenticación y Usuarios (AUT)', () => {
    it('POST /api/v1/auth/register debería registrar un nuevo usuario con contraseña >= 10 caracteres', async () => {
      const res = await request(app).post('/api/v1/auth/register').send({
        nombre: 'Brailin Mendez',
        email: 'brailin@nexofin.com',
        password: 'PasswordSegura2026!',
        moneda_predeterminada: 'DOP',
      });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.user).toBeDefined();
      expect(res.body.data.user.email).toBe('brailin@nexofin.com');
      expect(res.body.data.user.password_hash).toBeUndefined(); // Seguridad: nunca enviar hash
      expect(res.body.data.token).toBeDefined();

      authToken = res.body.data.token;
      userId = res.body.data.user.id;
    });

    it('POST /api/v1/auth/register debería rechazar contraseñas de menos de 10 caracteres (RF-AUT-01)', async () => {
      const res = await request(app).post('/api/v1/auth/register').send({
        nombre: 'Test User',
        email: 'shortpass@nexofin.com',
        password: 'corta',
      });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    it('POST /api/v1/auth/register debería rechazar correos duplicados', async () => {
      const res = await request(app).post('/api/v1/auth/register').send({
        nombre: 'Duplicado',
        email: 'brailin@nexofin.com',
        password: 'PasswordSegura2026!',
      });

      expect(res.status).toBe(409);
      expect(res.body.success).toBe(false);
    });

    it('POST /api/v1/auth/login debería permitir iniciar sesión con credenciales correctas', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({
        email: 'brailin@nexofin.com',
        password: 'PasswordSegura2026!',
      });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.token).toBeDefined();
    });

    it('POST /api/v1/auth/login debería rechazar credenciales incorrectas con error 401', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({
        email: 'brailin@nexofin.com',
        password: 'PasswordErronea999!',
      });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });

    it('GET /api/v1/auth/profile debería devolver el perfil del usuario autenticado', async () => {
      const res = await request(app)
        .get('/api/v1/auth/profile')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.user.id).toBe(userId);
      expect(res.body.data.user.email).toBe('brailin@nexofin.com');
    });

    it('GET /api/v1/auth/profile sin token debería fallar con 401 Unauthorized', async () => {
      const res = await request(app).get('/api/v1/auth/profile');
      expect(res.status).toBe(401);
    });
  });

  describe('3. Módulo de Cuentas Financieras (CTA)', () => {
    it('POST /api/v1/accounts debería crear una cuenta bancaria con saldo inicial', async () => {
      const res = await request(app)
        .post('/api/v1/accounts')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          nombre: 'Cuenta Corriente Banreservas',
          tipo: 'bancaria',
          moneda: 'DOP',
          saldo_inicial: 50000.0,
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.account.nombre).toBe('Cuenta Corriente Banreservas');
      expect(res.body.data.account.saldo_actual).toBe(50000.0);

      account1Id = res.body.data.account.id;
    });

    it('POST /api/v1/accounts debería crear una segunda cuenta de efectivo', async () => {
      const res = await request(app)
        .post('/api/v1/accounts')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          nombre: 'Efectivo en Billetera',
          tipo: 'efectivo',
          moneda: 'DOP',
          saldo_inicial: 5000.0,
        });

      expect(res.status).toBe(201);
      expect(res.body.data.account.saldo_actual).toBe(5000.0);
      account2Id = res.body.data.account.id;
    });

    it('GET /api/v1/accounts debería listar todas las cuentas activas del usuario', async () => {
      const res = await request(app)
        .get('/api/v1/accounts')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.total).toBe(2);
      expect(res.body.data.accounts.length).toBe(2);
    });

    it('GET /api/v1/accounts/summary/balances debería consolidar los saldos totales por moneda', async () => {
      const res = await request(app)
        .get('/api/v1/accounts/summary/balances')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.summary.length).toBeGreaterThan(0);
      const dopSummary = res.body.data.summary.find((s: any) => s.moneda === 'DOP');
      expect(dopSummary).toBeDefined();
      expect(dopSummary.total_saldo).toBe(55000.0);
      expect(dopSummary.cantidad_cuentas).toBe(2);
    });
  });

  describe('4. Módulo de Transacciones e Historial (TRX)', () => {
    it('POST /api/v1/transactions debería registrar un ingreso con categoría del sistema', async () => {
      const res = await request(app)
        .post('/api/v1/transactions')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          cuenta_id: account1Id,
          tipo: 'ingreso',
          monto: 25000.0,
          fecha: '2026-10-25',
          descripcion: 'Nómina quincenal',
          categoria_id: 'a0000000-0000-4000-8000-000000000001', // Salario / Nómina
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.transaction.monto).toBe(25000.0);
      expect(res.body.data.transaction.sentido).toBe('entrada');

      transactionId = res.body.data.transaction.id;
    });

    it('POST /api/v1/transactions debería registrar un gasto en efectivo', async () => {
      const res = await request(app)
        .post('/api/v1/transactions')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          cuenta_id: account2Id,
          tipo: 'gasto',
          monto: 1200.5,
          fecha: '2026-10-25',
          descripcion: 'Supermercado compra semanal',
          categoria_id: 'b0000000-0000-4000-8000-000000000002', // Alimentación y Supermercado
        });

      expect(res.status).toBe(201);
      expect(res.body.data.transaction.sentido).toBe('salida');
      expect(res.body.data.transaction.monto).toBe(1200.5);
    });

    it('POST /api/v1/transactions/transfer debería transferir fondos atómicamente entre cuentas (RF-TRX-02)', async () => {
      const res = await request(app)
        .post('/api/v1/transactions/transfer')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          cuenta_origen_id: account1Id,
          cuenta_destino_id: account2Id,
          monto: 3000.0,
          fecha: '2026-10-26',
          descripcion: 'Retiro cajero para efectivo diario',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.salida.monto).toBe(3000.0);
      expect(res.body.data.salida.sentido).toBe('salida');
      expect(res.body.data.entrada.monto).toBe(3000.0);
      expect(res.body.data.entrada.sentido).toBe('entrada');
      expect(res.body.data.salida.transferencia_vinculada_id).toBe(res.body.data.entrada.id);
    });

    it('GET /api/v1/accounts debería verificar los saldos matemáticamente exactos tras transacciones', async () => {
      // Cuenta 1: saldo_inicial (50000) + entrada nómina (25000) - salida transferencia (3000) = 72000.00
      // Cuenta 2: saldo_inicial (5000) - gasto supermercado (1200.50) + entrada transferencia (3000) = 6799.50
      const res = await request(app)
        .get('/api/v1/accounts')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      const acc1 = res.body.data.accounts.find((a: any) => a.id === account1Id);
      const acc2 = res.body.data.accounts.find((a: any) => a.id === account2Id);

      expect(acc1.saldo_actual).toBe(72000.0);
      expect(acc2.saldo_actual).toBe(6799.5);
    });

    it('GET /api/v1/transactions/summary/monthly debería calcular balance neto del mes', async () => {
      const res = await request(app)
        .get('/api/v1/transactions/summary/monthly?anio=2026&mes=10')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.totalIngresos).toBe(25000.0);
      expect(res.body.data.totalGastos).toBe(1200.5);
      expect(res.body.data.balanceNeto).toBe(23799.5);
    });

    it('PUT /api/v1/transactions/:id debería actualizar una transacción y respaldar historial', async () => {
      const res = await request(app)
        .put(`/api/v1/transactions/${transactionId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          monto: 26000.0,
          descripcion: 'Nómina quincenal con bono',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.transaction.monto).toBe(26000.0);
      expect(res.body.data.transaction.descripcion).toBe('Nómina quincenal con bono');
    });

    it('DELETE /api/v1/transactions/:id debería realizar baja lógica (eliminada = true)', async () => {
      const res = await request(app)
        .delete(`/api/v1/transactions/${transactionId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.message).toContain('eliminada lógicamente');

      // Intentar obtenerla directamente debería retornar 404
      const getRes = await request(app)
        .get(`/api/v1/transactions/${transactionId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(getRes.status).toBe(404);
    });
  });
});
