import '../core/constants/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Talks to the backend's /api/auth endpoints and manages the stored token.
class AuthService {
  AuthService({required this._api, required this._storage});

  final ApiService _api;
  final StorageService _storage;

  Future<User> login({required String email, required String password}) async {
    final body = await _api.post(ApiConstants.login, data: {'email': email.trim(), 'password': password});
    return _saveSession(body);
  }

  Future<User> register({required String name, required String email, required String password}) async {
    final body = await _api.post(
      ApiConstants.register,
      data: {'name': name.trim(), 'email': email.trim(), 'password': password},
    );
    return _saveSession(body);
  }

  /// Restores the session on app start. Returns null when there is no valid token.
  Future<User?> currentUser() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) return null;
    try {
      final body = await _api.get(ApiConstants.me);
      return User.fromJson((body['data'] as Map)['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _storage.clearToken();
        return null;
      }
      rethrow; // e.g. server unreachable: let the UI offer a retry
    }
  }

  /// Revokes the token on the server (best effort) and always clears it locally.
  Future<void> logout() async {
    try {
      await _api.post(ApiConstants.logout);
    } on ApiException {
      // Offline or already expired: logging out locally is still correct.
    } finally {
      await _storage.clearToken();
    }
  }

  Future<void> clearLocalSession() => _storage.clearToken();

  /// Asks the backend to email a 6-digit code. Returns the server's (deliberately generic) message.
  Future<String> forgotPassword(String email) async {
    final body = await _api.post(ApiConstants.forgotPassword, data: {'email': email.trim()});
    return body['message'] as String? ?? 'If an account exists for that email, a reset code has been sent.';
  }

  /// Sets a new password using the emailed code; the backend also logs the user in.
  Future<User> resetPassword({required String email, required String code, required String password}) async {
    final body = await _api.post(
      ApiConstants.resetPassword,
      data: {'email': email.trim(), 'code': code.trim(), 'password': password},
    );
    return _saveSession(body);
  }

  Future<User> _saveSession(Map<String, dynamic> body) async {
    final data = body['data'] as Map<String, dynamic>;
    await _storage.saveToken(data['token'] as String);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }
}
