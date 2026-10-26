import 'package:intl/intl.dart';

class DateFormatter {
  static String format(dynamic date) {
    if (date == null) return '';
    DateTime dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      try {
        dt = DateTime.parse(date);
      } catch (_) {
        return date;
      }
    } else {
      return '';
    }
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  static String toApiDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }
}
