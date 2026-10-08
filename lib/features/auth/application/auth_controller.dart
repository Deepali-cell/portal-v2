import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/providers.dart';
import '../../../core/storage/temp_file.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../call_detection/application/call_detect_controller.dart';
import '../../location_tracking/application/location_bridge.dart';
import '../../location_tracking/data/location_tracking_repository.dart';
import '../domain/profile.dart';
import 'lock_controller.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

@immutable
class AuthState {
  const AuthState._(this.status, this.profile);
  const AuthState.unknown() : this._(AuthStatus.unknown, null);
  const AuthState.unauthenticated() : this._(AuthStatus.unauthenticated, null);
  const AuthState.authenticated(Profile profile)
      : this._(AuthStatus.authenticated, profile);

  final AuthStatus status;
  final Profile? profile;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Resolve the persisted session after build returns (keeps build sync and
    // avoids a provider dependency cycle with the Dio client).
    Future.microtask(_bootstrap);
    return const AuthState.unknown();
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(authRepositoryProvider);
    if (!await repo.hasToken()) {
      state = const AuthState.unauthenticated();
      return;
    }

    final cached = await repo.cachedProfile();
    if (cached != null) {
      state = AuthState.authenticated(cached);
    }

    // Refresh in the background; ignore transient/offline failures so a cached
    // session still works without connectivity.
    try {
      final fresh = await repo.fetchProfile();
      state = AuthState.authenticated(fresh);
    } catch (_) {
      if (cached == null) state = const AuthState.unauthenticated();
    }
  }

  /// Throws [ApiException] on failure; caller renders the message.
  Future<void> login(String usr, String pwd) async {
    final repo = ref.read(authRepositoryProvider);
    final profile = await repo.login(usr, pwd);
    state = AuthState.authenticated(profile);
    ref.read(notificationServiceProvider).syncRegistration();
  }

  /// Re-fetch the profile for the current session (pull-to-refresh).
  Future<void> refresh() async {
    if (state.status != AuthStatus.authenticated) return;
    try {
      final fresh = await ref.read(authRepositoryProvider).fetchProfile();
      state = AuthState.authenticated(fresh);
    } catch (_) {
      // keep showing the last known profile on transient failures
    }
  }

  Future<void> logout() async {
    // Before the token is revoked: the server tracking session needs it.
    await _stopBackgroundServices();
    await ref.read(authRepositoryProvider).logout();
    await _clearPerUserCaches();
    ref.invalidate(sessionUnlockedProvider);
    state = const AuthState.unauthenticated();
  }

  /// Location tracking and call detection run as foreground services that
  /// survive the app closing. They belong to the signed-in user, so they stop
  /// on sign-out instead of carrying on (or starting for the next user).
  Future<void> _stopBackgroundServices() async {
    try {
      await ref.read(locationBridgeProvider).stopNativeService();
    } catch (_) {}
    try {
      await ref.read(locationRepositoryProvider).setEnabled(false);
    } catch (_) {/* best effort; the server session times out anyway */}
    try {
      await ref.read(callDetectControllerProvider.notifier).setEnabled(false);
    } catch (_) {}
  }

  /// Per-user Hive caches that should NOT leak to the next user even if the
  /// next user logs in against the same tenant. The tenant config itself
  /// stays cached (so the login screen stays themed).
  Future<void> _clearPerUserCaches() async {
    final boxName = AttendanceRepository.boxName;
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).clear();
    }
    await clearTempFiles();
  }

  /// Pushes editable Employee fields to the server and updates local state.
  Future<void> updateMyProfile(Map<String, dynamic> patch) async {
    final current = state.profile;
    if (current == null) return;
    final updated =
        await ref.read(authRepositoryProvider).updateMyProfile(patch);
    state = AuthState.authenticated(current.withEmployee(updated));
  }

  /// Invoked when the server rejects the token (expired/revoked).
  void forceLogout() {
    if (state.status == AuthStatus.unauthenticated) return;
    ref.invalidate(sessionUnlockedProvider);
    state = const AuthState.unauthenticated();
    // Clear stored credentials and stop background services without blocking.
    _stopBackgroundServices();
    ref.read(authRepositoryProvider).logout();
  }
}
