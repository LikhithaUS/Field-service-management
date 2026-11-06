import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

/// Dependency injection: services are exposed as providers so they can be
/// swapped for fakes in tests via `ProviderScope(overrides: [...])`.
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final apiServiceProvider = Provider<ApiService>(
  (ref) => ApiService(storage: ref.watch(storageServiceProvider)),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    api: ref.watch(apiServiceProvider),
    storage: ref.watch(storageServiceProvider),
  ),
);
