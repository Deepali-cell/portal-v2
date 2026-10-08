import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/tenant/application/tenant_controller.dart';
import 'config/app_config.dart';
import 'network/dio_client.dart';
import 'storage/secure_store.dart';

// Re-export the secure store provider so existing imports keep working.
export 'storage/secure_store.dart' show secureStoreProvider;

/// Resolves the server URL Dio should target right now.
///
/// Order of preference:
///   1. The active tenant's `server_url` (the SaaS path).
///   2. `TCB_DEFAULT_TENANT_URL` if set at build time (dev convenience).
///   3. An empty string — Dio will fail any request, which is correct because
///      no UI gates a call before tenant resolve except the resolve itself
///      (which uses its own dedicated Dio against the middleware).
final currentServerUrlProvider = Provider<String>((ref) {
  final tenant = ref.watch(tenantControllerProvider);
  if (tenant != null && tenant.serverUrl.isNotEmpty) return tenant.serverUrl;
  return AppConfig.defaultTenantServerUrl;
});

/// Owns the configured Dio instance. Rebuilds whenever the active tenant
/// changes so every subsequent request hits the right ERPNext.
///
/// On a 401 the [onUnauthorized] closure forces sign-out. The auth controller
/// is read lazily (only when 401 actually fires) so there is no build-time
/// dependency cycle with [authControllerProvider].
final dioClientProvider = Provider<DioClient>((ref) {
  final store = ref.watch(secureStoreProvider);
  final serverUrl = ref.watch(currentServerUrlProvider);
  return DioClient(
    store,
    serverUrl: serverUrl,
    onUnauthorized: () =>
        ref.read(authControllerProvider.notifier).forceLogout(),
  );
});

final dioProvider = Provider<Dio>((ref) => ref.watch(dioClientProvider).dio);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(dioProvider),
    ref.watch(secureStoreProvider),
    ref.watch(currentServerUrlProvider),
  ),
);
