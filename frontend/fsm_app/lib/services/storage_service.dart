import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT between app launches.
///
/// Uses the platform's secure store (Android Keystore, iOS Keychain, Windows Credential
/// Manager; encrypted browser storage on web) rather than plain SharedPreferences.
class StorageService {
  StorageService([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'auth_token';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
