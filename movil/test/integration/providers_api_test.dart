import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexofin/models/history_filter.dart';
import 'package:nexofin/providers/account_provider.dart';
import 'package:nexofin/providers/auth_provider.dart';
import 'package:nexofin/providers/transaction_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_api.dart';

/// Pruebas de integración cliente <-> API: los providers reales hablan con un servidor simulado que
/// responde con el mismo formato que la API NexoFin. Habrían detectado el error en que el dashboard
/// salía vacío porque la app esperaba listas donde la API devuelve objetos envueltos.
void main() {
  late FakeApi api;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    api = FakeApi();
    await api.install();
  });

  group('Cuentas', () {
    test('IF-01 · fetchAccounts lee data.accounts y el consolidado data.summary', () async {
      api.on('GET', '/accounts', {
        'success': true,
        'data': {
          'total': 3,
          'accounts': [
            accountJson('a1', 'Banco Popular', 'bancaria', 75800),
            accountJson('a2', 'Efectivo', 'efectivo', 6049.25),
            accountJson('a3', 'Visa', 'tarjeta', -8700, limite: 80000, corte: 25, pago: 15),
          ],
        },
      });
      api.on('GET', '/accounts/summary/balances', {
        'success': true,
        'data': {
          'summary': [
            {'moneda': 'DOP', 'total_saldo': 73149.25, 'cantidad_cuentas': 3},
          ],
        },
      });

      final provider = AccountProvider();
      await provider.fetchAccounts();

      expect(provider.accounts.length, 3);
      expect(provider.nameOf('a2'), 'Efectivo');
      expect(provider.nameOf('desconocida'), 'Cuenta');
      expect(provider.accounts.last.diaCorte, 25);
      expect(provider.totalNetWorthDOP, 73149.25);
      expect(provider.errorMessage, isNull);
    });

    test('IF-02 · createAccount envía los datos de tarjeta y agrega la cuenta devuelta en data.account', () async {
      api.on('POST', '/accounts', {
        'success': true,
        'data': {'account': accountJson('n1', 'Mastercard', 'tarjeta', 0, limite: 50000, corte: 20, pago: 10)},
      });
      api.on('GET', '/accounts/summary/balances', {'success': true, 'data': {'summary': []}});

      final provider = AccountProvider();
      final ok = await provider.createAccount(
        nombre: 'Mastercard', tipo: 'tarjeta', limiteCredito: 50000, diaCorte: 20, diaPago: 10,
      );

      expect(ok, true);
      expect(provider.accounts.single.nombre, 'Mastercard');
      final body = api.bodyOf(api.callsTo('POST', '/accounts').single);
      expect(body['limite_credito'], 50000);
      expect(body['dia_corte'], 20);
      expect(body['dia_pago'], 10);
      expect(body['tipo'], 'tarjeta');
    });

    test('IF-03 · updateAccount envía solo los campos editados', () async {
      api.on('PUT', '/accounts/a1', {'success': true, 'data': {'account': accountJson('a1', 'Nuevo nombre', 'bancaria', 10)}});
      api.on('GET', '/accounts', {'success': true, 'data': {'accounts': [accountJson('a1', 'Nuevo nombre', 'bancaria', 10)]}});
      api.on('GET', '/accounts/summary/balances', {'success': true, 'data': {'summary': []}});

      final provider = AccountProvider();
      expect(await provider.updateAccount('a1', nombre: 'Nuevo nombre'), true);
      expect(api.bodyOf(api.callsTo('PUT', '/accounts/a1').single), {'nombre': 'Nuevo nombre'});
      expect(provider.nameOf('a1'), 'Nuevo nombre');
    });
  });

  group('Transacciones', () {
    setUp(() {
      api.on('GET', '/categories', {
        'success': true,
        'data': {
          'total': 2,
          'categories': [
            categoryJson('k1', 'Alimentación y Supermercado', 'gasto', color: '#F97316'),
            categoryJson('k2', 'Salario / Nómina', 'ingreso', color: '#047857'),
          ],
        },
      });
      api.on('GET', '/transactions/summary/monthly', {
        'success': true,
        'data': {'totalIngresos': 65000, 'totalGastos': 26550, 'balanceNeto': 38450, 'periodo': '2026-10'},
      });
    });

    test('IF-04 · fetchTransactions lee data.transactions y el resumen mensual; las categorías resuelven nombre y color', () async {
      api.on('GET', '/transactions', {
        'success': true,
        'data': {
          'total': 2, 'limit': 50, 'offset': 0,
          'transactions': [
            txJson('t1', 'a1', 'gasto', 3450, '2026-10-25', categoriaId: 'k1', descripcion: 'Supermercados Bravo'),
            txJson('t2', 'a1', 'ingreso', 32500, '2026-10-23', sentido: 'entrada', categoriaId: 'k2'),
          ],
        },
      });

      final provider = TransactionProvider();
      await provider.fetchCategories();
      await provider.fetchTransactions();

      expect(provider.transactions.length, 2);
      expect(provider.monthlySummary?.ingresos, 65000);
      expect(provider.monthlySummary?.balanceNeto, 38450);
      expect(provider.categoryNameOf('k1'), 'Alimentación y Supermercado');
      expect(provider.categoryNameOf(null), isNull);
      expect(provider.categoryColorOf('k1'), const Color(0xFFF97316));
    });

    test('IF-05 · el historial pagina de 20 en 20, marca si hay más y agrega la página siguiente', () async {
      final first = List.generate(20, (i) => txJson('t$i', 'a1', 'gasto', 10 + i, '2026-10-25'));
      final second = List.generate(5, (i) => txJson('u$i', 'a1', 'gasto', 100 + i, '2026-10-20'));
      api.on('GET', '/transactions', {
        'success': true, 'data': {'total': 25, 'limit': 20, 'offset': 0, 'transactions': first},
      });

      final provider = TransactionProvider();
      await provider.fetchHistory();
      expect(provider.history.length, 20);
      expect(provider.historyTotal, 25);
      expect(provider.historyHasMore, true);

      api.on('GET', '/transactions', {
        'success': true, 'data': {'total': 25, 'limit': 20, 'offset': 20, 'transactions': second},
      });
      await provider.loadMoreHistory();
      expect(provider.history.length, 25);
      expect(provider.historyHasMore, false);
      expect(api.callsTo('GET', '/transactions').last.url.queryParameters['offset'], '20');
    });

    test('IF-06 · aplicar filtros reinicia la lista y envía tipo, cuenta y fechas a la API', () async {
      api.on('GET', '/transactions', {
        'success': true, 'data': {'total': 0, 'limit': 20, 'offset': 0, 'transactions': []},
      });
      final provider = TransactionProvider();
      await provider.fetchHistory(
        filter: HistoryFilter(tipo: 'gasto', cuentaId: 'a1', desde: DateTime(2026, 10, 1), hasta: DateTime(2026, 10, 31)),
      );
      final q = api.callsTo('GET', '/transactions').last.url.queryParameters;
      expect(q['tipo'], 'gasto');
      expect(q['cuenta_id'], 'a1');
      expect(q['fecha_inicio'], '2026-10-01');
      expect(q['fecha_fin'], '2026-10-31');
      expect(q['limit'], '20');
      expect(provider.history, isEmpty);
    });

    test('IF-07 · un ajuste envía el sentido elegido y no lleva categoría; una transferencia usa su endpoint', () async {
      api.on('POST', '/transactions', {'success': true, 'data': {'transaction': txJson('n1', 'a1', 'ajuste', 50, '2026-10-26', sentido: 'entrada')}});
      api.on('POST', '/transactions/transfer', {'success': true, 'data': {'salida': {}, 'entrada': {}}});
      api.on('GET', '/transactions', {'success': true, 'data': {'total': 0, 'transactions': []}});

      final provider = TransactionProvider();
      expect(
        await provider.createTransaction(cuentaId: 'a1', tipo: 'ajuste', monto: 50, fecha: '2026-10-26', sentido: 'entrada'),
        true,
      );
      final body = api.bodyOf(api.callsTo('POST', '/transactions').single);
      expect(body['sentido'], 'entrada');
      expect(body.containsKey('categoria_id'), false);

      expect(
        await provider.createTransfer(cuentaOrigenId: 'a1', cuentaDestinoId: 'a2', monto: 8700, fecha: '2026-10-26', descripcion: 'Pago de tarjeta'),
        true,
      );
      final t = api.bodyOf(api.callsTo('POST', '/transactions/transfer').single);
      expect(t['cuenta_origen_id'], 'a1');
      expect(t['cuenta_destino_id'], 'a2');
      expect(t['monto'], 8700);
    });

    test('IF-08 · updateTransaction envía solo lo editado y recarga las listas', () async {
      api.on('PUT', '/transactions/t1', {'success': true, 'data': {'transaction': txJson('t1', 'a1', 'ingreso', 33000, '2026-10-23', sentido: 'entrada')}});
      api.on('GET', '/transactions', {'success': true, 'data': {'total': 1, 'transactions': [txJson('t1', 'a1', 'ingreso', 33000, '2026-10-23', sentido: 'entrada')]}});

      final provider = TransactionProvider();
      expect(await provider.updateTransaction('t1', monto: 33000, descripcion: 'Nómina'), true);
      expect(api.bodyOf(api.callsTo('PUT', '/transactions/t1').single), {'monto': 33000, 'descripcion': 'Nómina'});
      expect(provider.transactions.single.monto, 33000);
      expect(provider.history.single.monto, 33000);
    });

    test('IF-09 · eliminar una transacción la quita del historial y descuenta el total', () async {
      api.on('GET', '/transactions', {'success': true, 'data': {'total': 2, 'transactions': [
        txJson('t1', 'a1', 'gasto', 10, '2026-10-25'),
        txJson('t2', 'a1', 'gasto', 20, '2026-10-25'),
      ]}});
      api.on('DELETE', '/transactions/t1', {'success': true, 'message': 'ok'});

      final provider = TransactionProvider();
      await provider.fetchTransactions();
      await provider.fetchHistory();
      expect(await provider.deleteTransaction('t1'), true);
      expect(provider.history.map((t) => t.id), ['t2']);
      expect(provider.historyTotal, 1);
      expect(provider.transactions.map((t) => t.id), ['t2']);
    });

    test('IF-15 · eliminar una transferencia quita de la lista las dos patas, no solo la que se tocó', () async {
      api.on('GET', '/transactions', {'success': true, 'data': {'total': 3, 'transactions': [
        txJson('s1', 'a1', 'transferencia', 8700, '2026-10-30', vinculada: 'e1'),
        txJson('e1', 'a3', 'transferencia', 8700, '2026-10-30', sentido: 'entrada', vinculada: 's1'),
        txJson('g1', 'a1', 'gasto', 50, '2026-10-29'),
      ]}});
      api.on('DELETE', '/transactions/s1', {'success': true, 'message': 'ok'});

      final provider = TransactionProvider();
      await provider.fetchTransactions();
      await provider.fetchHistory();
      expect(await provider.deleteTransaction('s1'), true);
      expect(provider.history.map((t) => t.id), ['g1']);
      expect(provider.transactions.map((t) => t.id), ['g1']);
      expect(provider.historyTotal, 1);
    });
  });

  group('Sesión y errores del servidor', () {
    test('IF-10 · login correcto guarda el token y el usuario que vienen en data.user', () async {
      api.on('POST', '/auth/login', {
        'success': true,
        'data': {
          'token': 'jwt-nuevo',
          'user': {'id': 'u-1', 'nombre': 'Paola Piantini', 'email': 'paola@itla.edu.do', 'moneda_predeterminada': 'DOP', 'zona_horaria': 'America/Santo_Domingo'},
        },
      });
      final auth = AuthProvider();
      expect(await auth.login('paola@itla.edu.do', 'ClaveSegura2026'), true);
      expect(auth.currentUser?.nombre, 'Paola Piantini');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('nexofin_auth_token'), 'jwt-nuevo');
    });

    test('IF-11 · credenciales inválidas: muestra el mensaje real de la API (error.message), no un texto genérico', () async {
      api.onError('POST', '/auth/login', 'Credenciales inválidas', status: 401);
      final auth = AuthProvider();
      expect(await auth.login('x@y.com', 'mala-clave-123'), false);
      expect(auth.errorMessage, 'Credenciales inválidas');
      expect(auth.currentUser, isNull);
    });

    test('IF-12 · cuenta bloqueada y límite de intentos (429) muestran el mensaje del servidor', () async {
      api.onError('POST', '/auth/login', 'Cuenta temporalmente bloqueada por seguridad tras 5 intentos fallidos. Intente nuevamente en 15 minuto(s).', status: 401);
      final auth = AuthProvider();
      await auth.login('x@y.com', 'clave-123456');
      expect(auth.errorMessage, contains('bloqueada'));

      api.onError('POST', '/auth/login', 'Demasiados intentos de inicio de sesión. Espera un minuto e inténtalo de nuevo.', status: 429);
      await auth.login('x@y.com', 'clave-123456');
      expect(auth.errorMessage, contains('Demasiados intentos'));
    });

    test('IF-13 · sin conexión con el servidor: mensaje claro en español, sin detalles técnicos', () async {
      api.onNetworkDown('POST', '/auth/login');
      final auth = AuthProvider();
      expect(await auth.login('x@y.com', 'clave-123456'), false);
      expect(auth.errorMessage, isNotNull);
      expect(auth.errorMessage, isNot(contains('Exception')));
    });

    test('IF-14 · checkSession recupera el usuario de data.user y restaura la sesión guardada', () async {
      SharedPreferences.setMockInitialValues({
        'nexofin_auth_token': 'jwt-guardado',
        'nexofin_user_data': '{"id":"u-1","nombre":"Cache","email":"c@c.com"}',
      });
      api.on('GET', '/auth/profile', {
        'success': true,
        'data': {'user': {'id': 'u-1', 'nombre': 'Carlos Demo', 'email': 'carlos@demo.com', 'moneda_predeterminada': 'DOP', 'zona_horaria': 'America/Santo_Domingo'}},
      });
      final auth = AuthProvider();
      expect(await auth.checkSession(), true);
      expect(auth.currentUser?.nombre, 'Carlos Demo');
    });
  });
}
