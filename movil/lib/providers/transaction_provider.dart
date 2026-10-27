import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import '../models/category_model.dart';
import '../models/history_filter.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';

class TransactionProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<TransactionModel> _transactions = [];
  List<CategoryModel> _categories = [];
  MonthlySummaryModel? _monthlySummary;
  bool _isLoading = false;
  String? _errorMessage;

  // Historial (pestaña Movimientos): filtros y paginación propios, separados de la
  // lista reciente que usa el dashboard.
  static const int _pageSize = 20;
  List<TransactionModel> _history = [];
  int _historyTotal = 0;
  bool _historyLoading = false;
  HistoryFilter _historyFilter = const HistoryFilter();

  List<TransactionModel> get history => _history;
  int get historyTotal => _historyTotal;
  bool get historyLoading => _historyLoading;
  bool get historyHasMore => _history.length < _historyTotal;
  HistoryFilter get historyFilter => _historyFilter;

  List<TransactionModel> get transactions => _transactions;
  List<CategoryModel> get categories => _categories;
  MonthlySummaryModel? get monthlySummary => _monthlySummary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// La API envuelve los resultados: `data: { transactions: [...] }`.
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

  /// Nombre de categoría a partir de las categorías ya cargadas
  /// (la API no devuelve el nombre dentro de cada transacción).
  String? categoryNameOf(String? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c.nombre;
    }
    return null;
  }

  static const _fallbackPalette = [
    Color(0xFF005F49), Color(0xFF4E45D5), Color(0xFF0071AC), Color(0xFFB45309),
    Color(0xFFB91C1C), Color(0xFF7C3AED), Color(0xFF0F766E),
  ];

  /// Color de la categoría (campo `color` de la API, p. ej. `#F97316`).
  Color categoryColorOf(String? id) {
    for (final c in _categories) {
      if (c.id == id && c.color != null) {
        final hex = c.color!.replaceFirst('#', '');
        final value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
        if (value != null) return Color(value);
      }
    }
    return _fallbackPalette[(id ?? '').hashCode.abs() % _fallbackPalette.length];
  }

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
      final list = _extractList(res['data'], 'transactions');
      _transactions = list
          .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
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
      final list = _extractList(res['data'], 'categories');
      _categories = list
          .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchHistory({HistoryFilter? filter}) async {
    if (filter != null) _historyFilter = filter;
    _historyLoading = true;
    notifyListeners();
    try {
      final res = await _apiService.get(
        '/transactions',
        queryParams: _historyFilter.toQuery(limit: _pageSize),
      );
      final data = res['data'];
      _history = _extractList(data, 'transactions')
          .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
      _historyTotal = data is Map ? int.tryParse('${data['total']}') ?? _history.length : _history.length;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreHistory() async {
    if (_historyLoading || !historyHasMore) return;
    _historyLoading = true;
    notifyListeners();
    try {
      final res = await _apiService.get(
        '/transactions',
        queryParams: _historyFilter.toQuery(limit: _pageSize, offset: _history.length),
      );
      final data = res['data'];
      _history = [
        ..._history,
        ..._extractList(data, 'transactions')
            .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>)),
      ];
      if (data is Map) _historyTotal = int.tryParse('${data['total']}') ?? _historyTotal;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }

  /// Edita monto, fecha, descripción, nota o categoría (la API no permite cambiar tipo ni cuenta).
  Future<bool> updateTransaction(
    String id, {
    String? categoriaId,
    double? monto,
    String? fecha,
    String? descripcion,
    String? nota,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (categoriaId != null) payload['categoria_id'] = categoriaId;
      if (monto != null) payload['monto'] = monto;
      if (fecha != null) payload['fecha'] = fecha;
      if (descripcion != null) payload['descripcion'] = descripcion;
      if (nota != null) payload['nota'] = nota;
      await _apiService.put('/transactions/$id', payload);
      await fetchTransactions();
      await fetchHistory();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createTransaction({
    required String cuentaId,
    String? categoriaId,
    required String tipo,
    required double monto,
    required String fecha,
    String? descripcion,
    String? nota,
    String? sentido, // solo para ajustes: entrada | salida
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
      if (sentido != null) {
        payload['sentido'] = sentido;
      }

      final res = await _apiService.post('/transactions', payload);
      final created = _extractObject(res['data'], 'transaction');
      if (created != null) {
        _transactions.insert(0, TransactionModel.fromJson(created));
      }
      await Future.wait([fetchMonthlySummary(), fetchHistory()]);
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
      await Future.wait([fetchTransactions(), fetchHistory()]);
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
      final before = _history.length;
      _history.removeWhere((t) => t.id == id);
      if (_history.length < before && _historyTotal > 0) _historyTotal--;
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
