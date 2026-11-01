/**
 * Comprensión del lenguaje natural del asistente (RF-ASI-01/03/07/08). Es determinística: no usa
 * un modelo generativo para calcular nada, solo identifica la intención y extrae parámetros que
 * luego ejecuta el motor financiero. Así ninguna cifra de una respuesta carece de origen.
 */

export type Intent =
  | 'simular_gasto'
  | 'ahorro_meta'
  | 'compra_cuotas'
  | 'saldo'
  | 'gasto_periodo'
  | 'ingreso_periodo'
  | 'deudas'
  | 'presupuestos'
  | 'metas'
  | 'registrar_transaccion'
  | 'educativo'
  | 'ayuda'
  | 'fuera_ambito'
  | 'desconocida';

export type Periodo = 'hoy' | 'semana' | 'mes' | 'mes_pasado' | 'anio';

export interface ParsedMessage {
  intent: Intent;
  monto?: number;
  num_cuotas?: number;
  plazo_meses?: number;
  tasa_anual?: number;
  periodo?: Periodo;
  texto_normalizado: string;
  tipo_transaccion?: 'gasto' | 'ingreso';
  concepto?: string;
  tema?: string;
  cancelar?: boolean;
  confirmar?: boolean;
  modifica_datos?: boolean;
}

export const norm = (t: string) =>
  t
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();

const FINANCE_WORDS = [
  'gast', 'ahorr', 'dinero', 'saldo', 'cuenta', 'tarjeta', 'presupuesto', 'meta', 'deuda', 'debo', 'prestamo',
  'cuota', 'ingres', 'sueldo', 'salario', 'compr', 'pagar', 'pago', 'interes', 'balance', 'banco', 'financ',
  'efectivo', 'transferencia', 'plata', 'pesos', 'rd$', 'inversion', 'credito', 'cobr', 'nomina', 'tengo',
  'alcanza', 'cuanto', 'finanzas', 'quincena', 'factura', 'renta',
];

const OFF_TOPIC = [
  'clima', 'receta', 'chiste', 'futbol', 'beisbol', 'pelicula', 'cancion', 'politic', 'presidente', 'horoscopo',
  'programa en', 'codigo', 'traduce', 'poema', 'historia de', 'capital de', 'quien gano', 'novia', 'tarea de',
  'ecuacion', 'hackea', 'contrasena de', 'password de',
];

const MUTATING = /\b(elimina|borra|borrar|eliminar|modifica|modificar|cambia|cambiar|edita|editar|transfiere|transferir|crea|crear|cierra|archiva|archivar)\b/;
const REGISTER = /\b(registra|registrar|anota|anotar|agrega|agregar|apunta|apuntar|guarda|guardar)\b.*\b(gasto|ingreso|pago|compra|cobro|deposito)\b|\b(gaste|pague|compre|cobre|recibi|me pagaron)\b.*\d/;

const TOPICS: { key: string; words: string[] }[] = [
  { key: 'interes', words: ['interes'] },
  { key: 'presupuesto', words: ['presupuesto'] },
  { key: 'tarjeta', words: ['tarjeta de credito', 'tarjeta'] },
  { key: 'ahorro', words: ['fondo de emergencia', 'ahorro', 'ahorrar'] },
  { key: 'deuda', words: ['deuda', 'prestamo'] },
  { key: 'inflacion', words: ['inflacion'] },
  { key: '503020', words: ['50/30/20', '50 30 20', 'regla 50'] },
  { key: 'cuota', words: ['amortizacion', 'cuota fija', 'cuotas'] },
  { key: 'tasa', words: ['tasa'] },
];

function parseNumberToken(raw: string): number {
  const s = raw.trim();
  if (/^\d{1,3}([.,]\d{3})+$/.test(s)) return Number(s.replace(/[.,]/g, ''));
  return Number(s.replace(',', '.'));
}

