import 'package:flutter_test/flutter_test.dart';
import 'package:nexofin/core/utils/currency_formatter.dart';
import 'package:nexofin/core/utils/date_formatter.dart';
import 'package:nexofin/models/account_model.dart';
import 'package:nexofin/models/transaction_model.dart';
import 'package:nexofin/models/user_model.dart';

void main() {
  group('NexoFin Mobile - Formatos y Reglas de Negocio', () {
    test('CurrencyFormatter formatea montos en RD\$ correctamente', () {
      final res = CurrencyFormatter.format(45000.50);
      expect(res, contains('RD\$'));
      expect(res, contains('45,000.50'));
    });

    test('DateFormatter formatea fechas a formato DD/MM/AAAA', () {
      final formatted = DateFormatter.format('2026-10-26T15:30:00.000Z');
      expect(formatted, equals('26/10/2026'));
    });

    test('UserModel deserializa campos correctamente', () {
      final json = {
        'id': 'usr-123',
        'nombre': 'Brailin Mendez',
        'email': 'brailin@nexofin.com',
        'moneda_predeterminada': 'DOP',
        'zona_horaria': 'America/Santo_Domingo',
      };
      final user = UserModel.fromJson(json);
      expect(user.id, equals('usr-123'));
      expect(user.nombre, equals('Brailin Mendez'));
      expect(user.monedaPredeterminada, equals('DOP'));
    });

    test('AccountModel mapea saldos derivados determinísticos', () {
      final json = {
        'id': 'acc-1',
        'usuario_id': 'usr-1',
        'nombre': 'Cuenta Banreservas',
        'tipo': 'bancaria',
        'moneda': 'DOP',
        'saldo_inicial': '10000.00',
        'saldo_actual': '25500.75',
        'archivada': false,
      };
      final acc = AccountModel.fromJson(json);
      expect(acc.saldoInicial, equals(10000.00));
      expect(acc.saldoActual, equals(25500.75));
      expect(acc.tipo, equals('bancaria'));
    });

    test('TransactionModel detecta transferencias e ingresos', () {
      final trxTransfer = TransactionModel.fromJson({
        'id': 'trx-1',
        'cuenta_id': 'acc-1',
        'tipo': 'transferencia',
        'sentido': 'salida',
        'monto': '1500.00',
        'fecha': '2026-10-26',
        'transferencia_vinculada_id': 'trx-2',
      });
      expect(trxTransfer.isTransfer, isTrue);

      final trxIncome = TransactionModel.fromJson({
        'id': 'trx-3',
        'cuenta_id': 'acc-1',
        'tipo': 'ingreso',
        'sentido': 'entrada',
        'monto': '30000.00',
        'fecha': '2026-10-26',
      });
      expect(trxIncome.isIncome, isTrue);
    });
  });
}
