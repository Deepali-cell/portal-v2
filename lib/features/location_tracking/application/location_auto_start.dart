import 'dart:async';
import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../core/security/data_disclosure.dart';
import '../../auth/application/auth_controller.dart';
import '../data/location_tracking_repository.dart';
import 'location_bridge.dart';

/// Health state used by the Home banner. `healthy` = tracking will keep
/// working; anything else = we need to nudge the user.
enum LocationHealth {
  healthy,
  noPermission,
  noBackground,
  noNotification,
  serviceOff,
}

/// Computes current health by checking OS-level permissions + the location
/// service. Refreshed manually via `ref.invalidate(locationHealthProvider)`
/// when the user comes back from Settings.
final locationHealthProvider =
    FutureProvider.autoDispose<LocationHealth>((ref) async {
  if (kIsWeb || !Platform.isAndroid) return LocationHealth.healthy;
  final profile = ref.watch(authControllerProvider).profile;
  final isSales = profile?.can('sees_sales') ?? false;
  if (!isSales) return LocationHealth.healthy;

  final fine = await ph.Permission.locationWhenInUse.status;
  if (!fine.isGranted) return LocationHealth.noPermission;
  final bg = await ph.Permission.locationAlways.status;
  if (!bg.isGranted) return LocationHealth.noBackground;
  final notif = await ph.Permission.notification.status;
  if (!notif.isGranted) return LocationHealth.noNotification;
  final serviceOn = await ph.Permission.location.serviceStatus;
  if (serviceOn != ph.ServiceStatus.enabled) {
    return LocationHealth.serviceOff;
  }
  return LocationHealth.healthy;
});

/// Boot controller - runs once per app process. When the current user is
/// a sales role, silently starts the native FGS and opens the server
/// session. When permissions are missing, sends a heartbeat to the server
/// so the manager can see WHY updates stopped.
class LocationAutoStartController extends Notifier<bool> {
  Timer? _healthLoop;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _wasOffline = false;

  @override
  bool build() {
    // React to auth changes so switching users re-runs the boot.
    ref.listen<AuthState>(authControllerProvider, (_, next) {
      _boot(next.profile);
    });
    // First-time boot after app start.
    Future.microtask(() => _boot(ref.read(authControllerProvider).profile));
    // Listen to connectivity - when the phone comes back online after
    // being offline, fire ONE `network_error` heartbeat so the manager
    // knows the person was unreachable for a stretch (distinct from
    // "location off" or "permission off").
    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      final online = results.any((r) => r != ConnectivityResult.none);
      final profile = ref.read(authControllerProvider).profile;
      if (profile == null || !(profile.can('sees_sales') as bool)) return;
      if (!online) {
        _wasOffline = true;
      } else if (_wasOffline) {
        _wasOffline = false;
        await _sendHeartbeat('network_error');
      }
    });
    ref.onDispose(() {
      _healthLoop?.cancel();
      _connSub?.cancel();
    });
    return false;
  }

  Future<void> _boot(dynamic profile) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (profile == null) return;
    final isSales = profile.can('sees_sales') as bool;
    final bridge = ref.read(locationBridgeProvider);
    if (!isSales) {
      // Non-sales user just logged in. Ensure the native service is stopped
      // and any server session for THIS user is closed.
      await bridge.stopNativeService();
      try {
        await ref.read(locationRepositoryProvider).setEnabled(false);
      } catch (_) {/* offline is fine */}
      return;
    }

    // Sales user. Check permissions.
    final fine = await ph.Permission.locationWhenInUse.status;
    final bg = await ph.Permission.locationAlways.status;
    final notif = await ph.Permission.notification.status;
    final serviceOn = await ph.Permission.location.serviceStatus;

    if (!fine.isGranted) {
      final r = await ph.Permission.locationWhenInUse.request();
      if (!r.isGranted) {
        await _sendHeartbeat('no_permission');
        _startHealthLoop();
        return;
      }
    }
    if (!bg.isGranted) {
      // Play requires our own disclosure before asking for background location.
      if (!await ensureDisclosureAccepted(DataDisclosure.backgroundLocation)) {
        await _sendHeartbeat('no_permission');
        _startHealthLoop();
        return;
      }
      final r = await ph.Permission.locationAlways.request();
      if (!r.isGranted) {
        await _sendHeartbeat('no_permission');
        _startHealthLoop();
        return;
      }
    }
    if (!notif.isGranted) {
      final r = await ph.Permission.notification.request();
      if (!r.isGranted) {
        await _sendHeartbeat('no_permission');
        _startHealthLoop();
        return;
      }
    }
    if (serviceOn != ph.ServiceStatus.enabled) {
      await _sendHeartbeat('location_off');
      _startHealthLoop();
      return;
    }

    // All green - start the native FGS + open server session.
    try {
      await ref.read(locationRepositoryProvider).setEnabled(true);
      await bridge.startNativeService();
    } catch (e) {
      if (kDebugMode) debugPrint('[loc-auto] boot failed: $e');
    }
    _startHealthLoop();
    state = true;
  }

  Future<void> _sendHeartbeat(String reason) async {
    try {
      await ref
          .read(locationRepositoryProvider)
          .recordHeartbeat(reason: reason);
    } catch (e) {
      if (kDebugMode) debugPrint('[loc-auto] heartbeat($reason) failed: $e');
    }
  }

  /// Poll health every 5 min; when it flips healthy, retry the boot.
  /// When it flips unhealthy, send a heartbeat so the manager knows.
  void _startHealthLoop() {
    _healthLoop?.cancel();
    _healthLoop = Timer.periodic(const Duration(minutes: 5), (_) async {
      final profile = ref.read(authControllerProvider).profile;
      if (profile == null || !(profile.can('sees_sales') as bool)) return;
      final serviceOn = await ph.Permission.location.serviceStatus;
      final fine = await ph.Permission.locationWhenInUse.status;
      final bg = await ph.Permission.locationAlways.status;
      if (!fine.isGranted || !bg.isGranted) {
        await _sendHeartbeat('no_permission');
      } else if (serviceOn != ph.ServiceStatus.enabled) {
        await _sendHeartbeat('location_off');
      }
    });
  }
}

final locationAutoStartProvider =
    NotifierProvider<LocationAutoStartController, bool>(
        LocationAutoStartController.new);
