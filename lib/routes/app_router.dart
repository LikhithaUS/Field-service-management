import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';

  static const _public = {login, register};
}

/// The router is created once. Instead of rebuilding it on auth changes (which would
/// reset navigation), auth state is mirrored into a [ValueNotifier] that GoRouter
/// listens to; every change re-runs [redirect].
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ValueNotifier<AsyncValue<User?>>(const AsyncLoading());
  ref.listen(authControllerProvider, (_, next) => authState.value = next, fireImmediately: true);
  ref.onDispose(authState.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authState,
    redirect: (context, state) {
      final auth = authState.value;
      final location = state.matchedLocation;

      // Still checking the stored token, or the server was unreachable.
      if (auth.isLoading || auth.hasError) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final loggedIn = auth.value != null;
      final onPublic = AppRoutes._public.contains(location);

      if (!loggedIn) return onPublic ? null : AppRoutes.login;
      if (onPublic || location == AppRoutes.splash) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: AppRoutes.dashboard, builder: (context, state) => const DashboardScreen()),
    ],
  );
});
