export interface CategoryRule {
  texto_contiene: string;
  categoria_id: string;
  prioridad: number;
}

export interface PastCorrection {
  descripcion_norm: string;
  categoria_id: string;
}

export interface Classification {
  categoria_id: string | null;
  confianza: number;
  origen: 'regla' | 'correccion' | 'palabra_clave' | 'ninguna';
  estado: 'categorizada' | 'pendiente_revision' | 'sin_categoria';
}

type Keyword = { words: string[]; categoria: string; weight: number };

const G = (n: string) => `b0000000-0000-4000-8000-0000000000${n}`;
const I = (n: string) => `a0000000-0000-4000-8000-0000000000${n}`;

/** Palabras clave por categoría del sistema (comercios y términos comunes en RD). */
const KEYWORDS: { tipo: 'ingreso' | 'gasto'; items: Keyword[] }[] = [
  {
    tipo: 'gasto',
    items: [
      { categoria: G('01'), weight: 0.85, words: ['renta', 'alquiler', 'hipoteca', 'condominio', 'mantenimiento del edificio'] },
      { categoria: G('02'), weight: 0.85, words: ['supermercado', 'colmado', 'nacional', 'jumbo', 'sirena', 'bravo', 'pola', 'plaza lama', 'restaurante', 'pizza', 'pollo', 'comida', 'cafeteria', 'mcdonald', 'burger', 'dominos', 'kfc', 'panaderia'] },
      { categoria: G('03'), weight: 0.85, words: ['gasolina', 'combustible', 'uber', 'taxi', 'peaje', 'parqueo', 'estacionamiento', 'texaco', 'shell', 'sunix', 'metro', 'omsa'] },
      { categoria: G('04'), weight: 0.85, words: ['edesur', 'edenorte', 'edeste', 'luz', 'agua', 'caasd', 'claro', 'altice', 'viva', 'internet', 'telefono', 'gas propano', 'cable', 'wind'] },
      { categoria: G('05'), weight: 0.85, words: ['farmacia', 'clinica', 'doctor', 'medico', 'hospital', 'laboratorio', 'seguro medico', 'senasa', 'carol', 'gbc'] },
      { categoria: G('06'), weight: 0.85, words: ['universidad', 'colegio', 'curso', 'libro', 'matricula', 'itla', 'udemy', 'academia', 'escuela'] },
      { categoria: G('07'), weight: 0.85, words: ['cine', 'netflix', 'spotify', 'disney', 'hbo', 'youtube premium', 'bar ', 'concierto', 'discoteca', 'steam', 'playstation', 'amazon prime'] },
      { categoria: G('08'), weight: 0.85, words: ['ropa', 'zapatos', 'salon', 'barberia', 'peluqueria', 'zara', 'tienda de ropa', 'perfume', 'spa'] },
      { categoria: G('09'), weight: 0.85, words: ['prestamo', 'cuota del prestamo', 'pago de tarjeta', 'financiamiento'] },
      { categoria: G('10'), weight: 0.85, words: ['ahorro', 'meta de ahorro'] },
      { categoria: G('11'), weight: 0.5, words: ['compra', 'pago', 'retiro', 'cargo', 'varios'] },
    ],
  },
  {
    tipo: 'ingreso',
    items: [
      { categoria: I('01'), weight: 0.85, words: ['nomina', 'salario', 'sueldo', 'quincena', 'pago de nomina'] },
      { categoria: I('02'), weight: 0.85, words: ['dividendo', 'intereses ganados', 'inversion', 'rendimiento', 'certificado'] },
      { categoria: I('03'), weight: 0.85, words: ['venta', 'cliente', 'factura cobrada', 'negocio', 'comision'] },
      { categoria: I('04'), weight: 0.8, words: ['transferencia recibida', 'te envio', 'deposito de'] },
      { categoria: I('05'), weight: 0.5, words: ['deposito', 'ingreso', 'otros'] },
    ],
  },
];

/**
 * Categorización determinística (RF-CAT-01/02/03/06). Orden de precedencia:
 * 1) reglas del usuario, 2) correcciones manuales previas con la misma descripción,
 * 3) palabras clave. Si la confianza queda bajo el umbral, la transacción pasa a la bandeja
 * de revisión sin categoría; si nada coincide queda "Sin categoría". Nunca se adivina.
 */
export class CategorizationEngine {
  public static readonly DEFAULT_THRESHOLD = 0.6;

  public static normalize(text: string): string {
    return text
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .toLowerCase()
      .replace(/\s+/g, ' ')
      .trim();
  }

  public static classify(
    descripcion: string | null | undefined,
    tipo: 'ingreso' | 'gasto',
    rules: CategoryRule[] = [],
    corrections: PastCorrection[] = [],
    threshold: number = CategorizationEngine.DEFAULT_THRESHOLD
  ): Classification {
    const text = this.normalize(descripcion || '');
    if (!text) return { categoria_id: null, confianza: 0, origen: 'ninguna', estado: 'sin_categoria' };

    const sortedRules = [...rules].sort((a, b) => b.prioridad - a.prioridad);
    for (const r of sortedRules) {
      if (text.includes(this.normalize(r.texto_contiene))) {
        return { categoria_id: r.categoria_id, confianza: 1, origen: 'regla', estado: 'categorizada' };
      }
    }

    const past = corrections.find((c) => c.descripcion_norm === text);
    if (past) {
      return { categoria_id: past.categoria_id, confianza: 0.95, origen: 'correccion', estado: 'categorizada' };
    }

    const group = KEYWORDS.find((g) => g.tipo === tipo)!;
    let best: { categoria: string; weight: number; len: number } | null = null;
    for (const item of group.items) {
      for (const w of item.words) {
        const word = this.normalize(w);
        const re = new RegExp(`(^|[^a-z0-9])${word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').trim()}($|[^a-z0-9])`);
        if (re.test(text) && (!best || item.weight > best.weight || (item.weight === best.weight && word.length > best.len))) {
          best = { categoria: item.categoria, weight: item.weight, len: word.length };
        }
      }
    }
    if (!best) return { categoria_id: null, confianza: 0, origen: 'ninguna', estado: 'sin_categoria' };
    if (best.weight < threshold) {
      return { categoria_id: null, confianza: best.weight, origen: 'palabra_clave', estado: 'pendiente_revision' };
    }
    return { categoria_id: best.categoria, confianza: best.weight, origen: 'palabra_clave', estado: 'categorizada' };
  }
}
