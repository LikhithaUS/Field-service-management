import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import 'service_providers.dart';

/// The app-wide authentication state.
///
/// - `AsyncLoading`      -> checking the stored token on startup (splash screen)
/// - `AsyncData(null)`   -> logged out
/// - `AsyncData(user)`   -> logged in
/// - `AsyncError`        -> couldn't reach the server on startup (splash offers retry)
///
/// The router listens to this provider and redirects automatically, so screens never
/// navigate after login/logout themselves.
final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
  retry: (retryCount, error) => null, // show the error on the splash instead of silently retrying
);

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    ref.read(apiServiceProvider).onUnauthorized = _onSessionExpired;
    return ref.read(authServiceProvider).currentUser();
  }

  /// Throws [ApiException] on failure so the form can show the message.
  /// Errors are deliberately NOT stored in `state`: a failed login is still "logged out".
  Future<void> login({required String email, required String password}) async {
    final user = await ref.read(authServiceProvider).login(email: email, password: password);
    state = AsyncData(user);
  }

  Future<void> register({required String name, required String email, required String password}) async {
    final user = await ref.read(authServiceProvider).register(name: name, email: email, password: password);
    state = AsyncData(user);
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    state = const AsyncData(null);
  }

  void _onSessionExpired() {
    if (state.value == null) return;
    ref.read(authServiceProvider).clearLocalSession();
    state = const AsyncData(null);
  }
}
