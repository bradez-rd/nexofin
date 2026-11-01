import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexofin/core/theme/app_theme.dart';
import 'package:nexofin/core/utils/date_formatter.dart';
import 'package:nexofin/providers/account_provider.dart';
import 'package:nexofin/providers/auth_provider.dart';
import 'package:nexofin/providers/transaction_provider.dart';
import 'package:nexofin/screens/accounts/accounts_tab.dart';
import 'package:nexofin/screens/profile/profile_tab.dart';
import 'package:nexofin/screens/transactions/transactions_tab.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_api.dart';

/// Pruebas de pantallas de Cuentas, Movimientos y Perfil, con la API simulada.
void main() {
  late FakeApi api;
  late AccountProvider accounts;
  late TransactionProvider transactions;
  late AuthProvider auth;

  final today = DateFormatter.toApiDate(DateTime.now());
  final yesterday = DateFormatter.toApiDate(DateTime.now().subtract(const Duration(days: 1)));

  setUp(() async {
    api = FakeApi();
    await api.install();
    accounts = AccountProvider();
    transactions = TransactionProvider();
    auth = AuthProvider();

    api.on('GET', '/accounts', {
      'success': true,
      'data': {
        'accounts': [
          accountJson('a1', 'Banco Popular', 'bancaria', 75800),
          accountJson('a2', 'Efectivo', 'efectivo', 6049.25),
          accountJson('a3', 'Visa Popular', 'tarjeta', -8700, limite: 80000, corte: 25, pago: 15),
        ],
      },
    });
    api.on('GET', '/accounts/summary/balances', {'success': true, 'data': {'summary': []}});
    api.on('GET', '/categories', {
      'success': true,
      'data': {'categories': [categoryJson('k1', 'Alimentación y Supermercado', 'gasto'), categoryJson('k2', 'Salario / Nómina', 'ingreso')]},
    });
    api.on('GET', '/transactions/summary/monthly', {
      'success': true,
      'data': {'totalIngresos': 65000, 'totalGastos': 26550, 'balanceNeto': 38450},
    });
    api.on('GET', '/transactions', {
      'success': true,
      'data': {
        'total': 3, 'limit': 20, 'offset': 0,
        'transactions': [
          txJson('t1', 'a1', 'gasto', 3450, today, categoriaId: 'k1', descripcion: 'Supermercados Bravo'),
          txJson('t2', 'a1', 'ingreso', 32500, yesterday, sentido: 'entrada', categoriaId: 'k2', descripcion: 'Nómina Quincenal'),
          txJson('t3', 'a1', 'transferencia', 5000, yesterday, vinculada: 't4', descripcion: 'Ahorro'),
        ],
      },
    });
    await accounts.fetchAccounts();
    await transactions.fetchCategories();
  });

  Widget app(Widget home) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<AccountProvider>.value(value: accounts),
        ChangeNotifierProvider<TransactionProvider>.value(value: transactions),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('es', 'DO'),
        supportedLocales: const [Locale('es', 'DO')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // La fuente de pruebas es el doble de ancha que una real: se reduce el texto (ver pantallas_test.dart)
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.55)),
          child: child!,
        ),
        home: Scaffold(body: home),
      ),
    );
  }

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('Cuentas y tarjetas (RN-CTA-02, RF-CTA-01/02/05)', () {
    testWidgets('WT-15 · la posición neta separa lo disponible de la deuda y la tarjeta muestra límite, consumo y fechas', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const AccountsTab()));
      await tester.pumpAndSettle();

      expect(find.text('RD\$ 81,849.25'), findsOneWidget); // disponible real: banco + efectivo, sin tarjeta
      expect(find.text('RD\$ 8,700.00'), findsOneWidget); // deuda de la tarjeta
      expect(find.textContaining('las tarjetas de crédito no'), findsOneWidget);
      expect(find.text('Banco Popular'), findsOneWidget);

      await tester.tap(find.text('Tarjetas (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Visa Popular'), findsOneWidget);
      expect(find.text('10.9% consumido'), findsOneWidget); // 8,700 / 80,000
      expect(find.text('Crédito disponible: RD\$ 71,300.00'), findsOneWidget);
      expect(find.text('Corte: día 25 · Pago: día 15'), findsOneWidget);
    });

    testWidgets('WT-16 · abonar a la tarjeta: no deja pagar más que la deuda y envía una transferencia (no un gasto)', (tester) async {
      bigScreen(tester);
      api.on('POST', '/transactions/transfer', {'success': true, 'data': {'salida': {}, 'entrada': {}}});
      await tester.pumpWidget(app(const AccountsTab()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tarjetas (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abonar a tarjeta'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar abono'), findsOneWidget);

      final amount = find.byType(TextField).last;
      await tester.enterText(amount, '9000');
      await tester.pump();
      expect(find.textContaining('no puede superar la deuda'), findsWidgets);

      await tester.enterText(amount, '8700');
      await tester.pump();
      await tester.tap(find.text('Confirmar abono'));
      await tester.pumpAndSettle();

      final body = api.bodyOf(api.callsTo('POST', '/transactions/transfer').single);
      expect(body['cuenta_origen_id'], 'a1'); // primera cuenta con fondos
      expect(body['cuenta_destino_id'], 'a3'); // la tarjeta
      expect(body['monto'], 8700);
      expect(api.callsTo('POST', '/transactions'), isEmpty); // no se registró como gasto
    });

    testWidgets('WT-17 · crear cuenta valida el nombre y muestra los datos de tarjeta solo para tarjetas', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const AccountsTab()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva').first);
      await tester.pumpAndSettle();
      expect(find.text('Nueva cuenta'), findsOneWidget);
      expect(find.text('Límite de crédito (opcional)'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'X');
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('El nombre debe tener al menos 2 caracteres.'), findsOneWidget);
      expect(api.callsTo('POST', '/accounts'), isEmpty);

      await tester.tap(find.text('Tarjeta').last);
      await tester.pumpAndSettle();
      expect(find.text('Límite de crédito (opcional)'), findsOneWidget);
      expect(find.text('Día de corte'), findsOneWidget);
    });
  });

  group('Movimientos (RF-TRX-03/04/05)', () {
    testWidgets('WT-18 · el historial agrupa por día, etiqueta el tipo y filtra por tipo contra la API', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const TransactionsTab()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hoy,'), findsOneWidget);
      expect(find.textContaining('Ayer,'), findsOneWidget);
      expect(find.text('Supermercados Bravo'), findsOneWidget);
      expect(find.text('Gasto'), findsOneWidget);
      expect(find.text('Ingreso'), findsOneWidget);
      expect(find.text('Transferencia'), findsOneWidget);
      expect(find.text('Resumen de ${[
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
      ][DateTime.now().month - 1]}'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ingresos'));
      await tester.pumpAndSettle();
      expect(api.callsTo('GET', '/transactions').last.url.queryParameters['tipo'], 'ingreso');
    });

    testWidgets('WT-19 · los filtros avanzados aplican el rango de fechas elegido', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const TransactionsTab()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.text('Filtros avanzados'), findsOneWidget);
      await tester.tap(find.text('Últimos 30 días'));
      await tester.pump();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      final q = api.callsTo('GET', '/transactions').last.url.queryParameters;
      expect(q['fecha_inicio'], isNotNull);
      expect(q['fecha_fin'], today);
    });

    testWidgets('WT-23 · en la hoja de filtros ningún chip aparece marcado hasta que se elige uno', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const TransactionsTab()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing); // antes: “Este mes” mostraba un check sin estar seleccionado
      ChoiceChip chip() => tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Este mes'));
      expect(chip().selected, false);
      await tester.tap(find.text('Este mes'));
      await tester.pump();
      expect(chip().selected, true);
    });

    testWidgets('WT-20 · el detalle permite eliminar una transacción tras confirmar', (tester) async {
      bigScreen(tester);
      api.on('DELETE', '/transactions/t1', {'success': true, 'message': 'ok'});
      await tester.pumpWidget(app(const TransactionsTab()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supermercados Bravo'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle de transacción'), findsOneWidget);
      await tester.tap(find.text('Eliminar transacción'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar'), findsOneWidget); // diálogo de confirmación
      expect(api.callsTo('DELETE', '/transactions/t1'), isEmpty); // aún no se eliminó
      await tester.tap(find.text('Eliminar').last);
      await tester.pumpAndSettle();
      expect(api.callsTo('DELETE', '/transactions/t1'), hasLength(1));
    });

    testWidgets('WT-21 · editar guarda solo los campos y una transferencia no se puede editar', (tester) async {
      bigScreen(tester);
      api.on('PUT', '/transactions/t1', {'success': true, 'data': {'transaction': {}}});
      await tester.pumpWidget(app(const TransactionsTab()));
      await tester.pumpAndSettle();

      // Gasto: se puede editar el monto
      await tester.tap(find.text('Supermercados Bravo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar campos'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '4000');
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      final body = api.bodyOf(api.callsTo('PUT', '/transactions/t1').single);
      expect(body['monto'], 4000);

      // Transferencia: la edición está deshabilitada
      await tester.tap(find.text('Ahorro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar campos'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no se pueden editar'), findsOneWidget);
    });
  });

  group('Perfil (RF-AUT-08)', () {
    testWidgets('WT-22 · muestra los datos del usuario y cierra sesión con el botón', (tester) async {
      bigScreen(tester);
      api.on('POST', '/auth/login', {
        'success': true,
        'data': {
          'token': 't',
          'user': {'id': 'u1', 'nombre': 'Paola Piantini', 'email': 'paola@itla.edu.do', 'moneda_predeterminada': 'DOP', 'zona_horaria': 'America/Santo_Domingo'},
        },
      });
      await auth.login('paola@itla.edu.do', 'ClaveSegura2026');
      var loggedOut = false;
      await tester.pumpWidget(app(ProfileTab(onLogout: () => loggedOut = true)));
      await tester.pumpAndSettle();

      expect(find.text('Paola Piantini'), findsOneWidget);
      expect(find.text('paola@itla.edu.do'), findsOneWidget);
      expect(find.text('Peso dominicano (RD\$)'), findsOneWidget);
      expect(find.text('America/Santo_Domingo'), findsOneWidget);
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      expect(loggedOut, true);
    });
  });
}
