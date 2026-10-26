import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  static const String appName = 'NexoFin AI';
  static const String appTagline = 'Gestión Financiera Inteligente y Determinística';
  
  // Storage keys
  static const String tokenKey = 'nexofin_auth_token';
  static const String userKey = 'nexofin_user_data';
  static const String baseUrlKey = 'nexofin_custom_base_url';

  // Default server URLs
  // On Android emulator, 10.0.2.2 maps to host localhost:3000
  // On Windows/Web, localhost:3000
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api/v1';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000/api/v1';
      }
    } catch (_) {}
    return 'http://localhost:3000/api/v1';
  }

  // Currency
  static const String defaultCurrency = 'DOP';
  static const String currencySymbol = r'RD$';
}
