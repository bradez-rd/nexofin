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

  Future<void> fetchAccounts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.get('/accounts');
      if (res['data'] is List) {
        _accounts = (res['data'] as List)
            .map((item) => AccountModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
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
      if (res['data'] is List) {
        _summaries = (res['data'] as List)
            .map((item) => BalanceSummaryModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  Future<bool> createAccount({
    required String nombre,
    required String tipo,
    String moneda = 'DOP',
    double saldoInicial = 0.0,
    double? limiteCredito,
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

      final res = await _apiService.post('/accounts', payload);
      if (res['data'] != null) {
        final newAccount = AccountModel.fromJson(res['data']);
        _accounts.insert(0, newAccount);
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
