import request from 'supertest';
import type Anthropic from '@anthropic-ai/sdk';
import { app } from '../../src/app.js';
import { db } from '../../src/infrastructure/database/db.js';
import { AssistantService } from '../../src/application/assistant/AssistantService.js';
import { TransactionService } from '../../src/application/transactions/TransactionService.js';
import { PostgresTransactionRepository } from '../../src/infrastructure/repositories/PostgresTransactionRepository.js';
import { PostgresAccountRepository } from '../../src/infrastructure/repositories/PostgresAccountRepository.js';
import { PostgresCategoryRepository } from '../../src/infrastructure/repositories/PostgresCategoryRepository.js';
import { LlmClient } from '../../src/infrastructure/ai/LlmClient.js';
import { ClaudeProvider } from '../../src/application/assistant/ClaudeAssistant.js';
import { DateRules } from '../../src/domain/services/DateRules.js';
import { DateUtils } from '../../src/domain/services/DateUtils.js';
import { env } from '../../src/config/env.js';

/**
 * Asistente con Claude: se prueba el bucle de herramientas con un cliente simulado que responde como lo haría
 * el modelo (pide herramientas y luego redacta). Así se verifica que las cifras salen del motor financiero,
 * que nada se registra sin confirmación y que, si Claude falla, responde el motor de reglas.
 */

const PASSWORD = 'ClaveDePrueba2026!';
const TODAY = DateRules.todayIn(env.TIMEZONE);
let counter = 0;

const msg = (content: Anthropic.ContentBlock[], stop: string): Anthropic.Message =>
  ({ id: 'msg_test', type: 'message', role: 'assistant', model: 'claude-sonnet-5-5', content, stop_reason: stop, stop_sequence: null, usage: { input_tokens: 1, output_tokens: 1 } }) as unknown as Anthropic.Message;
const toolUse = (name: string, input: object, id = 'toolu_1') => msg([{ type: 'tool_use', id, name, input } as Anthropic.ToolUseBlock], 'tool_use');
const text = (t: string) => msg([{ type: 'text', text: t, citations: null } as Anthropic.TextBlock], 'end_turn');

/** Cliente simulado: devuelve las respuestas en orden y guarda cada petición recibida. */
function fakeLlm(responses: (Anthropic.Message | Error)[]) {
  const calls: Anthropic.MessageCreateParamsNonStreaming[] = [];
  const llm: LlmClient = {
    messages: {
      create: async (params) => {
        calls.push(JSON.parse(JSON.stringify(params)));
        const next = responses.shift();
        if (!next) throw new Error('sin más respuestas simuladas');
        if (next instanceof Error) throw next;
        return next;
      },
    },
  };
  return { llm, calls };
}

async function setup() {
  counter += 1;
  const email = `claude.${Date.now()}.${counter}@prueba.nexofin.test`;
  const reg = await request(app).post('/api/v1/auth/register').send({ nombre: 'Claude Test', email, password: PASSWORD });
  const token = reg.body.data.token as string;
  const userId = reg.body.data.user.id as string;
  const auth = { Authorization: `Bearer ${token}` };
  const acc = await request(app).post('/api/v1/accounts').set(auth).send({ nombre: 'Principal', tipo: 'bancaria', saldo_inicial: 80000 });
  const cuenta = acc.body.data.account.id as string;
  await request(app).post('/api/v1/recurring').set(auth).send({ cuenta_id: cuenta, tipo: 'ingreso', monto: 60000, descripcion: 'Nómina', frecuencia: 'mensual', fecha_inicio: DateUtils.addMonths(TODAY, -3) });
  for (let i = 1; i <= 6; i++) {
    await request(app).post('/api/v1/transactions').set(auth).send({ cuenta_id: cuenta, tipo: 'gasto', monto: 3000 + i * 100, fecha: DateUtils.addDays(TODAY, -i * 9), descripcion: 'Supermercado Nacional' });
  }
  await request(app).put('/api/v1/auth/consent-ai').set(auth).send({ otorgado: true });
  return { userId, token, auth, cuenta };
}

function service(llm: LlmClient | null) {
  return new AssistantService(
    undefined,
    undefined,
    undefined,
    undefined,
    new TransactionService(new PostgresTransactionRepository(), new PostgresAccountRepository(), new PostgresCategoryRepository()),
    llm ? new ClaudeProvider(llm) : null
  );
}

beforeAll(async () => {
  await db.initSchema();
});
afterAll(async () => {
  await db.close();
});

