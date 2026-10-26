import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';

class TransactionProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<TransactionModel> _transactions = [];
  List<CategoryModel> _categories = [];
  MonthlySummaryModel? _monthlySummary;
  bool _isLoading = false;
  String? _errorMessage;

  List<TransactionModel> get transactions => _transactions;
  List<CategoryModel> get categories => _categories;
  MonthlySummaryModel? get monthlySummary => _monthlySummary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchTransactions({
    String? cuentaId,
    String? tipo,
    String? fechaInicio,
    String? fechaFin,
    String? busqueda,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final query = <String, dynamic>{'limit': 50};
      if (cuentaId != null && cuentaId.isNotEmpty) query['cuenta_id'] = cuentaId;
      if (tipo != null && tipo.isNotEmpty) query['tipo'] = tipo;
      if (fechaInicio != null && fechaInicio.isNotEmpty) query['fecha_inicio'] = fechaInicio;
      if (fechaFin != null && fechaFin.isNotEmpty) query['fecha_fin'] = fechaFin;
      if (busqueda != null && busqueda.isNotEmpty) query['busqueda'] = busqueda;

      final res = await _apiService.get('/transactions', queryParams: query);
      if (res['data'] is List) {
        _transactions = (res['data'] as List)
            .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      await fetchMonthlySummary();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMonthlySummary() async {
    try {
      final res = await _apiService.get('/transactions/summary/monthly');
      if (res['data'] != null) {
        _monthlySummary = MonthlySummaryModel.fromJson(res['data']);
      }
    } catch (_) {}
  }

  Future<void> fetchCategories() async {
    try {
      final res = await _apiService.get('/categories');
      if (res['data'] is List) {
        _categories = (res['data'] as List)
            .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> createTransaction({
    required String cuentaId,
    String? categoriaId,
    required String tipo,
    required double monto,
    required String fecha,
    String? descripcion,
    String? nota,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'cuenta_id': cuentaId,
        'tipo': tipo,
        'monto': monto,
        'fecha': fecha,
      };
      if (categoriaId != null && categoriaId.isNotEmpty) {
        payload['categoria_id'] = categoriaId;
      }
      if (descripcion != null && descripcion.isNotEmpty) {
        payload['descripcion'] = descripcion;
      }
      if (nota != null && nota.isNotEmpty) {
        payload['nota'] = nota;
      }

      final res = await _apiService.post('/transactions', payload);
      if (res['data'] != null) {
        final newTrx = TransactionModel.fromJson(res['data']);
        _transactions.insert(0, newTrx);
      }
      await fetchMonthlySummary();
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

  Future<bool> createTransfer({
    required String cuentaOrigenId,
    required String cuentaDestinoId,
    required double monto,
    required String fecha,
    String? descripcion,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'cuenta_origen_id': cuentaOrigenId,
        'cuenta_destino_id': cuentaDestinoId,
        'monto': monto,
        'fecha': fecha,
      };
      if (descripcion != null && descripcion.isNotEmpty) {
        payload['descripcion'] = descripcion;
      }

      await _apiService.post('/transactions/transfer', payload);
      await fetchTransactions();
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

  Future<bool> deleteTransaction(String id) async {
    try {
      await _apiService.delete('/transactions/$id');
      _transactions.removeWhere((t) => t.id == id);
      await fetchMonthlySummary();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
