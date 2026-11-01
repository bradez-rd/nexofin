import { FinancialCalculator } from './FinancialCalculator.js';
import { LoanCalculator } from './LoanCalculator.js';
import { RecurrenceRules, Frequency } from './RecurrenceRules.js';
import { DateUtils } from './DateUtils.js';
import { ValidationError } from '../errors/DomainError.js';

const r2 = (n: number) => FinancialCalculator.roundMoney(n);

export interface RecurringItem {
  descripcion: string;
  monto: number;
  frecuencia: Frequency;
  fecha_inicio: string;
  fecha_fin: string | null;
}

export interface FinancialSnapshot {
  hoy: string;
  moneda: string;
  saldo_disponible: number;
  deuda_tarjetas: number;
  deuda_prestamos: number;
  num_cuentas: number;
  num_transacciones_90d: number;
  ingresos_promedio_mensual_90d: number;
  gasto_promedio_mensual_90d: number;
  recurrentes_ingreso: RecurringItem[];
  recurrentes_gasto: RecurringItem[];
  cuotas_pendientes: { vencimiento: string; monto: number; acreedor: string }[];
  metas: { id: string; nombre: string; monto_mensual_necesario: number }[];
  presupuestos: { categoria_id: string; categoria_nombre: string; mes: string; monto_limite: number; consumido: number }[];
  gasto_por_categoria_90d: { categoria_id: string; nombre: string; promedio_mensual: number }[];
}

export interface Projection {
  desde: string;
  hasta: string;
  dias: number;
  ingresos: number;
  gastos_fijos: number;
  cuotas_deuda: number;
  gasto_variable_estimado: number;
  gastos_total: number;
  compromiso_metas: number;
  obligaciones: { fecha: string; descripcion: string; monto: number }[];
  fuente_ingresos: 'recurrentes' | 'historial' | 'ninguna';
}

export interface Sufficiency {
  suficientes: boolean;
  faltantes: string[];
}

export interface SimulationResult {
  tipo: 'gasto' | 'ahorro_meta' | 'compra_cuotas';
  concluyente: boolean;
  faltantes: string[];
  resumen: string;
  supuestos: Record<string, unknown>;
  resultado: Record<string, unknown>;
  alternativas: { tipo: string; descripcion: string; efecto: Record<string, number | string | null> }[];
  aviso: string;
}

export const DISCLAIMER =
  'Esta simulación es una estimación basada en tus datos registrados. No garantiza resultados futuros ni sustituye la asesoría de un profesional financiero regulado.';

/** Motor determinístico de simulación (RF-SIM-01 a 08). Sin acceso a datos: opera sobre un snapshot. */
export class SimulationEngine {
  public static readonly MIN_TRANSACTIONS = 5;

  public static sufficiency(s: FinancialSnapshot): Sufficiency {
    const faltantes: string[] = [];
    if (s.num_cuentas < 1) faltantes.push('Registra al menos una cuenta activa');
    if (s.num_transacciones_90d < this.MIN_TRANSACTIONS) {
      faltantes.push(
        `Registra al menos ${this.MIN_TRANSACTIONS} transacciones de los últimos 90 días (tienes ${s.num_transacciones_90d})`
      );
    }
    if (s.recurrentes_ingreso.length === 0 && s.ingresos_promedio_mensual_90d <= 0) {
      faltantes.push('Registra tus ingresos (una nómina recurrente o al menos un ingreso reciente)');
    }
    return { suficientes: faltantes.length === 0, faltantes };
  }

  public static horizonEnd(hoy: string, horizonteMeses?: number): string {
    if (horizonteMeses === undefined) return DateUtils.monthEnd(hoy);
    if (!Number.isInteger(horizonteMeses) || horizonteMeses < 1 || horizonteMeses > 12) {
      throw new ValidationError('El horizonte debe ser de 1 a 12 meses');
    }
    return DateUtils.monthEnd(DateUtils.addMonths(hoy, horizonteMeses - 1));
  }

