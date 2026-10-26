import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, [this.statusCode = 400]);

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

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

    final errorMessage = body is Map && body['message'] != null
        ? body['message'].toString()
        : 'Error inesperado del servidor';
    throw ApiException(errorMessage, response.statusCode);
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
      final response = await http
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('No se pudo conectar al servidor NexoFin en $_baseUrl');
    }
  }

  Future<dynamic> post(String path, dynamic data) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalizedPath');

    try {
      final response = await http
          .post(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con NexoFin API: ${e.toString()}');
    }
  }

  Future<dynamic> put(String path, dynamic data) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalizedPath');

    try {
      final response = await http
          .put(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error al actualizar recurso: ${e.toString()}');
    }
  }

  Future<dynamic> delete(String path) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalizedPath');

    try {
      final response = await http
          .delete(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error al eliminar recurso: ${e.toString()}');
    }
  }
}
