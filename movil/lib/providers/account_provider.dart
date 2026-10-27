import 'package:flutter/foundation.dart';
import '../models/account_model.dart';
import '../services/api_service.dart';

class AccountProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<AccountModel> _accounts = [];
  List<BalanceSummaryModel> _summaries = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AccountModel> get accounts => _accounts;
  List<BalanceSummaryModel> get summaries => _summaries;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get totalNetWorthDOP {
    final dopSummary = _summaries.firstWhere(
      (s) => s.moneda == 'DOP',
      orElse: () => BalanceSummaryModel(moneda: 'DOP', patrimonioNeto: 0, totalCuentas: 0),
    );
    if (dopSummary.patrimonioNeto != 0) {
      return dopSummary.patrimonioNeto;
    }
    // Fallback: sum of accounts in DOP
    return _accounts
        .where((a) => a.moneda == 'DOP')
        .fold(0.0, (acc, item) => acc + item.saldoActual);
  }

  /// La API envuelve los resultados: `data: { accounts: [...] }`.
  /// También se acepta una lista directa por compatibilidad.
  List<dynamic> _extractList(dynamic data, String key) {
    if (data is List) return data;
    if (data is Map && data[key] is List) return data[key] as List;
    return const [];
  }

  Map<String, dynamic>? _extractObject(dynamic data, String key) {
    if (data is Map<String, dynamic>) {
      final inner = data[key];
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    return null;
  }

  /// Nombre de la cuenta a partir de su ID (la API devuelve solo el ID en cada transacción).
  String nameOf(String id) {
    for (final a in _accounts) {
      if (a.id == id) return a.nombre;
    }
    return 'Cuenta';
  }

  Future<void> fetchAccounts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.get('/accounts');
      final list = _extractList(res['data'], 'accounts');
      _accounts = list
          .map((item) => AccountModel.fromJson(item as Map<String, dynamic>))
          .toList();
      await fetchBalancesSummary();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBalancesSummary() async {
    try {
      final res = await _apiService.get('/accounts/summary/balances');
      final list = _extractList(res['data'], 'summary');
      _summaries = list
          .map((item) => BalanceSummaryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<bool> createAccount({
    required String nombre,
    required String tipo,
    String moneda = 'DOP',
    double saldoInicial = 0.0,
    double? limiteCredito,
    int? diaCorte,
    int? diaPago,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'nombre': nombre.trim(),
        'tipo': tipo,
        'moneda': moneda,
        'saldo_inicial': saldoInicial,
      };
      if (limiteCredito != null && limiteCredito > 0) {
        payload['limite_credito'] = limiteCredito;
      }
      if (diaCorte != null) payload['dia_corte'] = diaCorte;
      if (diaPago != null) payload['dia_pago'] = diaPago;

      final res = await _apiService.post('/accounts', payload);
      final created = _extractObject(res['data'], 'account');
      if (created != null) {
        _accounts.insert(0, AccountModel.fromJson(created));
      }
      await fetchBalancesSummary();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Edita nombre y datos de tarjeta (la API no permite cambiar tipo ni moneda).
  Future<bool> updateAccount(
    String id, {
    String? nombre,
    double? limiteCredito,
    int? diaCorte,
    int? diaPago,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (nombre != null) payload['nombre'] = nombre.trim();
      if (limiteCredito != null) payload['limite_credito'] = limiteCredito;
      if (diaCorte != null) payload['dia_corte'] = diaCorte;
      if (diaPago != null) payload['dia_pago'] = diaPago;
      await _apiService.put('/accounts/$id', payload);
      await fetchAccounts();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> archiveAccount(String id) async {
    try {
      await _apiService.delete('/accounts/$id');
      _accounts.removeWhere((acc) => acc.id == id);
      await fetchBalancesSummary();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