  /** Proyección de ingresos y obligaciones en el intervalo (desde, hasta]. */
  public static project(s: FinancialSnapshot, desde: string, hasta: string): Projection {
    const dias = Math.max(0, DateUtils.diffDays(desde, hasta));
    const obligaciones: Projection['obligaciones'] = [];
    let ingresos = 0;
    for (const r of s.recurrentes_ingreso) {
      ingresos += RecurrenceRules.between(r.fecha_inicio, r.frecuencia, desde, hasta, r.fecha_fin).length * r.monto;
    }
    let fuente: Projection['fuente_ingresos'] = s.recurrentes_ingreso.length > 0 ? 'recurrentes' : 'ninguna';
    if (s.recurrentes_ingreso.length === 0 && s.ingresos_promedio_mensual_90d > 0) {
      ingresos = (s.ingresos_promedio_mensual_90d * dias) / 30;
      fuente = 'historial';
    }

    let fijos = 0;
    for (const r of s.recurrentes_gasto) {
      for (const f of RecurrenceRules.between(r.fecha_inicio, r.frecuencia, desde, hasta, r.fecha_fin)) {
        fijos += r.monto;
        obligaciones.push({ fecha: f, descripcion: r.descripcion, monto: r.monto });
      }
    }
    let cuotas = 0;
    for (const c of s.cuotas_pendientes) {
      if (c.vencimiento > desde && c.vencimiento <= hasta) {
        cuotas += c.monto;
        obligaciones.push({ fecha: c.vencimiento, descripcion: `Cuota · ${c.acreedor}`, monto: c.monto });
      }
    }
    const comprometido = fijos + cuotas;
    const variableTotal = (s.gasto_promedio_mensual_90d * dias) / 30;
    const variable = Math.max(0, variableTotal - fijos);
    const metas = (s.metas.reduce((t, m) => t + m.monto_mensual_necesario, 0) * dias) / 30;

    return {
      desde,
      hasta,
      dias,
      ingresos: r2(ingresos),
      gastos_fijos: r2(fijos),
      cuotas_deuda: r2(cuotas),
      gasto_variable_estimado: r2(variable),
      gastos_total: r2(comprometido + variable),
      compromiso_metas: r2(metas),
      obligaciones: obligaciones.sort((a, b) => a.fecha.localeCompare(b.fecha)),
      fuente_ingresos: fuente,
    };
  }

  /** Saldo libre = disponible + ingresos − gastos proyectados − compromiso con metas. */
  public static freeBalance(s: FinancialSnapshot, p: Projection): { proyectado: number; libre: number } {
    const proyectado = r2(s.saldo_disponible + p.ingresos - p.gastos_total);
    return { proyectado, libre: r2(proyectado - p.compromiso_metas) };
  }

  /** Capacidad mensual de ahorro: ingresos menos el mayor entre gasto histórico y compromisos. */
  public static monthlyCapacity(s: FinancialSnapshot): number {
    const ingresos =
      s.recurrentes_ingreso.length > 0
        ? s.recurrentes_ingreso.reduce((t, r) => t + RecurrenceRules.monthlyEquivalent(r.monto, r.frecuencia), 0)
        : s.ingresos_promedio_mensual_90d;
    const fijos = s.recurrentes_gasto.reduce((t, r) => t + RecurrenceRules.monthlyEquivalent(r.monto, r.frecuencia), 0);
    const cuota = s.cuotas_pendientes.length > 0 ? Math.max(...this.monthlyInstallments(s)) : 0;
    const gasto = Math.max(s.gasto_promedio_mensual_90d, fijos + cuota);
    const metas = s.metas.reduce((t, m) => t + m.monto_mensual_necesario, 0);
    return r2(ingresos - gasto - metas);
  }

  private static monthlyInstallments(s: FinancialSnapshot): number[] {
    const byMonth = new Map<string, number>();
    for (const c of s.cuotas_pendientes) {
      const k = c.vencimiento.slice(0, 7);
      byMonth.set(k, (byMonth.get(k) ?? 0) + c.monto);
    }
    return [...byMonth.values()];
  }

  // ---- Escenario 1: gasto hipotético (RF-SIM-01/04/05/06) ----------------------------------------

