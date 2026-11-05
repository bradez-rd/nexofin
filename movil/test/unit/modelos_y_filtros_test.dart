import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexofin/core/theme/app_theme.dart';
import 'package:nexofin/core/utils/currency_formatter.dart';
import 'package:nexofin/core/utils/date_formatter.dart';
import 'package:nexofin/models/account_model.dart';
import 'package:nexofin/models/history_filter.dart';
import 'package:nexofin/models/transaction_model.dart';

double _luminance(Color c) {
  double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

/// Relación de contraste WCAG entre dos colores.
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('HistoryFilter (RF-TRX-05)', () {
    test('UT-F01 · toQuery solo envía los filtros activos y da formato AAAA-MM-DD a las fechas', () {
      final f = HistoryFilter(
        tipo: 'gasto',
        cuentaId: 'c-1',
        desde: DateTime(2026, 10, 1),
        hasta: DateTime(2026, 10, 26),
      );
      final q = f.toQuery(limit: 20, offset: 40);
      expect(q, {
        'limit': 20,
        'offset': 40,
        'tipo': 'gasto',
        'cuenta_id': 'c-1',
        'fecha_inicio': '2026-10-01',
        'fecha_fin': '2026-10-26',
      });
      expect(const HistoryFilter().toQuery(limit: 20), {'limit': 20, 'offset': 0});
    });

    test('UT-F02 · la búsqueda vacía no se envía y la no vacía sí', () {
      expect(const HistoryFilter(busqueda: '').toQuery(limit: 5).containsKey('busqueda'), false);
      expect(const HistoryFilter(busqueda: 'farmacia').toQuery(limit: 5)['busqueda'], 'farmacia');
    });

    test('UT-F03 · activeCount cuenta cuenta, categoría y rango de fechas; no el tipo ni la búsqueda', () {
      expect(const HistoryFilter(tipo: 'gasto', busqueda: 'x').activeCount, 0);
      expect(const HistoryFilter(cuentaId: 'c').activeCount, 1);
      expect(HistoryFilter(cuentaId: 'c', categoriaId: 'k', desde: DateTime(2026, 1, 1)).activeCount, 3);
      expect(HistoryFilter(desde: DateTime(2026, 1, 1), hasta: DateTime(2026, 1, 31)).activeCount, 1);
    });

    test('UT-F04 · copyWith permite quitar un valor con null y conserva el resto', () {
      final f = HistoryFilter(tipo: 'gasto', cuentaId: 'c-1');
      final sinTipo = f.copyWith(tipo: null);
      expect(sinTipo.tipo, isNull);
      expect(sinTipo.cuentaId, 'c-1');
      expect(f.copyWith(busqueda: 'x').tipo, 'gasto');
    });

    test('UT-F05 · clearAdvanced conserva el tipo y la búsqueda y borra el resto', () {
      final f = HistoryFilter(tipo: 'ingreso', busqueda: 'nomina', cuentaId: 'c', categoriaId: 'k', desde: DateTime(2026, 1, 1));
      final c = f.clearAdvanced();
      expect(c.tipo, 'ingreso');
      expect(c.busqueda, 'nomina');
      expect(c.activeCount, 0);
    });
  });

  group('Modelos y formato de la API (contrato)', () {
    test('UT-F06 · MonthlySummaryModel lee los nombres reales de la API (camelCase)', () {
      final s = MonthlySummaryModel.fromJson({'totalIngresos': 65000, 'totalGastos': 26550, 'balanceNeto': 38450});
      expect(s.ingresos, 65000);
      expect(s.gastos, 26550);
      expect(s.balanceNeto, 38450);
    });

    test('UT-F07 · BalanceSummaryModel lee total_saldo y cantidad_cuentas', () {
      final b = BalanceSummaryModel.fromJson({'moneda': 'DOP', 'total_saldo': 76900.5, 'cantidad_cuentas': 4});
      expect(b.patrimonioNeto, 76900.5);
      expect(b.totalCuentas, 4);
    });

    test('UT-F08 · AccountModel usa saldo_actual y cae a saldo_inicial si falta', () {
      expect(AccountModel.fromJson({'id': 'a', 'nombre': 'N', 'tipo': 'bancaria', 'saldo_inicial': 100, 'saldo_actual': 80.25}).saldoActual, 80.25);
      expect(AccountModel.fromJson({'id': 'a', 'nombre': 'N', 'tipo': 'bancaria', 'saldo_inicial': 100}).saldoActual, 100);
    });

    test('UT-F09 · TransactionModel distingue ingreso, gasto y transferencia', () {
      final ingreso = TransactionModel.fromJson({'id': 't', 'cuenta_id': 'c', 'tipo': 'ingreso', 'sentido': 'entrada', 'monto': 10, 'fecha': '2026-10-26'});
      final gasto = TransactionModel.fromJson({'id': 't', 'cuenta_id': 'c', 'tipo': 'gasto', 'sentido': 'salida', 'monto': 10, 'fecha': '2026-10-26'});
      final transf = TransactionModel.fromJson({'id': 't', 'cuenta_id': 'c', 'tipo': 'transferencia', 'sentido': 'salida', 'monto': 10, 'fecha': '2026-10-26', 'transferencia_vinculada_id': 'x'});
      expect(ingreso.isIncome && !ingreso.isTransfer, true);
      expect(!gasto.isIncome && !gasto.isTransfer, true);
      expect(transf.isTransfer, true);
    });

    test('UT-F10 · CurrencyFormatter muestra RD\$ con separador de miles y signo explícito', () {
      expect(CurrencyFormatter.format(1234567.5), 'RD\$ 1,234,567.50');
      expect(CurrencyFormatter.formatSigned(-850), '-RD\$ 850.00');
      expect(CurrencyFormatter.formatSigned(32500), '+RD\$ 32,500.00');
      expect(CurrencyFormatter.format(null), 'RD\$ 0.00');
    });

    test('UT-F11 · DateFormatter muestra DD/MM/AAAA y convierte a AAAA-MM-DD para la API', () {
      expect(DateFormatter.format('2026-10-26'), '26/10/2026');
      expect(DateFormatter.toApiDate(DateTime(2026, 3, 5)), '2026-03-05');
    });
  });

  group('Accesibilidad de color (RNF-USA-02, WCAG 2.1 AA = 4.5:1)', () {
    void check(String modo, NexoColors c) {
      final pares = <String, List<Color>>{
        'texto/fondo': [c.text, c.background],
        'texto/tarjeta': [c.text, c.card],
        'secundario/fondo': [c.muted, c.background],
        'secundario/tarjeta': [c.muted, c.card],
        'positivo/fondo': [c.positive, c.background],
        'positivo/tarjeta': [c.positive, c.card],
        'negativo/fondo': [c.negative, c.background],
        'negativo/tarjeta': [c.negative, c.card],
        'negativo/superficie': [c.negative, c.surface],
        'advertencia/tarjeta': [c.warning, c.card],
        'acento/fondo': [c.accent, c.background],
        'acento/tarjeta': [c.accent, c.card],
      };
      pares.forEach((nombre, colores) {
        final ratio = contrast(colores[0], colores[1]);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '$modo · $nombre = ${ratio.toStringAsFixed(2)}:1');
      });
    }

    test('UT-F12 · la paleta del modo oscuro cumple el contraste AA en todos sus pares texto/fondo', () => check('oscuro', NexoColors.dark));
    test('UT-F13 · la paleta del modo claro cumple el contraste AA en todos sus pares texto/fondo', () => check('claro', NexoColors.light));
  });
}