/** Extrae el primer monto que no sea un número de cuotas, meses, porcentaje, días o años. */
export function parseMoney(text: string): number | undefined {
  const t = norm(text);
  const re = /(\d{1,3}(?:[.,]\d{3})+|\d+(?:[.,]\d+)?)\s*(mil\b|k\b|millones\b|millon\b|m\b)?/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(t)) !== null) {
    const after = t.slice(m.index + m[0].length).trimStart();
    if (/^(%|por ciento|meses|mes\b|cuotas?|anos?|dias?|semanas?|veces)/.test(after)) continue;
    let value = parseNumberToken(m[1]);
    if (!Number.isFinite(value)) continue;
    const unit = m[2];
    if (unit === 'mil' || unit === 'k') value *= 1000;
    else if (unit && unit.startsWith('mill')) value *= 1_000_000;
    else if (unit === 'm') value *= 1_000_000;
    if (value > 0) return Math.round(value * 100) / 100;
  }
  return undefined;
}

function parseInstallments(t: string): number | undefined {
  const m = /(\d+)\s*(cuotas?|pagos)/.exec(t) ?? /en\s+(\d+)\s*meses/.exec(t);
  return m ? Number(m[1]) : undefined;
}

function parseMonths(t: string): number | undefined {
  const y = /(\d+)\s*anos?/.exec(t);
  if (y) return Number(y[1]) * 12;
  const m = /(\d+)\s*mes(?:es)?\b/.exec(t);
  return m ? Number(m[1]) : undefined;
}

function parseRate(t: string): number | undefined {
  const m = /(\d+(?:[.,]\d+)?)\s*(%|por ciento)/.exec(t);
  if (m) return Number(m[1].replace(',', '.'));
  if (/sin interes|interes 0|tasa 0|0 interes/.test(t)) return 0;
  return undefined;
}

function parsePeriod(t: string): Periodo | undefined {
  if (/mes pasado|mes anterior/.test(t)) return 'mes_pasado';
  if (/esta semana|semana/.test(t)) return 'semana';
  if (/\bhoy\b/.test(t)) return 'hoy';
  if (/este ano|en el ano|anual/.test(t)) return 'anio';
  if (/este mes|del mes|mensual|mes\b/.test(t)) return 'mes';
  return undefined;
}