  public static simulateExpense(
    s: FinancialSnapshot,
    p: { monto: number; categoria_id?: string | null; fecha?: string; horizonte_meses?: number }
  ): SimulationResult {
    if (!(p.monto > 0)) throw new ValidationError('El monto del gasto debe ser mayor que cero');
    const suf = this.sufficiency(s);
    const fecha = p.fecha ?? s.hoy;
    if (fecha < s.hoy) throw new ValidationError('La fecha aproximada del gasto no puede ser pasada');
    const fin = this.horizonEnd(s.hoy, p.horizonte_meses);
    if (fecha > fin) throw new ValidationError('La fecha del gasto cae fuera del horizonte de la simulación');
    const monto = r2(p.monto);

    const proy = this.project(s, s.hoy, fin);
    const antes = this.freeBalance(s, proy);
    const despues = { proyectado: r2(antes.proyectado - monto), libre: r2(antes.libre - monto) };

    const mesGasto = fecha.slice(0, 7);
    const presup = s.presupuestos.find((b) => b.categoria_id === p.categoria_id && b.mes === mesGasto) ?? null;
    const efectoPresupuesto = presup
      ? {
          categoria: presup.categoria_nombre,
          limite: presup.monto_limite,
          consumido_antes: presup.consumido,
          consumido_despues: r2(presup.consumido + monto),
          porcentaje_antes: Math.round((presup.consumido / presup.monto_limite) * 1000) / 10,
          porcentaje_despues: Math.round(((presup.consumido + monto) / presup.monto_limite) * 1000) / 10,
          supera_presupuesto: presup.consumido + monto > presup.monto_limite,
        }
      : null;

    const comprometeMetas = proy.compromiso_metas > 0 && despues.proyectado < proy.compromiso_metas;
    const negativo = despues.libre < 0;
    const superaPresupuesto = Boolean(efectoPresupuesto?.supera_presupuesto);

    const alternativas: SimulationResult['alternativas'] = [];
    if (negativo || superaPresupuesto || comprometeMetas) {
      const maximo = Math.max(0, r2(antes.libre));
      alternativas.push({
        tipo: 'reducir_monto',
        descripcion: `Reduce el gasto a RD$ ${maximo.toFixed(2)} para no comprometer tu saldo libre ni tus metas`,
        efecto: { monto_sugerido: maximo, saldo_libre_despues: r2(antes.libre - maximo) },
      });
      const siguiente = this.project(s, s.hoy, DateUtils.monthEnd(DateUtils.addMonths(fin, 1)));
      const sig = this.freeBalance(s, siguiente);
      alternativas.push({
        tipo: 'posponer',
        descripcion: 'Pospón el gasto un mes: ya habrás recibido más ingresos y pagado tus obligaciones',
        efecto: { saldo_libre_al_cierre_siguiente_mes: r2(sig.libre - monto), mejora: r2(sig.libre - monto - despues.libre) },
      });
      const recorte = [...s.gasto_por_categoria_90d]
        .filter((c) => c.categoria_id !== p.categoria_id)
        .sort((a, b) => b.promedio_mensual - a.promedio_mensual)[0];
      if (recorte && recorte.promedio_mensual > 0) {
        const ahorro = r2(recorte.promedio_mensual * 0.2);
        alternativas.push({
          tipo: 'recortar_categoria',
          descripcion: `Recorta 20 % de ${recorte.nombre} (promedio RD$ ${recorte.promedio_mensual.toFixed(2)} al mes)`,
          efecto: { categoria: recorte.nombre, ahorro_mensual: ahorro, saldo_libre_despues: r2(despues.libre + ahorro) },
        });
      }
      alternativas.push({
        tipo: 'redistribuir_mes',
        descripcion: 'Distribuye el gasto en dos pagos para suavizar el flujo del mes',
        efecto: { pago_1: r2(monto / 2), pago_2: r2(monto - r2(monto / 2)) },
      });
    }

    const concluyente = suf.suficientes;
    const resumen = !concluyente
      ? 'No hay datos suficientes para simular con confianza: ' + suf.faltantes.join('; ') + '.'
      : negativo
        ? `Con este gasto tu saldo libre quedaría en RD$ ${despues.libre.toFixed(2)} al ${fin}.`
        : `Con este gasto tu saldo libre pasaría de RD$ ${antes.libre.toFixed(2)} a RD$ ${despues.libre.toFixed(2)} al ${fin}.`;

    return {
      tipo: 'gasto',
      concluyente,
      faltantes: suf.faltantes,
      resumen,
      supuestos: this.assumptions(s, proy, { monto, fecha, horizonte_hasta: fin }),
      resultado: concluyente
        ? {
            saldo_libre_antes: antes.libre,
            saldo_libre_despues: despues.libre,
            saldo_proyectado_antes: antes.proyectado,
            saldo_proyectado_despues: despues.proyectado,
            efecto_presupuesto: efectoPresupuesto,
            compromete_metas: comprometeMetas,
            compromiso_metas: proy.compromiso_metas,
            obligaciones_proximas: proy.obligaciones,
            saldo_negativo: negativo,
          }
        : { efecto_presupuesto: efectoPresupuesto, obligaciones_proximas: proy.obligaciones },
      alternativas: concluyente ? alternativas : [],
      aviso: DISCLAIMER,
    };
  }

