import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  /// Contenido del objeto `error` de la respuesta (por ejemplo, las columnas a mapear en una importación).
  final Map<String, dynamic>? details;

  ApiException(this.message, [this.statusCode = 400, this.details]);

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  http.Client _client = http.Client();

  /// Permite sustituir el cliente HTTP en las pruebas (por ejemplo, con un servidor simulado).
  @visibleForTesting
  set client(http.Client value) => _client = value;

  String _baseUrl = AppConstants.defaultBaseUrl;
  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = prefs.getString(AppConstants.baseUrlKey);
    if (savedBaseUrl != null && savedBaseUrl.trim().isNotEmpty) {
      _baseUrl = savedBaseUrl.trim();
    }
    _token = prefs.getString(AppConstants.tokenKey);
  }

  Future<void> setBaseUrl(String newUrl) async {
    _baseUrl = newUrl.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.baseUrlKey, _baseUrl);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(AppConstants.tokenKey, token);
    } else {
      await prefs.remove(AppConstants.tokenKey);
    }
  }

  /// Mensaje para fallos de red o de tiempo de espera: sin detalles técnicos (RNF-USA-06).
  String get _connectionMessage =>
      'No se pudo conectar con el servidor de NexoFin. Revisa tu conexión e inténtalo de nuevo.';

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  dynamic _processResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException(
        'Error de comunicación con el servidor (${response.statusCode})',
        response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    // La API responde `{ success: false, error: { message, details } }`.
    String? serverMessage;
    Map<String, dynamic>? errorBody;
    if (body is Map) {
      final err = body['error'];
      if (err is Map && err['message'] != null) {
        serverMessage = err['message'].toString();
        errorBody = Map<String, dynamic>.from(err);
      } else if (body['message'] != null) {
        serverMessage = body['message'].toString();
      }
    }
    final errorMessage = serverMessage ?? 'Error inesperado del servidor';
    throw ApiException(errorMessage, response.statusCode, errorBody);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    Uri uri;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$_baseUrl$normalizedPath';

    if (queryParams != null && queryParams.isNotEmpty) {
      final cleanParams = queryParams.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      uri = Uri.parse(fullUrl).replace(queryParameters: cleanParams);
    } else {
      uri = Uri.parse(fullUrl);
    }

    try {
      final response = await _client
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_connectionMessage);
    }
  }

  /// Descarga un archivo (reportes en CSV, Excel o PDF) como bytes.
  Future<List<int>> download(String path, {Map<String, dynamic>? queryParams}) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    var uri = Uri.parse('$_baseUrl$normalizedPath');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())));
    }
    try {
      final response = await _client.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 30));
      if (response.statusCode >= 200 && response.statusCode < 300) return response.bodyBytes;
      _processResponse(response); // lanza ApiException con el mensaje del servidor
      throw ApiException('No se pudo descargar el archivo', response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_connectionMessage);
    }
  }

  Future<dynamic> post(String path, dynamic data) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalizedPath');

    try {
      final response = await _client
          .post(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_connectionMessage);
    }
  }

  Future<dynamic> put(String path, dynamic data) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalizedPath');

    try {
      final response = await _client
          .put(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_connectionMessage);
    }
  }

  Future<dynamic> delete(String path, {Object? body}) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalizedPath');

    try {
      final response = await _client
          .delete(uri, headers: _buildHeaders(), body: body == null ? null : jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_connectionMessage);
    }
  }
}