describe('Asistente con Claude (RF-ASI)', () => {
  it('AC-01 · Claude pide la herramienta, las cifras salen del motor y la respuesta se etiqueta como estimación con aviso', async () => {
    const { userId } = await setup();
    const { llm, calls } = fakeLlm([toolUse('simulate_expense', { monto: 5000, categoria: 'ropa' }), text('Si gastas RD$ 5,000 tu saldo libre baja en esa cantidad.')]);
    const r = await service(llm).send(userId, '¿Puedo gastar 5 mil en ropa?');
    expect(r.respuesta.motor).toBe('claude');
    expect(r.respuesta.tipo_contenido).toBe('estimacion');
    expect(r.respuesta.simulacion_id).toBeTruthy();
    expect(r.respuesta.contenido).toMatch(/no garantiza/i);
    expect(r.respuesta.cifras.some((c: any) => c.etiqueta === 'Saldo libre después' && c.origen.includes('Motor de simulación'))).toBe(true);
    // El resultado de la herramienta (con las cifras) se le devuelve al modelo en la segunda llamada
    const second = calls[1].messages[calls[1].messages.length - 1] as any;
    expect(second.role).toBe('user');
    expect(second.content[0].type).toBe('tool_result');
    expect(second.content[0].content).toMatch(/Saldo libre/);
    expect(calls[0].model).toBe(env.ANTHROPIC_MODEL);
    expect(calls[0].tools!.map((t: any) => t.name)).toContain('propose_transaction');
  });

  it('AC-02 · una consulta de datos usa su herramienta y se etiqueta como cálculo con tus datos', async () => {
    const { userId } = await setup();
    const { llm } = fakeLlm([toolUse('get_balances', {}), text('Tienes disponible lo que indica el resumen.')]);
    const r = await service(llm).send(userId, '¿Cuánto tengo?');
    expect(r.respuesta.tipo_contenido).toBe('calculo');
    expect(r.respuesta.cifras[0].etiqueta).toBe('Saldo disponible');
  });

  it('AC-03 · Claude propone registrar un gasto pero no se guarda hasta que el usuario confirma con "sí"', async () => {
    const { userId, auth } = await setup();
    const before = (await request(app).get('/api/v1/transactions').set(auth)).body.data.total;
    const first = fakeLlm([toolUse('propose_transaction', { tipo: 'gasto', monto: 750, descripcion: 'Farmacia' }), text('Voy a registrar RD$ 750 en Farmacia. ¿Confirmas con "sí"?')]);
    const svc = service(first.llm);
    const r1 = await svc.send(userId, 'Registra un gasto de 750 en farmacia');
    expect(r1.respuesta.requiere_confirmacion).toBe(true);
    expect((await request(app).get('/api/v1/transactions').set(auth)).body.data.total).toBe(before);

    // La confirmación la procesa el servidor, no el modelo: no se hace ninguna llamada a Claude
    const second = fakeLlm([]);
    const r2 = await service(second.llm).send(userId, 'sí', r1.conversacion_id);
    expect(second.calls).toHaveLength(0);
    expect(r2.respuesta.contenido).toMatch(/registré/i);
    expect((await request(app).get('/api/v1/transactions').set(auth)).body.data.total).toBe(before + 1);
  });

  it('AC-04 · el historial de la conversación viaja a Claude para resolver preguntas de seguimiento', async () => {
    const { userId } = await setup();
    const a = fakeLlm([text('Con gusto. ¿Cuántas cuotas y a qué tasa?')]);
    const r1 = await service(a.llm).send(userId, 'Quiero comprar una laptop a cuotas');
    const b = fakeLlm([text('Entendido.')]);
    await service(b.llm).send(userId, '12 cuotas al 18%', r1.conversacion_id);
    const msgs = b.calls[0].messages as any[];
    expect(msgs[0]).toMatchObject({ role: 'user', content: 'Quiero comprar una laptop a cuotas' });
    expect(msgs[1].role).toBe('assistant');
    expect(msgs[msgs.length - 1]).toMatchObject({ role: 'user', content: '12 cuotas al 18%' });
  });

  it('AC-05 · si Claude no responde (error de red o clave inválida) el asistente cae al motor de reglas', async () => {
    const { userId } = await setup();
    const { llm } = fakeLlm([new Error('401 invalid x-api-key')]);
    const r = await service(llm).send(userId, '¿Cuánto tengo?');
    expect(r.respuesta.motor).toBe('reglas');
    expect(r.respuesta.contenido).toMatch(/saldo disponible/i);
  });

  it('AC-06 · si el modelo rechaza la solicitud (refusal) se responde con un mensaje seguro', async () => {
    const { userId } = await setup();
    const { llm } = fakeLlm([msg([], 'refusal')]);
    const r = await service(llm).send(userId, 'algo raro');
    expect(r.respuesta.contenido).toMatch(/No puedo ayudarte/);
    expect(r.respuesta.simulacion_id).toBeNull();
  });

  it('AC-07 · una herramienta con datos inválidos devuelve error al modelo y no crea simulaciones', async () => {
    const { userId, auth } = await setup();
    const { llm, calls } = fakeLlm([toolUse('simulate_expense', { monto: -50 }), text('Necesito un monto válido para simular.')]);
    const r = await service(llm).send(userId, 'simula gastar -50');
    const result = (calls[1].messages[calls[1].messages.length - 1] as any).content[0];
    expect(result.is_error).toBe(true);
    expect(r.respuesta.simulacion_id).toBeNull();
    expect((await request(app).get('/api/v1/simulations?todas=true').set(auth)).body.data.total).toBe(0);
  });

  it('AC-08 · por la API HTTP, con LLM_PROVIDER=reglas el asistente usa el motor de reglas', async () => {
    const { auth } = await setup();
    const r = await request(app).post('/api/v1/assistant/messages').set(auth).send({ mensaje: '¿Cuánto tengo?' });
    expect(r.status).toBe(201);
    expect(r.body.data.respuesta.motor).toBe('reglas'); // las pruebas fuerzan LLM_PROVIDER=reglas
  });
});
