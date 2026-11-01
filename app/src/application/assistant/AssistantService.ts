import { db } from '../../infrastructure/database/db.js';
import { AssistantEngine, ParsedMessage, Intent, Periodo, EDUCATION, norm } from '../../domain/services/AssistantEngine.js';
import { CategorizationEngine } from '../../domain/services/CategorizationEngine.js';
import { DISCLAIMER } from '../../domain/services/SimulationEngine.js';
import { DateRules } from '../../domain/services/DateRules.js';
import { DateUtils } from '../../domain/services/DateUtils.js';
import { FinancialCalculator } from '../../domain/services/FinancialCalculator.js';
import { ForbiddenError, NotFoundError, ValidationError } from '../../domain/errors/DomainError.js';
import { SimulationService, StoredSimulation } from '../simulation/SimulationService.js';
import { BudgetService } from '../budgets/BudgetService.js';
import { GoalService } from '../goals/GoalService.js';
import { DebtService } from '../debts/DebtService.js';
import { TransactionService } from '../transactions/TransactionService.js';
import { env } from '../../config/env.js';
import { AssistantLlm, HistoryMessage } from './AssistantLlm.js';

const money = (n: number) =>
  `RD$ ${n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
const r2 = (n: number) => FinancialCalculator.roundMoney(n);

type ContentType = 'calculo' | 'estimacion' | 'educativo' | null;

interface Figure {
  etiqueta: string;
  valor: number | string;
  origen: string;
}

interface State {
  intent?: Intent;
  params?: Record<string, any>;
  faltan?: string[];
  pending_action?: { tipo: 'crear_transaccion'; datos: Record<string, any>; resumen: string };
}

interface Reply {
  contenido: string;
  tipo: ContentType;
  cifras?: Figure[];
  simulacion?: StoredSimulation;
  estado?: State;
  acciones?: string[];
  motor?: 'claude' | 'gemini' | 'reglas';
}

export interface StoredMessage {
  id: string;
  rol: 'usuario' | 'asistente';
  contenido: string;
  tipo_contenido: ContentType;
  detalle_calculo: Record<string, any> | null;
  simulacion_id: string | null;
  creado_en: Date;
}

const ASK: Record<string, string> = {
  monto: '¿De cuánto es el monto? (por ejemplo: 5,000)',
  num_cuotas: '¿En cuántas cuotas sería?',
  tasa_anual: '¿Qué tasa de interés anual tiene? (si es sin interés, escribe 0)',
  plazo_meses: '¿En cuántos meses quieres lograrlo?',
  cuenta: '¿En cuál de tus cuentas lo registro?',
};

const json = (v: unknown) => (typeof v === 'string' ? JSON.parse(v) : v);

/**
 * Asistente conversacional (RF-ASI-01 a 08). Interpreta la pregunta, pide los datos faltantes,
 * ejecuta el motor financiero o consultas sobre los datos del usuario y explica el resultado
 * indicando su origen. Por defecto solo consulta: cualquier cambio exige confirmación explícita.
 */
export class AssistantService {
  constructor(
    private readonly simulations = new SimulationService(),
    private readonly budgets = new BudgetService(),
    private readonly goals = new GoalService(),
    private readonly debts = new DebtService(),
    private readonly createTransaction?: TransactionService,
    /** Proveedor de IA (Gemini o Claude); sin él el asistente responde con su motor de reglas local. */
    private readonly llm: AssistantLlm | null = null
  ) {}

  private async assertConsent(userId: string): Promise<void> {
    const u = await db.query<any>(`SELECT consentimiento_ia_en FROM usuario WHERE id = $1`, [userId]);
    if (!u.rows[0]?.consentimiento_ia_en) {
      throw new ForbiddenError('Para usar el asistente debes aceptar el consentimiento de uso de tus datos (PUT /auth/consent-ai)');
    }
  }

  // ---- Conversaciones (RF-ASI-08) ----------------------------------------------------------------

  public async listConversations(userId: string) {
    const res = await db.query<any>(
      `SELECT id, titulo, creada_en FROM conversacion WHERE usuario_id = $1 ORDER BY creada_en DESC LIMIT 100`,
      [userId]
    );
    return res.rows.map((r) => ({ id: r.id, titulo: r.titulo, creada_en: new Date(r.creada_en) }));
  }

  private async assertConversation(userId: string, id: string): Promise<void> {
    const c = await db.query(`SELECT 1 FROM conversacion WHERE id = $1 AND usuario_id = $2`, [id, userId]);
    if (c.rowCount === 0) throw new NotFoundError('Conversación no encontrada');
  }

  public async messages(userId: string, conversationId: string): Promise<StoredMessage[]> {
    await this.assertConversation(userId, conversationId);
    const res = await db.query<any>(
      `SELECT * FROM mensaje WHERE conversacion_id = $1 ORDER BY creado_en ASC, rol DESC`,
      [conversationId]
    );
    return res.rows.map((r) => ({
      id: r.id,
      rol: r.rol,
      contenido: r.contenido,
      tipo_contenido: r.tipo_contenido,
      detalle_calculo: r.detalle_calculo ? json(r.detalle_calculo) : null,
      simulacion_id: r.simulacion_id,
      creado_en: new Date(r.creado_en),
    }));
  }

  /** Al borrar una conversación no queda copia accesible: se eliminan mensajes y simulaciones no guardadas. */
  public async deleteConversation(userId: string, id: string): Promise<void> {
    await this.assertConversation(userId, id);
    const sims = await db.query<any>(
      `SELECT DISTINCT simulacion_id FROM mensaje WHERE conversacion_id = $1 AND simulacion_id IS NOT NULL`,
      [id]
    );
    await db.query(`DELETE FROM mensaje WHERE conversacion_id = $1`, [id]);
    await db.query(`DELETE FROM conversacion WHERE id = $1 AND usuario_id = $2`, [id, userId]);
    for (const s of sims.rows) {
      await db.query(`DELETE FROM simulacion WHERE id = $1 AND usuario_id = $2 AND guardada = FALSE`, [s.simulacion_id, userId]);
    }
  }

  // ---- Envío de mensajes -----------------------------------------------------------------------------

  public async send(userId: string, text: string, conversationId?: string) {
    await this.assertConsent(userId);
    const message = text.trim();
    if (!message) throw new ValidationError('Escribe una pregunta');

    let convId = conversationId;
    if (convId) await this.assertConversation(userId, convId);
    else {
      const c = await db.query<any>(`INSERT INTO conversacion (usuario_id, titulo) VALUES ($1,$2) RETURNING id`, [
        userId,
        message.slice(0, 60),
      ]);
      convId = c.rows[0].id as string;
    }

    const history = await this.messages(userId, convId);
    const lastState: State = [...history].reverse().find((m) => m.rol === 'asistente')?.detalle_calculo?.estado ?? {};

    await db.query(`INSERT INTO mensaje (conversacion_id, rol, contenido) VALUES ($1,'usuario',$2)`, [convId, message]);
    const reply = await this.reply(userId, message, lastState, history);

    const detalle = {
      cifras: reply.cifras ?? [],
      fuentes: [...new Set((reply.cifras ?? []).map((c) => c.origen))],
      simulacion: reply.simulacion?.resultado ?? null,
      datos_usados: reply.simulacion?.datos_usados ?? null,
      acciones_sugeridas: reply.acciones ?? [],
      estado: reply.estado ?? {},
      motor: reply.motor ?? 'reglas',
    };
    const saved = await db.query<any>(
      `INSERT INTO mensaje (conversacion_id, simulacion_id, rol, contenido, tipo_contenido, detalle_calculo)
       VALUES ($1,$2,'asistente',$3,$4,$5) RETURNING id, creado_en`,
      [convId, reply.simulacion?.id ?? null, reply.contenido, reply.tipo, JSON.stringify(detalle)]
    );
    return {
      conversacion_id: convId,
      respuesta: {
        id: saved.rows[0].id,
        contenido: reply.contenido,
        tipo_contenido: reply.tipo,
        cifras: detalle.cifras,
        fuentes: detalle.fuentes,
        simulacion_id: reply.simulacion?.id ?? null,
        acciones_sugeridas: detalle.acciones_sugeridas,
        requiere_confirmacion: Boolean(reply.estado?.pending_action),
        motor: reply.motor ?? 'reglas',
      },
    };
  }

  // ---- Lógica de respuesta ------------------------------------------------------------------------------

  private async reply(userId: string, message: string, state: State, history: StoredMessage[] = []): Promise<Reply> {
    const parsed = AssistantEngine.parse(message);

    // 1) Confirmación o cancelación de una acción pendiente (RF-ASI-06)
    if (state.pending_action) {
      if (parsed.confirmar) return this.executePending(userId, state.pending_action);
      if (parsed.cancelar) return { contenido: 'Listo, no registré nada.', tipo: null };
    }

    // 1b) Con un proveedor de IA disponible, el modelo entiende la pregunta y las herramientas calculan las cifras.
    //     Si el servicio de IA falla, se responde con el motor de reglas local.
    if (this.llm) {
      try {
        return await this.llmReply(userId, message, history);
      } catch (e: any) {
        console.error('[Asistente] La IA no respondió, se usa el motor de reglas:', e?.message ?? e);
      }
    }

    // 2) Datos faltantes de la pregunta anterior (RF-ASI-03)
    if (state.faltan && state.faltan.length > 0 && state.intent) {
      const filled = this.fillSlot(state, parsed, message);
      if (filled) return this.handle(userId, state.intent, filled, parsed, message);
    }

    // 3) Pregunta de seguimiento sin intención nueva (RF-ASI-08)
    if ((parsed.intent === 'desconocida' || parsed.intent === 'fuera_ambito') && state.intent && state.params && !parsed.modifica_datos) {
      const hasNew = parsed.monto !== undefined || parsed.num_cuotas !== undefined || parsed.plazo_meses !== undefined || parsed.tasa_anual !== undefined;
      if (hasNew && ['simular_gasto', 'ahorro_meta', 'compra_cuotas'].includes(state.intent)) {
        const params = { ...state.params };
        if (parsed.monto !== undefined) params.monto = parsed.monto;
        if (parsed.num_cuotas !== undefined) params.num_cuotas = parsed.num_cuotas;
        if (parsed.plazo_meses !== undefined) params.plazo_meses = parsed.plazo_meses;
        if (parsed.tasa_anual !== undefined) params.tasa_anual = parsed.tasa_anual;
        return this.handle(userId, state.intent, params, parsed, message);
      }
    }

    return this.handle(userId, parsed.intent, this.paramsFrom(parsed, message), parsed, message);
  }

  // ---- Asistente con Claude ---------------------------------------------------------------------------

  private toMessageParams(history: StoredMessage[]): HistoryMessage[] {
    const out: HistoryMessage[] = [];
    for (const m of history.slice(-12)) {
      const role = m.rol === 'usuario' ? 'user' : 'assistant';
      if (out.length === 0 && role === 'assistant') continue; // la conversación debe empezar con el usuario
      if (out.length > 0 && out[out.length - 1].role === role) continue;
      out.push({ role, content: m.contenido });
    }
    if (out.length > 0 && out[out.length - 1].role === 'user') out.pop(); // el mensaje nuevo ya va aparte
    return out;
  }

  private async llmReply(userId: string, message: string, history: StoredMessage[]): Promise<Reply> {
    const figures: Figure[] = [];
    let simulation: StoredSimulation | undefined;
    let pending: State['pending_action'];

    const fold = (r: Reply): string => {
      figures.push(...(r.cifras ?? []));
      if (r.simulacion) simulation = r.simulacion;
      if (r.estado?.pending_action) pending = r.estado.pending_action;
      const cif = (r.cifras ?? []).map((c) => `${c.etiqueta}: ${c.valor}`).join('; ');
      return `${r.contenido}${cif ? `\n\nCifras: ${cif}` : ''}`;
    };
    const category = (text: unknown) => {
      if (typeof text !== 'string' || !text.trim()) return undefined;
      const c = CategorizationEngine.classify(text, 'gasto');
      return c.estado === 'categorizada' ? (c.categoria_id ?? undefined) : undefined;
    };
    const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : undefined);

    const run = await this.llm!.runTurn(this.toMessageParams(history), message, async (name, input) => {
      switch (name) {
        case 'get_balances':
          return { content: fold(await this.query(userId, 'saldo', undefined, undefined, message)) };
        case 'get_debts':
          return { content: fold(await this.query(userId, 'deudas', undefined, undefined, message)) };
        case 'get_budgets':
          return { content: fold(await this.query(userId, 'presupuestos', undefined, undefined, message)) };
        case 'get_goals':
          return { content: fold(await this.query(userId, 'metas', undefined, undefined, message)) };
        case 'get_spending': {
          const intent: Intent = input.tipo === 'ingreso' ? 'ingreso_periodo' : 'gasto_periodo';
          return { content: fold(await this.query(userId, intent, input.periodo as Periodo | undefined, category(input.categoria), message)) };
        }
        case 'simulate_expense': {
          const monto = num(input.monto);
          if (!monto || monto <= 0) return { content: 'El monto debe ser un número mayor que cero.', isError: true };
          const cat = category(input.categoria);
          const sim = await this.simulations.simulate(userId, 'gasto', { monto, ...(cat ? { categoria_id: cat } : {}) });
          return { content: fold(this.fromSimulation(sim, 'simular_gasto', {})) };
        }
        case 'simulate_saving': {
          const monto = num(input.monto_objetivo);
          const meses = num(input.plazo_meses);
          if (!monto || !meses || monto <= 0 || meses < 1) return { content: 'Se necesita un monto y un plazo en meses válidos.', isError: true };
          const sim = await this.simulations.simulate(userId, 'ahorro_meta', {
            monto_objetivo: monto,
            fecha_limite: DateUtils.addMonths(DateRules.todayIn(env.TIMEZONE), Math.round(meses)),
          });
          return { content: fold(this.fromSimulation(sim, 'ahorro_meta', {})) };
        }
        case 'simulate_installments': {
          const monto = num(input.monto);
          const cuotas = num(input.num_cuotas);
          const tasa = num(input.tasa_anual);
          if (!monto || !cuotas || tasa === undefined || monto <= 0 || cuotas < 1 || tasa < 0) {
            return { content: 'Se necesitan monto, número de cuotas y tasa anual válidos.', isError: true };
          }
          const sim = await this.simulations.simulate(userId, 'compra_cuotas', { monto, num_cuotas: Math.round(cuotas), tasa_anual: tasa });
          return { content: fold(this.fromSimulation(sim, 'compra_cuotas', {})) };
        }
        case 'propose_transaction': {
          const monto = num(input.monto);
          if (!monto || monto <= 0) return { content: 'El monto debe ser un número mayor que cero.', isError: true };
          const tipo = input.tipo === 'ingreso' ? 'ingreso' : 'gasto';
          const r = await this.prepareTransaction(
            userId,
            { monto, tipo_transaccion: tipo, concepto: String(input.descripcion ?? ''), cuenta_texto: typeof input.cuenta === 'string' ? input.cuenta : undefined },
            String(input.descripcion ?? '')
          );
          const text = fold(r);
          return {
            content: r.estado?.pending_action
              ? `Propuesta pendiente de confirmación (aún NO se registró): ${r.estado.pending_action.resumen}. Pídele al usuario que responda "sí" o "no".`
              : text,
          };
        }
        default:
          return { content: `Herramienta desconocida: ${name}`, isError: true };
      }
    });

    let contenido = run.text || 'No pude generar una respuesta. Inténtalo de nuevo.';
    const usedSim = run.toolsUsed.some((t) => t.startsWith('simulate_'));
    if (usedSim && !/no garantiza/i.test(contenido)) contenido += `\n\n${DISCLAIMER}`;
    const tipo: ContentType = usedSim ? 'estimacion' : run.toolsUsed.length > 0 ? 'calculo' : /\d/.test(contenido) && !run.refused ? 'educativo' : null;
    return {
      contenido,
      tipo,
      cifras: figures,
      simulacion: simulation,
      estado: pending ? { pending_action: pending } : {},
      acciones: usedSim ? ['Guardar simulación', 'Ver supuestos'] : [],
      motor: this.llm!.name,
    };
  }

  private paramsFrom(p: ParsedMessage, message: string): Record<string, any> {
    const cat = CategorizationEngine.classify(message, 'gasto');
    return {
      monto: p.monto,
      num_cuotas: p.num_cuotas,
      plazo_meses: p.plazo_meses,
      tasa_anual: p.tasa_anual,
      periodo: p.periodo,
      categoria_id: cat.estado === 'categorizada' ? cat.categoria_id : undefined,
      tipo_transaccion: p.tipo_transaccion,
      concepto: p.concepto,
      tema: p.tema,
    };
  }

  /** Completa el dato que se había pedido con lo que respondió el usuario. */
  private fillSlot(state: State, parsed: ParsedMessage, message: string): Record<string, any> | null {
    const params = { ...(state.params ?? {}) };
    const slot = state.faltan![0];
    const bare = /^\s*\d+(?:[.,]\d+)?\s*(%|cuotas?|meses?)?\s*$/.test(norm(message));
    const num = Number(norm(message).replace(/[^0-9.,]/g, '').replace(',', '.'));
    if (slot === 'monto' && parsed.monto !== undefined) params.monto = parsed.monto;
    else if (slot === 'num_cuotas' && (parsed.num_cuotas !== undefined || (bare && num > 0))) params.num_cuotas = parsed.num_cuotas ?? Math.round(num);
    else if (slot === 'plazo_meses' && (parsed.plazo_meses !== undefined || (bare && num > 0))) params.plazo_meses = parsed.plazo_meses ?? Math.round(num);
    else if (slot === 'tasa_anual' && (parsed.tasa_anual !== undefined || (bare && num >= 0))) params.tasa_anual = parsed.tasa_anual ?? num;
    else if (slot === 'cuenta') params.cuenta_texto = message;
    else return null;
    return params;
  }

  private ask(intent: Intent, params: Record<string, any>, faltan: string[], intro: string): Reply {
    return {
      contenido: `${intro} ${ASK[faltan[0]]}`,
      tipo: null,
      estado: { intent, params, faltan },
    };
  }

  private async handle(userId: string, intent: Intent, params: Record<string, any>, parsed: ParsedMessage, message: string): Promise<Reply> {
    switch (intent) {
      case 'ayuda':
        return {
          contenido:
            'Soy el asistente financiero de NexoFin. Puedo: simular un gasto ("¿puedo gastar 5,000 en ropa?"), calcular cuánto ahorrar para una meta ("¿cuánto debo ahorrar para juntar 60,000 en 6 meses?"), simular una compra a cuotas, consultar tu saldo, tus gastos, deudas, presupuestos y metas, explicarte conceptos financieros y, con tu confirmación, registrar un gasto o ingreso.',
          tipo: 'educativo',
        };
      case 'fuera_ambito':
        return {
          contenido:
            'Solo puedo ayudarte con tus finanzas personales (gastos, ahorro, deudas, presupuestos y simulaciones). Esa consulta está fuera de mi ámbito y no realicé ninguna operación.',
          tipo: null,
        };
      case 'educativo':
        return { contenido: EDUCATION[parsed.tema ?? ''] ?? EDUCATION.presupuesto, tipo: 'educativo' };
      case 'desconocida':
        if (parsed.modifica_datos) {
          return {
            contenido:
              'Por defecto solo consulto tus datos y no creo, modifico ni elimino nada desde el chat. Para registrar un gasto o ingreso dímelo así: "registra un gasto de 500 en comida" y te pediré confirmación. Para otros cambios usa las pantallas de la app.',
            tipo: null,
          };
        }
        return {
          contenido: 'No estoy seguro de haber entendido. Prueba con: "¿cuánto tengo?", "¿cuánto gasté este mes?" o "¿puedo gastar 5,000 en ropa?".',
          tipo: null,
        };
      case 'simular_gasto': {
        if (params.monto === undefined) return this.ask(intent, params, ['monto'], 'Puedo simularlo.');
        const sim = await this.simulations.simulate(userId, 'gasto', {
          monto: params.monto,
          ...(params.categoria_id ? { categoria_id: params.categoria_id } : {}),
        });
        return this.fromSimulation(sim, intent, params);
      }
      case 'ahorro_meta': {
        const faltan = ['monto', 'plazo_meses'].filter((k) => params[k] === undefined);
        if (faltan.length > 0) return this.ask(intent, params, faltan, 'Puedo calcularlo.');
        const hoy = DateRules.todayIn(env.TIMEZONE);
        const sim = await this.simulations.simulate(userId, 'ahorro_meta', {
          monto_objetivo: params.monto,
          fecha_limite: DateUtils.addMonths(hoy, params.plazo_meses),
        });
        return this.fromSimulation(sim, intent, params);
      }
      case 'compra_cuotas': {
        const faltan = ['monto', 'num_cuotas', 'tasa_anual'].filter((k) => params[k] === undefined);
        if (faltan.length > 0) return this.ask(intent, params, faltan, 'Puedo simular esa compra a cuotas.');
        const sim = await this.simulations.simulate(userId, 'compra_cuotas', {
          monto: params.monto,
          tasa_anual: params.tasa_anual,
          num_cuotas: params.num_cuotas,
        });
        return this.fromSimulation(sim, intent, params);
      }
      case 'registrar_transaccion':
        return this.prepareTransaction(userId, params, message);
      default:
        return this.query(userId, intent, params.periodo ?? parsed.periodo, params.categoria_id, message);
    }
  }

  // ---- Simulaciones ----------------------------------------------------------------------------------------

  private fromSimulation(sim: StoredSimulation, intent: Intent, params: Record<string, any>): Reply {
    const r = sim.resultado.resultado as Record<string, any>;
    const lines: string[] = [sim.resultado.resumen];
    const cifras: Figure[] = [];
    const origenSim = `Motor de simulación · simulación ${sim.id.slice(0, 8)}`;

    if (sim.concluyente) {
      if (sim.tipo === 'gasto') {
        cifras.push(
          { etiqueta: 'Saldo libre antes', valor: r.saldo_libre_antes, origen: `${origenSim}: saldo disponible + ingresos proyectados − gastos proyectados − compromiso de metas` },
          { etiqueta: 'Saldo libre después', valor: r.saldo_libre_despues, origen: origenSim }
        );
        if (r.efecto_presupuesto) {
          const e = r.efecto_presupuesto;
          lines.push(`En tu presupuesto de ${e.categoria} pasarías de ${e.porcentaje_antes}% a ${e.porcentaje_despues}% (límite ${money(e.limite)}).`);
          cifras.push({ etiqueta: 'Presupuesto consumido después', valor: `${e.porcentaje_despues}%`, origen: 'Presupuesto del mes y transacciones registradas' });
        }
        if (r.compromete_metas) lines.push('⚠️ Este gasto comprometería tus aportes a metas de ahorro.');
        if (r.obligaciones_proximas?.length) {
          lines.push(`Antes de fin del periodo tienes ${r.obligaciones_proximas.length} obligación(es) programada(s).`);
        }
      } else if (sim.tipo === 'ahorro_meta') {
        cifras.push(
          { etiqueta: 'Ahorro mensual requerido', valor: r.ahorro_mensual_requerido, origen: `${origenSim}: (objetivo − acumulado) ÷ meses` },
          { etiqueta: 'Capacidad mensual de ahorro', valor: r.capacidad_mensual_ahorro, origen: 'Ingresos − gastos promedio − compromisos de metas' }
        );
      } else {
        cifras.push(
          { etiqueta: 'Cuota mensual', valor: r.cuota_mensual, origen: `${origenSim}: sistema francés (cuota fija)` },
          { etiqueta: 'Costo total', valor: r.costo_total, origen: origenSim },
          { etiqueta: 'Intereses pagados', valor: r.intereses_pagados, origen: origenSim }
        );
        lines.push(`Costo total: ${money(r.costo_total)}, de los cuales ${money(r.intereses_pagados)} son intereses.`);
      }
      for (const a of sim.resultado.alternativas) lines.push(`• ${a.descripcion}`);
    } else {
      lines.push('Por eso no te doy una cifra como exacta.');
      if (sim.tipo === 'compra_cuotas') {
        cifras.push({ etiqueta: 'Cuota mensual', valor: r.cuota_mensual, origen: `${origenSim}: sistema francés (cuota fija)` });
      }
    }
    lines.push(DISCLAIMER);
    return {
      contenido: lines.join('\n'),
      tipo: 'estimacion',
      cifras,
      simulacion: sim,
      acciones: ['Guardar simulación', 'Ver supuestos'],
      estado: { intent, params },
    };
  }

  // ---- Consultas de datos ---------------------------------------------------------------------------------------

  private range(p: Periodo | undefined): { desde: string; hasta: string; etiqueta: string } {
    const hoy = DateRules.todayIn(env.TIMEZONE);
    switch (p) {
      case 'hoy':
        return { desde: hoy, hasta: hoy, etiqueta: 'hoy' };
      case 'semana':
        return { desde: DateUtils.addDays(hoy, -6), hasta: hoy, etiqueta: 'los últimos 7 días' };
      case 'mes_pasado': {
        const prev = DateUtils.addMonths(DateUtils.monthStart(hoy), -1);
        return { desde: prev, hasta: DateUtils.monthEnd(prev), etiqueta: 'el mes pasado' };
      }
      case 'anio':
        return { desde: `${hoy.slice(0, 4)}-01-01`, hasta: hoy, etiqueta: 'este año' };
      default:
        return { desde: DateUtils.monthStart(hoy), hasta: hoy, etiqueta: 'este mes' };
    }
  }

  private async query(userId: string, intent: Intent, periodo: Periodo | undefined, categoriaId: string | undefined, message: string): Promise<Reply> {
    switch (intent) {
      case 'saldo': {
        const res = await db.query<any>(
          `SELECT c.nombre, c.tipo, COALESCE(v.saldo_actual, c.saldo_inicial) AS saldo FROM cuenta c
           LEFT JOIN vista_saldo_cuenta v ON v.cuenta_id = c.id WHERE c.usuario_id = $1 AND c.archivada = FALSE ORDER BY c.creada_en`,
          [userId]
        );
        if (res.rowCount === 0) return { contenido: 'Aún no tienes cuentas registradas.', tipo: null };
        const normales = res.rows.filter((r) => r.tipo !== 'tarjeta');
        const tarjetas = res.rows.filter((r) => r.tipo === 'tarjeta');
        const disponible = r2(normales.reduce((s, r) => s + Number(r.saldo), 0));
        const usado = r2(tarjetas.reduce((s, r) => s + Math.max(0, -Number(r.saldo)), 0));
        const lines = [`Tu saldo disponible es ${money(disponible)}.`];
        for (const c of normales) lines.push(`• ${c.nombre}: ${money(Number(c.saldo))}`);
        if (usado > 0) lines.push(`Además debes ${money(usado)} en tarjetas de crédito.`);
        return {
          contenido: lines.join('\n'),
          tipo: 'calculo',
          cifras: [
            { etiqueta: 'Saldo disponible', valor: disponible, origen: 'Suma de saldos de tus cuentas activas (sin tarjetas)' },
            ...(usado > 0 ? [{ etiqueta: 'Deuda en tarjetas', valor: usado, origen: 'Saldo negativo de tus tarjetas (RN-CTA-02)' }] : []),
          ],
        };
      }
      case 'gasto_periodo':
      case 'ingreso_periodo': {
        const tipo = intent === 'gasto_periodo' ? 'gasto' : 'ingreso';
        const { desde, hasta, etiqueta } = this.range(periodo);
        const params: any[] = [userId, tipo, desde, hasta];
        let extra = '';
        if (categoriaId && tipo === 'gasto') {
          params.push(categoriaId);
          extra = ' AND categoria_id = $5';
        }
        const tot = await db.query<any>(
          `SELECT COALESCE(SUM(monto), 0) AS total, COUNT(*)::text AS n FROM transaccion
           WHERE usuario_id = $1 AND tipo = $2 AND eliminada = FALSE AND fecha >= $3 AND fecha <= $4${extra}`,
          params
        );
        const total = r2(Number(tot.rows[0].total));
        const n = parseInt(tot.rows[0].n, 10);
        const lines = [
          n === 0
            ? `No tienes ${tipo === 'gasto' ? 'gastos' : 'ingresos'} registrados en ${etiqueta}.`
            : `${tipo === 'gasto' ? 'Gastaste' : 'Recibiste'} ${money(total)} en ${etiqueta} (${n} transacciones).`,
        ];
        if (tipo === 'gasto' && n > 0 && !categoriaId) {
          const top = await db.query<any>(
            `SELECT COALESCE(c.nombre, 'Sin categoría') AS nombre, SUM(t.monto) AS total FROM transaccion t
             LEFT JOIN categoria c ON c.id = t.categoria_id
             WHERE t.usuario_id = $1 AND t.tipo = 'gasto' AND t.eliminada = FALSE AND t.fecha >= $2 AND t.fecha <= $3
             GROUP BY c.nombre ORDER BY SUM(t.monto) DESC LIMIT 3`,
            [userId, desde, hasta]
          );
          for (const r of top.rows) lines.push(`• ${r.nombre}: ${money(Number(r.total))}`);
        }
        return {
          contenido: lines.join('\n'),
          tipo: 'calculo',
          cifras: [{ etiqueta: tipo === 'gasto' ? 'Total gastado' : 'Total recibido', valor: total, origen: `Suma de transacciones de tipo ${tipo} del ${desde} al ${hasta} (sin transferencias)` }],
        };
      }
      case 'deudas': {
        const list = (await this.debts.list(userId)).filter((d) => d.estado === 'activa');
        const cards = await db.query<any>(
          `SELECT c.nombre, COALESCE(v.saldo_actual, c.saldo_inicial) AS saldo FROM cuenta c
           LEFT JOIN vista_saldo_cuenta v ON v.cuenta_id = c.id WHERE c.usuario_id = $1 AND c.tipo = 'tarjeta' AND c.archivada = FALSE`,
          [userId]
        );
        const prestamos = r2(list.reduce((s, d) => s + d.saldo_pendiente, 0));
        const tarjetas = r2(cards.rows.reduce((s, c) => s + Math.max(0, -Number(c.saldo)), 0));
        if (prestamos + tarjetas === 0) return { contenido: 'No tienes deudas registradas. ¡Muy bien!', tipo: 'calculo' };
        const lines = [`Tu deuda total es ${money(r2(prestamos + tarjetas))}.`];
        for (const d of list) lines.push(`• ${d.acreedor}: ${money(d.saldo_pendiente)} pendientes (${d.cuotas_restantes} cuotas)`);
        if (tarjetas > 0) lines.push(`• Tarjetas de crédito: ${money(tarjetas)}`);
        return {
          contenido: lines.join('\n'),
          tipo: 'calculo',
          cifras: [
            { etiqueta: 'Deuda total', valor: r2(prestamos + tarjetas), origen: 'Saldo pendiente de tus deudas + saldo usado de tus tarjetas' },
          ],
        };
      }
      case 'presupuestos': {
        const hoy = DateRules.todayIn(env.TIMEZONE);
        const list = await this.budgets.list(userId, hoy.slice(0, 7));
        if (list.length === 0) return { contenido: 'No tienes presupuestos definidos este mes. Puedes crearlos en la sección Presupuestos.', tipo: null };
        const lines = ['Así vas con tus presupuestos de este mes:'];
        for (const b of list) lines.push(`• ${b.categoria_nombre}: ${money(b.consumido)} de ${money(b.monto_limite)} (${b.porcentaje}%)`);
        return {
          contenido: lines.join('\n'),
          tipo: 'calculo',
          cifras: list.map((b) => ({ etiqueta: `${b.categoria_nombre} consumido`, valor: `${b.porcentaje}%`, origen: 'Gastos del mes de la categoría ÷ límite del presupuesto' })),
        };
      }
      case 'metas': {
        const list = (await this.goals.list(userId)).filter((g) => g.estado === 'activa' || g.estado === 'alcanzada');
        if (list.length === 0) return { contenido: 'No tienes metas de ahorro. Puedes crear una en la sección Metas.', tipo: null };
        const lines = ['Tus metas de ahorro:'];
        for (const g of list) lines.push(`• ${g.nombre}: ${money(g.acumulado)} de ${money(g.monto_objetivo)} (${g.porcentaje}%) — necesitas ${money(g.monto_mensual_necesario)} al mes`);
        return {
          contenido: lines.join('\n'),
          tipo: 'calculo',
          cifras: list.map((g) => ({ etiqueta: `${g.nombre}: avance`, valor: `${g.porcentaje}%`, origen: 'Aportes registrados ÷ monto objetivo de la meta' })),
        };
      }
      default:
        return { contenido: 'No estoy seguro de haber entendido.', tipo: null };
    }
  }

  // ---- Registro de transacciones con confirmación (RF-ASI-06) --------------------------------------------------

  private async prepareTransaction(userId: string, params: Record<string, any>, message: string): Promise<Reply> {
    if (!this.createTransaction) {
      return { contenido: 'El registro de transacciones por chat no está disponible.', tipo: null };
    }
    if (params.monto === undefined) return this.ask('registrar_transaccion', params, ['monto'], 'Puedo registrarlo.');
    const accounts = await db.query<any>(
      `SELECT id, nombre, tipo FROM cuenta WHERE usuario_id = $1 AND archivada = FALSE ORDER BY creada_en`,
      [userId]
    );
    if (accounts.rowCount === 0) return { contenido: 'Primero crea una cuenta para poder registrar movimientos.', tipo: null };
    let cuenta = accounts.rows.length === 1 ? accounts.rows[0] : undefined;
    const hint = norm(params.cuenta_texto ?? message);
    cuenta = cuenta ?? accounts.rows.find((a: any) => hint.includes(norm(a.nombre)));
    if (!cuenta) {
      return {
        contenido: `¿En cuál de tus cuentas lo registro? Tienes: ${accounts.rows.map((a: any) => a.nombre).join(', ')}.`,
        tipo: null,
        estado: { intent: 'registrar_transaccion', params, faltan: ['cuenta'] },
      };
    }
    const tipo = (params.tipo_transaccion as 'gasto' | 'ingreso') ?? 'gasto';
    const descripcion = (params.concepto ?? message)
      .replace(/\d[\d.,]*\s*(mil|k)?/gi, '')
      .replace(/\b(rd\$?|pesos|un|una|de|en|por|el|la)\b/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 60);
    const fecha = DateRules.todayIn(env.TIMEZONE);
    const datos = { cuenta_id: cuenta.id, tipo, monto: params.monto, fecha, descripcion: descripcion || (tipo === 'gasto' ? 'Gasto' : 'Ingreso') };
    const resumen = `${tipo === 'gasto' ? 'Gasto' : 'Ingreso'} de ${money(params.monto)} en ${cuenta.nombre}, fecha ${fecha}, descripción "${datos.descripcion}"`;
    return {
      contenido: `Voy a registrar: ${resumen}.\n¿Confirmas? Responde "sí" para guardarlo o "no" para cancelar.`,
      tipo: null,
      cifras: [{ etiqueta: 'Monto a registrar', valor: params.monto, origen: 'Monto indicado por ti en el mensaje' }],
      estado: { pending_action: { tipo: 'crear_transaccion', datos, resumen } },
    };
  }

  private async executePending(userId: string, action: NonNullable<State['pending_action']>): Promise<Reply> {
    const created = await this.createTransaction!.createTransaction(userId, action.datos as any);
    return {
      contenido: `Listo, registré: ${action.resumen}.`,
      tipo: 'calculo',
      cifras: [{ etiqueta: 'Transacción registrada', valor: created.monto, origen: `Transacción ${created.id.slice(0, 8)} creada con tu confirmación` }],
    };
  }
}