  // ---- Escenario 2: ahorro para una meta (RF-SIM-02) ----------------------------------------------

  public static simulateSaving(
    s: FinancialSnapshot,
    p: { monto_objetivo: number; fecha_limite: string; acumulado_actual?: number }
  ): SimulationResult {
    if (!(p.monto_objetivo > 0)) throw new ValidationError('El monto objetivo debe ser mayor que cero');
    if (p.fecha_limite <= s.hoy) throw new ValidationError('La fecha límite debe ser posterior a hoy');
    const acumulado = r2(p.acumulado_actual ?? 0);
    const faltante = Math.max(0, r2(p.monto_objetivo - acumulado));
    const meses = DateUtils.monthsBetween(s.hoy, p.fecha_limite);
    const requerido = r2(faltante / meses);
    const suf = this.sufficiency(s);
    const capacidad = this.monthlyCapacity(s);
    const viable = capacidad >= requerido;

    const alternativas: SimulationResult['alternativas'] = [];
    if (suf.suficientes && !viable) {
      if (capacidad > 0) {
        const mesesNec = Math.ceil(faltante / capacidad);
        alternativas.push({
          tipo: 'extender_plazo',
          descripcion: `Extiende el plazo a ${mesesNec} meses (${DateUtils.addMonths(s.hoy, mesesNec)}) para ahorrar RD$ ${r2(faltante / mesesNec).toFixed(2)} al mes`,
          efecto: { meses_necesarios: mesesNec, aporte_mensual: r2(faltante / mesesNec) },
        });
        alternativas.push({
          tipo: 'reducir_objetivo',
          descripcion: `Con tu capacidad actual alcanzarías RD$ ${r2(capacidad * meses + acumulado).toFixed(2)} en el plazo`,
          efecto: { objetivo_alcanzable: r2(capacidad * meses + acumulado) },
        });
      } else {
        alternativas.push({
          tipo: 'liberar_flujo',
          descripcion: 'Tus gastos actuales superan tus ingresos: primero necesitas liberar flujo mensual',
          efecto: { deficit_mensual: r2(-capacidad) },
        });
      }
    }
    const concluyente = suf.suficientes;
    return {
      tipo: 'ahorro_meta',
      concluyente,
      faltantes: suf.faltantes,
      resumen: !concluyente
        ? 'No hay datos suficientes para evaluar si el ahorro es viable: ' + suf.faltantes.join('; ') + '.'
        : viable
          ? `Necesitas ahorrar RD$ ${requerido.toFixed(2)} al mes durante ${meses} meses y es viable con tu capacidad actual.`
          : `Necesitas ahorrar RD$ ${requerido.toFixed(2)} al mes, pero tu capacidad actual es de RD$ ${capacidad.toFixed(2)}.`,
      supuestos: {
        ...this.assumptions(s, this.project(s, s.hoy, DateUtils.monthEnd(s.hoy)), {}),
        monto_objetivo: r2(p.monto_objetivo),
        acumulado_actual: acumulado,
        fecha_limite: p.fecha_limite,
        meses,
      },
      resultado: {
        faltante,
        meses,
        ahorro_mensual_requerido: requerido,
        ...(concluyente ? { capacidad_mensual_ahorro: capacidad, viable } : {}),
      },
      alternativas,
      aviso: DISCLAIMER,
    };
  }

