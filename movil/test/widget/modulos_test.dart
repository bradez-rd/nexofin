import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexofin/core/theme/app_theme.dart';
import 'package:nexofin/providers/account_provider.dart';
import 'package:nexofin/providers/transaction_provider.dart';
import 'package:nexofin/screens/assistant/assistant_screen.dart';
import 'package:nexofin/screens/budgets/budgets_screen.dart';
import 'package:nexofin/screens/debts/debts_screen.dart';
import 'package:nexofin/screens/goals/goals_screen.dart';
import 'package:nexofin/screens/imports/import_screen.dart';
import 'package:nexofin/screens/notifications/notifications_screen.dart';
import 'package:nexofin/screens/recurring/recurring_screen.dart';
import 'package:nexofin/screens/security/security_screen.dart';
import 'package:nexofin/screens/simulator/simulator_tab.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_api.dart';

/// Pruebas de pantalla de los módulos de nivel 1 completados en el Entregable 5, con la API simulada.
void main() {
  late FakeApi api;

  setUp(() async {
    api = FakeApi();
    await api.install();
    api.on('GET', '/accounts', {
      'success': true,
      'data': {
        'accounts': [accountJson('a1', 'Banco Popular', 'bancaria', 75800)],
      },
    });
    api.on('GET', '/categories', {
      'success': true,
      'data': {'categories': [categoryJson('k1', 'Alimentación y Supermercado', 'gasto'), categoryJson('k2', 'Salario / Nómina', 'ingreso')]},
    });
  });

  Widget app(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccountProvider()..fetchAccounts()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()..fetchCategories()),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: const [Locale('es', 'DO')],
        locale: const Locale('es', 'DO'),
        home: child,
      ),
    );
  }

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 0.55;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearAllTestValues();
    });
  }

  group('Módulos de planificación', () {
    testWidgets('MW-01 · presupuestos: muestra el porcentaje consumido y el estado de cada categoría', (tester) async {
      bigScreen(tester);
      api.on('GET', '/budgets', {
        'success': true,
        'data': {
          'budgets': [
            {'id': 'b1', 'categoria_id': 'k1', 'categoria_nombre': 'Alimentación y Supermercado', 'mes': '2026-11', 'monto_limite': 10000, 'umbral_alerta': 0.8, 'consumido': 8500, 'disponible': 1500, 'porcentaje': 85, 'estado': 'alerta'},
            {'id': 'b2', 'categoria_id': 'k3', 'categoria_nombre': 'Transporte', 'mes': '2026-11', 'monto_limite': 2000, 'umbral_alerta': 0.8, 'consumido': 2400, 'disponible': -400, 'porcentaje': 120, 'estado': 'superado'},
          ],
        },
      });
      await tester.pumpWidget(app(const BudgetsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Alimentación y Supermercado'), findsOneWidget);
      expect(find.text('En alerta'), findsOneWidget);
      expect(find.text('Superado'), findsOneWidget);
      expect(find.textContaining('Te pasaste por RD\$ 400.00'), findsOneWidget);
    });

    testWidgets('MW-02 · presupuestos: sin datos muestra un estado vacío con instrucciones', (tester) async {
      bigScreen(tester);
      api.on('GET', '/budgets', {'success': true, 'data': {'budgets': []}});
      await tester.pumpWidget(app(const BudgetsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Sin presupuestos este mes'), findsOneWidget);
    });

    testWidgets('MW-03 · metas: muestra el monto mensual necesario y la fecha estimada', (tester) async {
      bigScreen(tester);
      api.on('GET', '/goals', {
        'success': true,
        'data': {
          'goals': [
            {'id': 'g1', 'nombre': 'Viaje', 'cuenta_id': null, 'monto_objetivo': 60000, 'fecha_limite': '2027-05-01', 'estado': 'activa', 'acumulado': 15000, 'faltante': 45000, 'porcentaje': 25, 'meses_restantes': 6, 'monto_mensual_necesario': 7500, 'ritmo_mensual_actual': 5000, 'fecha_estimada_cumplimiento': '2027-08-01', 'vencida': false},
          ],
        },
      });
      await tester.pumpWidget(app(const GoalsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Viaje'), findsOneWidget);
      expect(find.textContaining('Necesitas RD\$ 7,500.00 al mes'), findsOneWidget);
      expect(find.textContaining('01/08/2027'), findsOneWidget);
      expect(find.text('Aportar'), findsOneWidget);
    });

    testWidgets('MW-04 · deudas: muestra saldo pendiente, cuotas restantes y la próxima cuota', (tester) async {
      bigScreen(tester);
      api.on('GET', '/debts', {
        'success': true,
        'data': {
          'debts': [
            {'id': 'd1', 'acreedor': 'Banco Popular', 'monto_original': 120000, 'tasa_anual': 12, 'num_cuotas': 12, 'fecha_primera_cuota': '2026-11-10', 'estado': 'activa', 'saldo_pendiente': 106618.5, 'capital_pendiente': 100000, 'cuotas_restantes': 10, 'proxima_cuota': {'numero': 3, 'vencimiento': '2027-01-10', 'monto_pendiente': 10661.85}},
          ],
        },
      });
      await tester.pumpWidget(app(const DebtsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Banco Popular'), findsOneWidget);
      expect(find.text('Pendiente: RD\$ 106,618.50'), findsOneWidget);
      expect(find.textContaining('10 cuotas restantes'), findsOneWidget);
      expect(find.textContaining('cuota 3 el 10/01/2027'), findsOneWidget);
    });

    testWidgets('MW-05 · recurrentes: permite pausar y muestra el estado', (tester) async {
      bigScreen(tester);
      api.on('GET', '/recurring', {
        'success': true,
        'data': {
          'recurrentes': [
            {'id': 'r1', 'cuenta_id': 'a1', 'categoria_id': null, 'tipo': 'gasto', 'monto': 900, 'descripcion': 'Netflix', 'frecuencia': 'mensual', 'fecha_inicio': '2026-10-01', 'fecha_fin': null, 'ultima_generada': '2026-11-01', 'estado': 'activa'},
          ],
        },
      });
      await tester.pumpWidget(app(const RecurringScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Activa'), findsOneWidget);
      expect(find.textContaining('Mensual'), findsOneWidget);
    });

    testWidgets('MW-06 · notificaciones: distingue las no leídas y las marca al tocarlas', (tester) async {
      bigScreen(tester);
      api.on('GET', '/notifications', {
        'success': true,
        'data': {
          'no_leidas': 1,
          'notifications': [
            {'id': 'n1', 'tipo': 'presupuesto_superado', 'mensaje': 'Superaste el presupuesto de Transporte.', 'leida': false, 'creada_en': '2026-11-01T10:00:00Z'},
            {'id': 'n2', 'tipo': 'meta_alcanzada', 'mensaje': '¡Alcanzaste tu meta "Laptop"!', 'leida': true, 'creada_en': '2026-10-30T10:00:00Z'},
          ],
        },
      });
      api.on('POST', '/notifications/n1/read', {'success': true, 'data': {}});
      await tester.pumpWidget(app(const NotificationsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Superaste el presupuesto de Transporte.'), findsOneWidget);
      await tester.tap(find.text('Superaste el presupuesto de Transporte.'));
      await tester.pumpAndSettle();
      expect(api.callsTo('POST', '/notifications/n1/read'), hasLength(1));
    });
  });

  group('Simulador y asistente', () {
    testWidgets('MW-07 · simulador: envía el gasto, muestra saldo libre antes y después, alternativas y aviso', (tester) async {
      bigScreen(tester);
      api.on('POST', '/simulations/expense', {
        'success': true,
        'data': {
          'simulacion': {
            'id': 's1',
            'tipo': 'gasto',
            'concluyente': true,
            'resultado': {
              'tipo': 'gasto',
              'concluyente': true,
              'faltantes': [],
              'resumen': 'Con este gasto tu saldo libre pasaría de RD\$ 50,000.00 a RD\$ 40,000.00 al 2026-11-30.',
              'supuestos': {'fecha_base': '2026-11-01', 'fuente_ingresos': 'recurrentes'},
              'resultado': {'saldo_libre_antes': 50000, 'saldo_libre_despues': 40000},
              'alternativas': [
                {'tipo': 'posponer', 'descripcion': 'Pospón el gasto un mes', 'efecto': {}}
              ],
              'aviso': 'Esta simulación es una estimación y no garantiza resultados futuros.',
            },
          },
        },
      }, status: 201);
      await tester.pumpWidget(app(const Scaffold(body: SimulatorTab())));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '10000');
      await tester.tap(find.text('Simular'));
      await tester.pumpAndSettle();
      expect(api.bodyOf(api.callsTo('POST', '/simulations/expense').first)['monto'], 10000);
      expect(find.textContaining('pasaría de RD\$ 50,000.00'), findsOneWidget);
      expect(find.text('RD\$ 50,000.00'), findsOneWidget);
      expect(find.text('RD\$ 40,000.00'), findsOneWidget);
      expect(find.textContaining('Pospón el gasto'), findsOneWidget);
      expect(find.textContaining('no garantiza'), findsOneWidget);
    });

    testWidgets('MW-08 · simulador: con datos insuficientes lo declara y lista lo que falta', (tester) async {
      bigScreen(tester);
      api.on('POST', '/simulations/expense', {
        'success': true,
        'data': {
          'simulacion': {
            'id': 's2',
            'tipo': 'gasto',
            'concluyente': false,
            'resultado': {
              'tipo': 'gasto',
              'concluyente': false,
              'faltantes': ['Registra tus ingresos (una nómina recurrente o al menos un ingreso reciente)'],
              'resumen': 'No hay datos suficientes para simular con confianza.',
              'supuestos': {},
              'resultado': {},
              'alternativas': [],
              'aviso': 'Esta simulación es una estimación.',
            },
          },
        },
      }, status: 201);
      await tester.pumpWidget(app(const Scaffold(body: SimulatorTab())));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '500');
      await tester.tap(find.text('Simular'));
      await tester.pumpAndSettle();
      expect(find.text('Datos insuficientes'), findsOneWidget);
      expect(find.textContaining('Registra tus ingresos'), findsOneWidget);
    });

    testWidgets('MW-09 · simulador: rechaza un monto vacío sin llamar a la API', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const Scaffold(body: SimulatorTab())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simular'));
      await tester.pumpAndSettle();
      expect(find.text('Indica un monto mayor que cero'), findsOneWidget);
      expect(api.callsTo('POST', '/simulations/expense'), isEmpty);
    });

    testWidgets('MW-10 · asistente: muestra la respuesta con su etiqueta de contenido y el origen de las cifras', (tester) async {
      bigScreen(tester);
      api.on('POST', '/assistant/messages', {
        'success': true,
        'data': {
          'conversacion_id': 'c1',
          'respuesta': {
            'id': 'm1',
            'contenido': 'Tu saldo disponible es RD\$ 82,000.00.',
            'tipo_contenido': 'calculo',
            'cifras': [
              {'etiqueta': 'Saldo disponible', 'valor': 82000, 'origen': 'Suma de saldos de tus cuentas activas (sin tarjetas)'}
            ],
            'fuentes': [],
            'simulacion_id': null,
            'acciones_sugeridas': [],
            'requiere_confirmacion': false,
          },
        },
      }, status: 201);
      await tester.pumpWidget(app(const AssistantScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('¿Cuánto tengo?'));
      await tester.pumpAndSettle();
      expect(find.text('Tu saldo disponible es RD\$ 82,000.00.'), findsOneWidget);
      expect(find.text('Cálculo con tus datos'), findsOneWidget);
      await tester.tap(find.text('Ver detalle del cálculo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Origen: Suma de saldos'), findsOneWidget);
    });

    testWidgets('MW-11 · asistente: pide el consentimiento y lo envía al aceptar', (tester) async {
      bigScreen(tester);
      api.onError('POST', '/assistant/messages', 'Para usar el asistente debes aceptar el consentimiento de uso de tus datos', status: 403);
      api.on('PUT', '/auth/consent-ai', {'success': true, 'data': {}});
      await tester.pumpWidget(app(const AssistantScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('¿Cuánto tengo?'));
      await tester.pumpAndSettle();
      expect(find.text('Antes de empezar'), findsOneWidget);
      // Al aceptar, la pregunta pendiente se reenvía sola y ya recibe respuesta
      api.on('POST', '/assistant/messages', {
        'success': true,
        'data': {
          'conversacion_id': 'c1',
          'respuesta': {'id': 'm1', 'contenido': 'Tu saldo disponible es RD\$ 82,000.00.', 'tipo_contenido': 'calculo', 'cifras': [], 'fuentes': [], 'simulacion_id': null, 'acciones_sugeridas': [], 'requiere_confirmacion': false},
        },
      }, status: 201);
      await tester.tap(find.text('Aceptar y continuar'));
      await tester.pumpAndSettle();
      expect(api.bodyOf(api.callsTo('PUT', '/auth/consent-ai').first)['otorgado'], true);
      expect(find.text('Antes de empezar'), findsNothing);
      expect(find.text('Tu saldo disponible es RD\$ 82,000.00.'), findsOneWidget);
      expect(find.text('¿Cuánto tengo?'), findsOneWidget); // la pregunta original sigue en el chat
    });
  });

  group('Datos y seguridad', () {
    testWidgets('MW-12 · importaciones: lista los archivos con su estado y el motivo de un fallo', (tester) async {
      bigScreen(tester);
      api.on('GET', '/imports', {
        'success': true,
        'data': {
          'importaciones': [
            {'id': 'i1', 'cuenta_id': 'a1', 'nombre_archivo': 'estado_octubre.csv', 'tipo_archivo': 'csv', 'estado': 'lista_revision', 'motivo_fallo': null, 'creada_en': '2026-11-01T10:00:00Z'},
            {'id': 'i2', 'cuenta_id': 'a1', 'nombre_archivo': 'roto.xlsx', 'tipo_archivo': 'xlsx', 'estado': 'fallida', 'motivo_fallo': 'El archivo está dañado o no se puede leer.', 'creada_en': '2026-11-01T09:00:00Z'},
          ],
        },
      });
      await tester.pumpWidget(app(const ImportScreen()));
      await tester.pumpAndSettle();
      expect(find.text('estado_octubre.csv'), findsOneWidget);
      expect(find.text('Lista para revisar'), findsOneWidget);
      expect(find.text('Fallida'), findsOneWidget);
      expect(find.textContaining('dañado'), findsOneWidget);
    });

    testWidgets('MW-13 · revisión de importación: marca los posibles duplicados y permite guardar los aprobados', (tester) async {
      bigScreen(tester);
      api.on('GET', '/imports/i1', {
        'success': true,
        'data': {
          'importacion': {'id': 'i1', 'cuenta_id': 'a1', 'nombre_archivo': 'estado.csv', 'tipo_archivo': 'csv', 'estado': 'lista_revision', 'motivo_fallo': null, 'creada_en': '2026-11-01T10:00:00Z', 'confirmada_en': null},
          'resumen': {'detectados': 2, 'duplicados_potenciales': 1, 'sin_categoria_sugerida': 1, 'aprobados': 1, 'excluidos': 1, 'total_entradas': 45000, 'total_salidas': 0},
          'movimientos': [
            {'id': 'm1', 'fecha': '2026-10-20', 'monto': 45000, 'sentido': 'entrada', 'descripcion': 'Nómina empresa', 'duplicado_potencial': false, 'categoria_sugerida_id': null, 'confianza': null, 'decision': 'aprobado', 'transaccion_id': null},
            {'id': 'm2', 'fecha': '2026-10-22', 'monto': 2500.5, 'sentido': 'salida', 'descripcion': 'Supermercado Nacional', 'duplicado_potencial': true, 'categoria_sugerida_id': 'k1', 'confianza': 0.85, 'decision': 'excluido', 'transaccion_id': null},
          ],
        },
      });
      api.on('POST', '/imports/i1/confirm', {'success': true, 'data': {}});
      await tester.pumpWidget(app(const ImportReviewScreen(importId: 'i1')));
      await tester.pumpAndSettle();
      expect(find.text('Posible duplicado'), findsOneWidget);
      expect(find.textContaining('1 posibles duplicados'), findsOneWidget);
      expect(find.text('Guardar 1 movimientos'), findsOneWidget);
    });

    testWidgets('MW-14 · seguridad: muestra el estado de dos pasos y la actividad reciente', (tester) async {
      bigScreen(tester);
      api.on('GET', '/auth/profile', {
        'success': true,
        'data': {
          'user': {'id': 'u1', 'nombre': 'Paola', 'email': 'p@itla.edu.do', 'dos_factores_activo': true, 'consentimiento_ia_en': '2026-11-01T10:00:00Z'},
        },
      });
      api.on('GET', '/audit/activity', {
        'success': true,
        'data': {
          'total': 2,
          'activity': [
            {'id': 2, 'accion': 'login', 'resultado': 'fallo', 'detalle': null, 'fecha': '2026-11-01T10:00:00Z'},
            {'id': 1, 'accion': 'login', 'resultado': 'exito', 'detalle': null, 'fecha': '2026-10-31T10:00:00Z'},
          ],
        },
      });
      await tester.pumpWidget(app(const SecurityScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Activada'), findsOneWidget);
      expect(find.text('Desactivar'), findsOneWidget);
      expect(find.text('Inicio de sesión'), findsNWidgets(2));
      expect(find.text('Fallido'), findsOneWidget);
    });
  });
}
