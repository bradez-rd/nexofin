import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _dopFormatter = NumberFormat('#,##0.00', 'en_US');

  static String format(num? amount, {String currency = 'DOP'}) {
    if (amount == null) return 'RD\$ 0.00';
    final formattedNumber = _dopFormatter.format(amount);
    if (currency == 'USD') {
      return 'US\$ $formattedNumber';
    }
    return 'RD\$ $formattedNumber';
  }

  static String formatSigned(num? amount, {String currency = 'DOP'}) {
    final formatted = format(amount?.abs(), currency: currency);
    if (amount == null || amount == 0) return formatted;
    return amount > 0 ? '+$formatted' : '-$formatted';
  }
}
