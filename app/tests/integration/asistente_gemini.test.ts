import request from 'supertest';
import { app } from '../../src/app.js';
import { db } from '../../src/infrastructure/database/db.js';
import { AssistantService } from '../../src/application/assistant/AssistantService.js';
import { TransactionService } from '../../src/application/transactions/TransactionService.js';
import { PostgresTransactionRepository } from '../../src/infrastructure/repositories/PostgresTransactionRepository.js';
import { PostgresAccountRepository } from '../../src/infrastructure/repositories/PostgresAccountRepository.js';
import { PostgresCategoryRepository } from '../../src/infrastructure/repositories/PostgresCategoryRepository.js';
import { GeminiClient, GeminiHttpClient, GeminiProvider, GeminiResponse } from '../../src/application/assistant/GeminiProvider.js';
import { DateRules } from '../../src/domain/services/DateRules.js';
import { DateUtils } from '../../src/domain/services/DateUtils.js';
import { env } from '../../src/config/env.js';

/**
 * Asistente con Gemini (capa gratuita de Google AI Studio): bucle de llamadas a funciones con un cliente simulado,
 * más la verificación del cliente HTTP real con `fetch` interceptado (sin hacer llamadas de red).
 */

const PASSWORD = 'ClaveDePrueba2026!';
const TODAY = DateRules.todayIn(env.TIMEZONE);
let counter = 0;

const call = (name: string, args: Record<string, unknown>, extra: Record<string, unknown> = {}): GeminiResponse => ({
  candidates: [{ content: { role: 'model', parts: [{ functionCall: { name, args }, ...extra }] }, finishReason: 'STOP' }],
});
const say = (text: string): GeminiResponse => ({ candidates: [{ content: { role: 'model', parts: [{ text }] }, finishReason: 'STOP' }] });

function fakeGemini(responses: (GeminiResponse | Error)[]) {
  const calls: { model: string; body: any }[] = [];
  const client: GeminiClient = {
    generateContent: async (model, body) => {
      calls.push({ model, body: JSON.parse(JSON.stringify(body)) });
      const next = responses.shift();
      if (!next) throw new Error('sin más respuestas simuladas');
      if (next instanceof Error) throw next;
      return next;
    },
  };
  return { client, calls };
}

async function setup() {
  counter += 1;
  const email = `gemini.${Date.now()}.${counter}@prueba.nexofin.test`;
  const reg = await request(app).post('/api/v1/auth/register').send({ nombre: 'Gemini Test', email, password: PASSWORD });
  const token = reg.body.data.token as string;
  const auth = { Authorization: `Bearer ${token}` };
  const acc = await request(app).post('/api/v1/accounts').set(auth).send({ nombre: 'Principal', tipo: 'bancaria', saldo_inicial: 80000 });
  const cuenta = acc.body.data.account.id as string;
  await request(app).post('/api/v1/recurring').set(auth).send({ cuenta_id: cuenta, tipo: 'ingreso', monto: 60000, descripcion: 'Nómina', frecuencia: 'mensual', fecha_inicio: DateUtils.addMonths(TODAY, -3) });
  for (let i = 1; i <= 6; i++) {
    await request(app).post('/api/v1/transactions').set(auth).send({ cuenta_id: cuenta, tipo: 'gasto', monto: 3000 + i * 100, fecha: DateUtils.addDays(TODAY, -i * 9), descripcion: 'Supermercado Nacional' });
  }
  await request(app).put('/api/v1/auth/consent-ai').set(auth).send({ otorgado: true });
  return { userId: reg.body.data.user.id as string, auth };
}

const service = (client: GeminiClient | null) =>
  new AssistantService(
    undefined,
    undefined,
    undefined,
    undefined,
    new TransactionService(new PostgresTransactionRepository(), new PostgresAccountRepository(), new PostgresCategoryRepository()),
    client ? new GeminiProvider(client) : null
  );

beforeAll(async () => {
  await db.initSchema();
});
afterAll(async () => {
  await db.close();
});

