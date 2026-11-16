import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';

/// Shown while the stored token is checked. The router moves on automatically once
/// the auth state resolves; if the server is unreachable, offers a retry.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 80),
              const SizedBox(height: 20),
              Text('ServiceHub', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 32),
              if (auth.hasError) ...[
                Text(
                  auth.error is ApiException ? (auth.error as ApiException).message : 'Something went wrong.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => ref.invalidate(authControllerProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ] else
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
