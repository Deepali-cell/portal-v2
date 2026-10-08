import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_store.dart';
import '../data/tenant_repository.dart';
import '../domain/tenant.dart';

final tenantRepositoryProvider = Provider<TenantRepository>(
    (ref) => TenantRepository(ref.read(secureStoreProvider)));

final tenantControllerProvider =
    NotifierProvider<TenantController, Tenant?>(TenantController.new);

/// Holds the currently active [Tenant], or null if no tenant has been
/// resolved on this device yet.
///
/// Lifecycle:
///  * cold start: [build] reads the cached tenant from SecureStore (if any).
///  * Company ID entered on login: [resolveAndSet] hits the middleware and
///    persists the result.
///  * "Switch company": [clear] wipes the cached tenant and forces the
///    next launch to start at the Company ID screen.
class TenantController extends Notifier<Tenant?> {
  late SecureStore _store;

  @override
  Tenant? build() {
    _store = ref.read(secureStoreProvider);
    Future.microtask(_bootstrap);
    return null;
  }

  Future<void> _bootstrap() async {
    final raw = await _store.readTenant();
    if (raw == null || raw.isEmpty) return;
    try {
      state = Tenant.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt cache - drop it.
      await _store.clearTenant();
    }
  }

  /// Calls the middleware's resolve endpoint and persists the result.
  /// Throws [ApiException] on refusal; the caller renders the message.
  Future<Tenant> resolveAndSet(String companyId) async {
    final tenant =
        await ref.read(tenantRepositoryProvider).resolve(companyId);
    await _store.writeTenant(jsonEncode(tenant.toJson()));
    state = tenant;
    return tenant;
  }

  /// Wipes the cached tenant. Used by "Switch company" — usually followed by
  /// a wider [SecureStore.clearAll] to also clear any cached auth token.
  Future<void> clear() async {
    await _store.clearTenant();
    state = null;
  }
}

