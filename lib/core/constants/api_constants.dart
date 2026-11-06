import 'package:flutter/foundation.dart';

/// Where the app finds the ServiceHub backend.
///
/// Override at build/run time without touching code:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com/api
class ApiConstants {
  ApiConstants._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:5000/api';
    // The Android emulator reaches the host machine's localhost via 10.0.2.2.
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5000/api';
    return 'http://localhost:5000/api';
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Resources
  static const String employees = '/employees';
  static const String departments = '/departments';
}
