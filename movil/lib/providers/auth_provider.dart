import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _apiService.token != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);
      final userRaw = prefs.getString(AppConstants.userKey);

      if (token != null && token.isNotEmpty) {
        await _apiService.setToken(token);
        if (userRaw != null) {
          _currentUser = UserModel.fromJson(jsonDecode(userRaw));
        }

        // Verify with remote profile
        try {
          final res = await _apiService.get('/auth/profile');
          if (res['data'] != null) {
            _currentUser = UserModel.fromJson(res['data']);
            await prefs.setString(AppConstants.userKey, jsonEncode(_currentUser!.toJson()));
          }
        } catch (_) {
          // If offline or token expired, keep cached user or logout if 401
        }

        _isLoading = false;
        notifyListeners();
        return _currentUser != null;
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.post('/auth/login', {
        'email': email.trim(),
        'password': password,
      });

      final data = res['data'];
      final token = data['token']?.toString();
      final userData = data['user'];

      if (token == null || userData == null) {
        throw ApiException('Respuesta de autenticación incompleta');
      }

      await _apiService.setToken(token);
      _currentUser = UserModel.fromJson(userData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(_currentUser!.toJson()));

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

  Future<bool> register({
    required String nombre,
    required String email,
    required String password,
    String moneda = 'DOP',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.post('/auth/register', {
        'nombre': nombre.trim(),
        'email': email.trim(),
        'password': password,
        'moneda_predeterminada': moneda,
        'zona_horaria': 'America/Santo_Domingo',
      });

      final data = res['data'];
      final token = data['token']?.toString();
      final userData = data['user'];

      if (token != null && userData != null) {
        await _apiService.setToken(token);
        _currentUser = UserModel.fromJson(userData);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.userKey, jsonEncode(_currentUser!.toJson()));
      }

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

  Future<void> logout() async {
    _currentUser = null;
    await _apiService.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userKey);
    notifyListeners();
  }
}