export class AssistantEngine {
  public static parse(message: string): ParsedMessage {
    const t = norm(message);
    const base: ParsedMessage = {
      intent: 'desconocida',
      texto_normalizado: t,
      monto: parseMoney(message),
      num_cuotas: parseInstallments(t),
      plazo_meses: parseMonths(t),
      tasa_anual: parseRate(t),
      periodo: parsePeriod(t),
    };

    if (/^(si|sí|confirmo|confirmar|dale|ok|okay|adelante|hazlo|correcto|de acuerdo)\b/.test(t)) base.confirmar = true;
    if (/^(no|cancela|cancelar|olvidalo|dejalo|mejor no)\b/.test(t)) base.cancelar = true;
    if (base.confirmar || base.cancelar) return base;

    const hasFinance = FINANCE_WORDS.some((w) => t.includes(w));
    const off = OFF_TOPIC.some((w) => t.includes(w));
    if (off && !hasFinance) return { ...base, intent: 'fuera_ambito' };

    if (/^(hola|buenas|buenos dias|buenas tardes|buenas noches|ayuda|que puedes hacer|que haces|help)\b/.test(t)) {
      return { ...base, intent: 'ayuda' };
    }

    if (REGISTER.test(t) && /\d/.test(t)) {
      return {
        ...base,
        intent: 'registrar_transaccion',
        tipo_transaccion: /ingreso|cobro|cobre|recibi|me pagaron|deposito|sueldo|nomina/.test(t) ? 'ingreso' : 'gasto',
        concepto: message.replace(/^(registra|anota|agrega|apunta|guarda)\w*\s+(un|una)?\s*/i, '').trim(),
        modifica_datos: true,
      };
    }
    if (MUTATING.test(t)) return { ...base, intent: 'desconocida', modifica_datos: true };

    const edu = /(que es|que significa|como funciona|explica|explicame|para que sirve|en que consiste|diferencia entre)/.test(t);
    if (edu) {
      const topic = TOPICS.find((tp) => tp.words.some((w) => t.includes(w)));
      if (topic) return { ...base, intent: 'educativo', tema: topic.key };
    }

    if (/(a|en)\s+\d+\s*cuotas|financi|a cuotas|prestamo de|sacar un prestamo/.test(t) && /compr|financi|prestamo|pagar/.test(t)) {
      return { ...base, intent: 'compra_cuotas' };
    }
    if (/(cuanto|que monto|cuanta plata).*(ahorrar|apartar|guardar)|ahorrar.*para (llegar|juntar|alcanzar)|para (juntar|alcanzar|llegar a)/.test(t)) {
      return { ...base, intent: 'ahorro_meta' };
    }
    if (/(puedo|podria|me alcanza|alcanza para|que pasa si|que pasaria si|si (gasto|compro|pago)|afecta|me conviene)/.test(t) && /(gast|compr|pag|llev|invert|salir|viaj|cena|celular|laptop|ropa|\d)/.test(t)) {
      return { ...base, intent: 'simular_gasto' };
    }
    if (/(cuanto|cual|dime|muestrame|mi)\b.*\b(deb|deuda|prestamo)|^deudas?$|mis deudas|cuanto debo/.test(t)) {
      return { ...base, intent: 'deudas' };
    }
    if (/presupuesto/.test(t)) return { ...base, intent: 'presupuestos' };
    if (/\bmetas?\b|objetivo de ahorro/.test(t)) return { ...base, intent: 'metas' };
    if (/(cuanto|que|total).*(gaste|gasto|he gastado|gastado|gastos)|mis gastos|en que gaste|en que he gastado/.test(t)) {
      return { ...base, intent: 'gasto_periodo' };
    }
    if (/(cuanto|total).*(gane|ingres|cobre|recibi|entro)|mis ingresos/.test(t)) {
      return { ...base, intent: 'ingreso_periodo' };
    }
    if (/(cuanto (dinero )?tengo|saldo|balance|cuanto hay|disponible|mis cuentas|posicion)/.test(t)) {
      return { ...base, intent: 'saldo' };
    }
    if (!hasFinance && t.length > 3) return { ...base, intent: 'fuera_ambito' };
    return base;
  }
}

export const EDUCATION: Record<string, string> = {
  interes:
    'El interés es el costo de usar dinero prestado (o lo que ganas por prestarlo). En un préstamo se calcula sobre el saldo pendiente: a mayor tasa y plazo, más pagas en total.',
  presupuesto:
    'Un presupuesto es un plan de cuánto vas a gastar por categoría en un mes. Sirve para ver cuánto llevas consumido y recibir una alerta antes de pasarte del límite.',
  tarjeta:
    'La tarjeta de crédito te presta dinero a corto plazo. Si pagas el total antes de la fecha de pago normalmente no pagas intereses; si pagas solo una parte, el saldo restante genera intereses. En NexoFin una tarjeta es una cuenta con saldo negativo (lo que debes).',
  ahorro:
    'Un fondo de emergencia es un ahorro para imprevistos; una guía común es reunir de 3 a 6 meses de gastos básicos. Lo ideal es aportar un monto fijo cada mes, aunque sea pequeño.',
  deuda:
    'Una deuda es una obligación de pagar un monto en cuotas. Conviene priorizar las de mayor tasa de interés y evitar que las cuotas superen una parte razonable de tus ingresos mensuales.',
  inflacion:
    'La inflación es el aumento general de los precios: con el tiempo, el mismo dinero compra menos. Por eso conviene que tus ahorros crezcan al menos al ritmo de la inflación.',
  '503020':
    'La regla 50/30/20 sugiere destinar 50 % de tus ingresos a necesidades, 30 % a deseos y 20 % a ahorro o pago de deudas. Es solo una guía; ajústala a tu realidad.',
  cuota:
    'En un préstamo con cuota fija, cada pago incluye interés y capital. Al inicio la mayor parte de la cuota es interés y con el tiempo pesa más el capital (amortización).',
  tasa:
    'La tasa de interés anual indica cuánto cuesta el dinero prestado en un año. Para la cuota mensual se divide entre 12. Compara siempre la tasa y el costo total, no solo la cuota.',
};