  // ---- Escenario 3: compra a cuotas (RF-SIM-03) ---------------------------------------------------

  public static simulateInstallments(
    s: FinancialSnapshot,
    p: { monto: number; tasa_anual: number; num_cuotas: number }
  ): SimulationResult {
    const resumen = LoanCalculator.summary(r2(p.monto), p.tasa_anual, p.num_cuotas);
    const suf = this.sufficiency(s);
    const capacidad = this.monthlyCapacity(s);
    const capacidadDespues = r2(capacidad - resumen.cuota);
    const viable = capacidadDespues >= 0;

    const alternativas: SimulationResult['alternativas'] = [];
    if (suf.suficientes && !viable) {
      for (const n of [p.num_cuotas * 2, p.num_cuotas * 3].filter((x) => x <= 600)) {
        const alt = LoanCalculator.summary(r2(p.monto), p.tasa_anual, n);
        alternativas.push({
          tipo: 'mas_cuotas',
          descripcion: `A ${n} cuotas pagarías RD$ ${alt.cuota.toFixed(2)} al mes (intereses totales RD$ ${alt.total_intereses.toFixed(2)})`,
          efecto: { cuota: alt.cuota, intereses: alt.total_intereses, flujo_mensual_despues: r2(capacidad - alt.cuota) },
        });
      }
      alternativas.push({
        tipo: 'dar_inicial',
        descripcion: 'Da una inicial para bajar la cuota hasta que quepa en tu flujo mensual',
        efecto: { inicial_sugerida: r2(Math.max(0, p.monto - (capacidad > 0 ? (capacidad * p.num_cuotas) : 0))) },
      });
    }
    const concluyente = suf.suficientes;
    return {
      tipo: 'compra_cuotas',
      concluyente,
      faltantes: suf.faltantes,
      resumen: !concluyente
        ? `La cuota es RD$ ${resumen.cuota.toFixed(2)} al mes; no hay datos suficientes para medir el efecto en tu flujo: ${suf.faltantes.join('; ')}.`
        : viable
          ? `Pagarías RD$ ${resumen.cuota.toFixed(2)} al mes y tu flujo mensual seguiría positivo (RD$ ${capacidadDespues.toFixed(2)}).`
          : `Pagarías RD$ ${resumen.cuota.toFixed(2)} al mes y tu flujo mensual quedaría en RD$ ${capacidadDespues.toFixed(2)}.`,
      supuestos: { ...this.assumptions(s, this.project(s, s.hoy, DateUtils.monthEnd(s.hoy)), {}), monto: r2(p.monto), tasa_anual: p.tasa_anual, num_cuotas: p.num_cuotas },
      resultado: {
        cuota_mensual: resumen.cuota,
        costo_total: resumen.total_pagado,
        intereses_pagados: resumen.total_intereses,
        plazo_meses: p.num_cuotas,
        ...(concluyente ? { flujo_mensual_antes: capacidad, flujo_mensual_despues: capacidadDespues, viable } : {}),
      },
      alternativas,
      aviso: DISCLAIMER,
    };
  }

  private static assumptions(s: FinancialSnapshot, proy: Projection, extra: Record<string, unknown>): Record<string, unknown> {
    return {
      fecha_base: s.hoy,
      moneda: s.moneda,
      saldo_disponible: s.saldo_disponible,
      deuda_tarjetas: s.deuda_tarjetas,
      deuda_prestamos: s.deuda_prestamos,
      periodo: { desde: proy.desde, hasta: proy.hasta, dias: proy.dias },
      fuente_ingresos: proy.fuente_ingresos,
      ingresos_proyectados: proy.ingresos,
      gastos_fijos_proyectados: proy.gastos_fijos,
      cuotas_de_deuda: proy.cuotas_deuda,
      gasto_variable_estimado: proy.gasto_variable_estimado,
      compromiso_metas: proy.compromiso_metas,
      metodo_gasto_variable: 'promedio mensual de los últimos 90 días menos los gastos fijos del periodo',
      ...extra,
    };
  }
}
