import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexofin/core/theme/app_theme.dart';
import 'package:nexofin/providers/account_provider.dart';
import 'package:nexofin/providers/auth_provider.dart';
import 'package:nexofin/providers/transaction_provider.dart';
import 'package:nexofin/screens/auth/login_screen.dart';
import 'package:nexofin/screens/auth/register_screen.dart';
import 'package:nexofin/screens/dashboard/dashboard_tab.dart';
import 'package:nexofin/screens/transactions/add_transaction_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_api.dart';

/// Pruebas de pantallas (widget): comprueban lo que el usuario ve y puede hacer, con providers reales
/// conectados a una API simulada.
void main() {
  late FakeApi api;

  setUp(() async {
    api = FakeApi();
    await api.install(loggedIn: false);
  });

  Widget app(Widget home, {List<ChangeNotifierProvider>? providers}) {
    return MultiProvider(
      providers: providers ??
          [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<AccountProvider>(create: (_) => AccountProvider()),
            ChangeNotifierProvider<TransactionProvider>(create: (_) => TransactionProvider()),
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
        // La fuente de las pruebas (Ahem) es el doble de ancha que una real; se reduce el texto para
        // que los desbordamientos que se detecten sean de verdad y no del tipo de letra.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.55)),
          child: child!,
        ),
        home: home,
      ),
    );
  }

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('Inicio de sesión (RF-AUT-03)', () {
    testWidgets('WT-01 · los campos arrancan vacíos: no hay credenciales precargadas en la pantalla', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const LoginScreen()));
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields.length, 2);
      expect(fields[0].controller!.text, isEmpty);
      expect(fields[1].controller!.text, isEmpty);
      expect(find.textContaining('brailin@nexofin.com'), findsNothing);
    });

    testWidgets('WT-02 · enviar vacío muestra los avisos de campo obligatorio y no llama a la API', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const LoginScreen()));
      await tester.tap(find.text('Ingresar a NexoFin'));
      await tester.pumpAndSettle();
      expect(find.text('El correo es obligatorio'), findsOneWidget);
      expect(find.text('La contraseña es requerida'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('WT-03 · credenciales incorrectas: aviso genérico que no revela cuál campo falló', (tester) async {
      bigScreen(tester);
      api.onError('POST', '/auth/login', 'Credenciales inválidas', status: 401);
      await tester.pumpWidget(app(const LoginScreen()));
      await tester.enterText(find.byType(TextFormField).at(0), 'paola@itla.edu.do');
      await tester.enterText(find.byType(TextFormField).at(1), 'ClaveIncorrecta1');
      await tester.tap(find.text('Ingresar a NexoFin'));
      await tester.pumpAndSettle();
      expect(find.text('Credenciales inválidas'), findsOneWidget);
      expect(find.text('Por seguridad, verifica tu correo y contraseña.'), findsOneWidget);
    });

    testWidgets('WT-04 · cuenta bloqueada: el aviso lo indica y muestra los minutos restantes', (tester) async {
      bigScreen(tester);
      api.onError('POST', '/auth/login',
          'Cuenta temporalmente bloqueada por seguridad tras 5 intentos fallidos. Intente nuevamente en 15 minuto(s).',
          status: 401);
      await tester.pumpWidget(app(const LoginScreen()));
      await tester.enterText(find.byType(TextFormField).at(0), 'paola@itla.edu.do');
      await tester.enterText(find.byType(TextFormField).at(1), 'ClaveCorrecta2026');
      await tester.tap(find.text('Ingresar a NexoFin'));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta bloqueada temporalmente'), findsOneWidget);
      expect(find.textContaining('15 minuto(s)'), findsOneWidget);
    });
  });

  group('Registro (RF-AUT-01, RN-SEG-01)', () {
    Future<void> openRegister(WidgetTester tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const RegisterScreen()));
    }

    Finder field(int i) => find.byType(TextFormField).at(i);

    testWidgets('WT-05 · el medidor de fortaleza pasa de Débil a Fuerte y Muy fuerte según la contraseña', (tester) async {
      await openRegister(tester);
      await tester.enterText(field(2), 'abcdefghij'); // solo longitud
      await tester.pump();
      expect(find.text('Débil'), findsOneWidget);
      await tester.enterText(field(2), 'Abcdefghij1'); // longitud + número + mayúsculas y minúsculas
      await tester.pump();
      expect(find.text('Fuerte'), findsOneWidget);
      await tester.enterText(field(2), 'Abcdefghij1!zzzz'); // 14 o más caracteres
      await tester.pump();
      expect(find.text('Muy fuerte'), findsOneWidget);
    });

    testWidgets('WT-06 · una contraseña de menos de 10 caracteres se rechaza con un aviso', (tester) async {
      await openRegister(tester);
      await tester.enterText(field(0), 'Maria Prueba');
      await tester.enterText(field(1), 'maria@itla.edu.do');
      await tester.enterText(field(2), 'Corta1!');
      await tester.enterText(field(3), 'Corta1!');
      await tester.tap(find.text('Crear cuenta y comenzar'));
      await tester.pumpAndSettle();
      expect(find.text('La contraseña debe tener mínimo 10 caracteres'), findsOneWidget);
      expect(api.callsTo('POST', '/auth/register'), isEmpty);
    });

    testWidgets('WT-07 · indica si el correo es válido y si las contraseñas coinciden', (tester) async {
      await openRegister(tester);
      await tester.enterText(field(1), 'no-es-correo');
      await tester.pump();
      expect(find.text('Revisa el formato'), findsOneWidget);
      await tester.enterText(field(1), 'maria@itla.edu.do');
      await tester.pump();
      expect(find.text('Válido'), findsOneWidget);

      await tester.enterText(field(2), 'Abcdefghij1!');
      await tester.enterText(field(3), 'otra-cosa');
      await tester.pump();
      expect(find.text('No coinciden'), findsOneWidget);
      await tester.enterText(field(3), 'Abcdefghij1!');
      await tester.pump();
      expect(find.text('Las contraseñas coinciden'), findsOneWidget);
    });

    testWidgets('WT-08 · no permite registrarse sin aceptar los términos y no llama a la API', (tester) async {
      await openRegister(tester);
      await tester.enterText(field(0), 'Maria Prueba');
      await tester.enterText(field(1), 'maria@itla.edu.do');
      await tester.enterText(field(2), 'Abcdefghij1!');
      await tester.enterText(field(3), 'Abcdefghij1!');
      await tester.tap(find.text('Crear cuenta y comenzar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Debes aceptar los Términos de Servicio'), findsOneWidget);
      expect(api.callsTo('POST', '/auth/register'), isEmpty);
    });
  });

  group('Nueva transacción (RF-TRX-01, RN-TRX-01/02)', () {
    Future<void> openAdd(WidgetTester tester, {String type = 'gasto'}) async {
      bigScreen(tester);
      api.on('GET', '/accounts', {
        'success': true,
        'data': {
          'accounts': [
            accountJson('a1', 'Banco Popular', 'bancaria', 76100),
            accountJson('a2', 'Efectivo', 'efectivo', 4600),
          ],
        },
      });
      api.on('GET', '/accounts/summary/balances', {'success': true, 'data': {'summary': []}});
      api.on('GET', '/categories', {
        'success': true,
        'data': {'categories': [categoryJson('k1', 'Alimentación y Supermercado', 'gasto')]},
      });
      await tester.pumpWidget(app(AddTransactionScreen(initialType: type)));
      await tester.pumpAndSettle();
    }

    testWidgets('WT-09 · abre en Gasto, exige un monto mayor que cero y confirma cuando es válido', (tester) async {
      await openAdd(tester);
      expect(find.text('Monto del gasto'), findsOneWidget);
      expect(find.text('El monto debe ser mayor a RD\$ 0.00'), findsOneWidget);
      await tester.tap(find.text('+500'));
      await tester.pump();
      expect(find.text('Monto válido'), findsOneWidget);
      await tester.tap(find.text('+1,000'));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text, '1500');
    });

    testWidgets('WT-10 · cambiar el tipo actualiza el texto, y Transferir pide la cuenta de destino sin categoría', (tester) async {
      await openAdd(tester);
      await tester.tap(find.text('Ingreso'));
      await tester.pump();
      expect(find.text('Monto del ingreso'), findsOneWidget);

      await tester.tap(find.text('Transferir'));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta de destino'), findsOneWidget);
      expect(find.text('Categoría'), findsNothing);
      expect(find.textContaining('no cuentan como gasto ni ingreso'), findsOneWidget);
    });

    testWidgets('WT-11 · un ajuste pide elegir si aumenta o disminuye el saldo', (tester) async {
      await openAdd(tester);
      await tester.tap(find.text('Ajuste'));
      await tester.pumpAndSettle();
      expect(find.text('Efecto del ajuste'), findsOneWidget);
      expect(find.text('Aumenta el saldo'), findsOneWidget);
      expect(find.text('Disminuye el saldo'), findsOneWidget);
    });

    testWidgets('WT-12 · guardar sin monto muestra el aviso y no envía nada a la API', (tester) async {
      await openAdd(tester);
      await tester.ensureVisible(find.text('Guardar transacción'));
      await tester.tap(find.text('Guardar transacción'));
      await tester.pumpAndSettle();
      expect(find.text('El monto debe ser mayor que cero.'), findsOneWidget);
      expect(api.callsTo('POST', '/transactions'), isEmpty);
    });

    testWidgets('WT-13 · al guardar un gasto válido envía los datos correctos a la API y muestra el nuevo saldo', (tester) async {
      await openAdd(tester);
      api.on('POST', '/transactions', {
        'success': true,
        'data': {'transaction': txJson('n1', 'a1', 'gasto', 1000, '2026-10-26')},
      });
      api.on('GET', '/transactions', {'success': true, 'data': {'total': 0, 'transactions': []}});
      api.on('GET', '/transactions/summary/monthly', {'success': true, 'data': {'totalIngresos': 0, 'totalGastos': 1000, 'balanceNeto': -1000}});

      await tester.tap(find.text('+1,000'));
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar transacción'));
      await tester.tap(find.text('Guardar transacción'));
      await tester.pumpAndSettle();

      final body = api.bodyOf(api.callsTo('POST', '/transactions').single);
      expect(body['tipo'], 'gasto');
      expect(body['monto'], 1000);
      expect(body['cuenta_id'], 'a1');
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(body['fecha'] as String), true);
    });
  });

  group('Dashboard (RN-CTA-02, RF-DAS-01/02)', () {
    testWidgets('WT-14 · el saldo disponible excluye las tarjetas y la deuda se muestra aparte', (tester) async {
      bigScreen(tester);
      api.on('GET', '/accounts', {
        'success': true,
        'data': {
          'accounts': [
            accountJson('a1', 'Banco Popular', 'bancaria', 75800),
            accountJson('a2', 'Efectivo', 'efectivo', 6049.25),
            accountJson('a3', 'Visa', 'tarjeta', -8700, limite: 80000),
          ],
        },
      });
      api.on('GET', '/accounts/summary/balances', {'success': true, 'data': {'summary': []}});
      api.on('GET', '/transactions', {'success': true, 'data': {'total': 0, 'transactions': []}});
      api.on('GET', '/transactions/summary/monthly', {
        'success': true,
        'data': {'totalIngresos': 65000, 'totalGastos': 26550, 'balanceNeto': 38450},
      });

      final accounts = AccountProvider();
      final transactions = TransactionProvider();
      await accounts.fetchAccounts();
      await transactions.fetchTransactions();

      await tester.pumpWidget(app(
        Scaffold(
          body: DashboardTab(onNavigateToAccounts: () {}, onNavigateToTransactions: () {}, onNavigateToSimulator: () {}),
        ),
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<AccountProvider>.value(value: accounts),
          ChangeNotifierProvider<TransactionProvider>.value(value: transactions),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('RD\$ 81,849.25'), findsOneWidget); // 75,800 + 6,049.25 (sin la tarjeta)
      expect(find.text('RD\$ 8,700.00'), findsOneWidget); // deuda de la tarjeta
      expect(find.text('Deuda en tarjetas'), findsOneWidget);
      expect(find.text('RD\$ 65,000.00'), findsOneWidget); // ingresos del mes
      expect(find.text('RD\$ 26,550.00'), findsOneWidget); // gastos del mes
    });
  });
}