describe('Asistente con Gemini (RF-ASI)', () => {
  it('AG-01 · Gemini llama a la función, recibe las cifras del motor y la respuesta queda como estimación con aviso', async () => {
    const { userId } = await setup();
    const { client, calls } = fakeGemini([call('simulate_expense', { monto: 5000, categoria: 'ropa' }, { thoughtSignature: 'firma-123' }), say('Si gastas RD$ 5,000 tu saldo libre baja en esa cantidad.')]);
    const r = await service(client).send(userId, '¿Puedo gastar 5 mil en ropa?');
    expect(r.respuesta.motor).toBe('gemini');
    expect(r.respuesta.tipo_contenido).toBe('estimacion');
    expect(r.respuesta.simulacion_id).toBeTruthy();
    expect(r.respuesta.contenido).toMatch(/no garantiza/i);
    expect(calls[0].model).toBe(env.GEMINI_MODEL);
    expect(calls[0].body.systemInstruction.parts[0].text).toMatch(/asistente financiero de NexoFin/);
    expect(calls[0].body.tools[0].functionDeclarations.map((f: any) => f.name)).toContain('propose_transaction');
    // 2.ª petición: el turno del modelo vuelve intacto (con su firma) y luego la respuesta de la función con las cifras
    const sent = calls[1].body.contents;
    expect(sent[sent.length - 2].parts[0].thoughtSignature).toBe('firma-123');
    expect(sent[sent.length - 1].parts[0].functionResponse.name).toBe('simulate_expense');
    expect(JSON.stringify(sent[sent.length - 1].parts[0].functionResponse.response)).toMatch(/Saldo libre/);
  });

  it('AG-02 · una consulta de datos usa su función y se etiqueta como cálculo', async () => {
    const { userId } = await setup();
    const { client } = fakeGemini([call('get_balances', {}), say('Tienes disponible lo que indica el resumen.')]);
    const r = await service(client).send(userId, '¿Cuánto tengo?');
    expect(r.respuesta.tipo_contenido).toBe('calculo');
    expect(r.respuesta.cifras[0].etiqueta).toBe('Saldo disponible');
  });

  it('AG-03 · propone registrar un gasto, no lo guarda hasta el "sí" y la confirmación no pasa por el modelo', async () => {
    const { userId, auth } = await setup();
    const total = async () => (await request(app).get('/api/v1/transactions').set(auth)).body.data.total;
    const before = await total();
    const a = fakeGemini([call('propose_transaction', { tipo: 'gasto', monto: 750, descripcion: 'Farmacia' }), say('Voy a registrar RD$ 750 en Farmacia. ¿Confirmas con "sí"?')]);
    const r1 = await service(a.client).send(userId, 'Registra un gasto de 750 en farmacia');
    expect(r1.respuesta.requiere_confirmacion).toBe(true);
    expect(await total()).toBe(before);
    const b = fakeGemini([]);
    await service(b.client).send(userId, 'sí', r1.conversacion_id);
    expect(b.calls).toHaveLength(0);
    expect(await total()).toBe(before + 1);
  });

  it('AG-04 · si Gemini falla (cuota agotada, clave inválida) responde el motor de reglas', async () => {
    const { userId } = await setup();
    const { client } = fakeGemini([new Error('Gemini respondió 429: quota exceeded')]);
    const r = await service(client).send(userId, '¿Cuánto tengo?');
    expect(r.respuesta.motor).toBe('reglas');
    expect(r.respuesta.contenido).toMatch(/saldo disponible/i);
  });

  it('AG-05 · una respuesta bloqueada por seguridad se contesta con un mensaje seguro', async () => {
    const { userId } = await setup();
    const { client } = fakeGemini([{ promptFeedback: { blockReason: 'SAFETY' } }]);
    const r = await service(client).send(userId, 'algo raro');
    expect(r.respuesta.contenido).toMatch(/No puedo ayudarte/);
  });

  it('AG-06 · el cliente HTTP envía la clave en el encabezado (no en la URL) y oculta detalles en los errores', async () => {
    const spy = jest.spyOn(global, 'fetch');
    spy.mockResolvedValueOnce(new Response(JSON.stringify(say('hola')), { status: 200, headers: { 'Content-Type': 'application/json' } }));
    const http = new GeminiHttpClient('clave-secreta-123', 'https://gemini.test/v1beta');
    const ok = await http.generateContent('gemini-2.5-flash', { contents: [] });
    expect(ok.candidates?.[0].content?.parts[0].text).toBe('hola');
    const [url, init] = spy.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://gemini.test/v1beta/models/gemini-2.5-flash:generateContent');
    expect(url).not.toContain('clave-secreta-123');
    expect((init.headers as Record<string, string>)['x-goog-api-key']).toBe('clave-secreta-123');

    spy.mockResolvedValueOnce(new Response(JSON.stringify({ error: { message: 'API key not valid' } }), { status: 400 }));
    await expect(http.generateContent('gemini-2.5-flash', {})).rejects.toThrow(/400: API key not valid/);
    spy.mockRestore();
  });
});
