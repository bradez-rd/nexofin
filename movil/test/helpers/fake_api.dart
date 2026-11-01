import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexofin/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servidor simulado de la API NexoFin para las pruebas: responde con el mismo formato real
/// (`{ success, data: {...} }` / `{ success: false, error: { message } }`) y registra cada petición.
class FakeApi {
  final Map<String, http.Response Function(http.Request)> _routes = {};
  final List<http.Request> calls = [];

  static const _headers = {'content-type': 'application/json; charset=utf-8'};

  /// Registra una respuesta para `METODO /ruta` (la ruta va sin el prefijo /api/v1).
  void on(String method, String path, Object body, {int status = 200}) {
    _routes['$method $path'] = (_) => http.Response(jsonEncode(body), status, headers: _headers);
  }

  void onError(String method, String path, String message, {int status = 400}) {
    on(method, path, {
      'success': false,
      'error': {'code': 'Error', 'message': message},
    }, status: status);
  }

  /// Simula que no hay conexión con el servidor.
  void onNetworkDown(String method, String path) {
    _routes['$method $path'] = (_) => throw http.ClientException('sin conexión');
  }

  Iterable<http.Request> callsTo(String method, String path) =>
      calls.where((r) => r.method == method && r.url.path.endsWith('/api/v1$path'));

  Map<String, dynamic> bodyOf(http.Request r) => jsonDecode(r.body) as Map<String, dynamic>;

  /// Conecta el ApiService global con este servidor simulado y deja una sesión iniciada.
  Future<void> install({bool loggedIn = true}) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiService();
    await api.setBaseUrl('http://api.test/api/v1');
    await api.setToken(loggedIn ? 'token-de-prueba' : null);
    api.client = MockClient((req) async {
      calls.add(req);
      final path = req.url.path.replaceFirst('/api/v1', '');
      final handler = _routes['${req.method} $path'];
      if (handler == null) {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {'message': 'Ruta no simulada: ${req.method} $path'},
          }),
          404,
          headers: _headers,
        );
      }
      return handler(req);
    });
  }
}

// ---- Datos de ejemplo con la misma forma que devuelve la API real ----

Map<String, dynamic> accountJson(String id, String nombre, String tipo, num saldo,
    {num? limite, int? corte, int? pago}) {
  return {
    'id': id,
    'usuario_id': 'u-1',
    'nombre': nombre,
    'tipo': tipo,
    'moneda': 'DOP',
    'saldo_inicial': saldo,
    'saldo_actual': saldo,
    'limite_credito': limite,
    'dia_corte': corte,
    'dia_pago': pago,
    'archivada': false,
  };
}

Map<String, dynamic> txJson(String id, String cuentaId, String tipo, num monto, String fecha,
    {String sentido = 'salida', String? categoriaId, String? descripcion, String? vinculada}) {
  return {
    'id': id,
    'usuario_id': 'u-1',
    'cuenta_id': cuentaId,
    'categoria_id': categoriaId,
    'tipo': tipo,
    'sentido': sentido,
    'monto': monto,
    'fecha': fecha,
    'descripcion': descripcion,
    'nota': null,
    'transferencia_vinculada_id': vinculada,
  };
}

Map<String, dynamic> categoryJson(String id, String nombre, String tipo, {String color = '#F97316'}) {
  return {'id': id, 'nombre': nombre, 'tipo': tipo, 'icono': 'shopping_cart', 'color': color, 'es_sistema': true};
}
