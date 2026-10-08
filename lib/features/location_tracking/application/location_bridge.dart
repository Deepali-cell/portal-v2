import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../core/security/data_disclosure.dart';
import '../data/location_tracking_repository.dart';

/// Owns the MethodChannel to the Android foreground service and pipes every
/// `onLocationUpdate` from native into the tenant Frappe via `record_ping`.
///
/// One instance per app process, created lazily by `locationBridgeProvider`.
class LocationBridge {
  LocationBridge(this._ref) {
    _channel.setMethodCallHandler(_handleCall);
  }
  final Ref _ref;

  static const _channel = MethodChannel('tcb_portal/location_tracking');

  // Serialise ping uploads so bursts don't hit the API in parallel.
  bool _uploading = false;
  final List<Map<String, dynamic>> _pendingBatch = [];

  Future<bool> startNativeService() async {
    try {
      final r = await _channel.invokeMethod<bool>('startService');
      return r ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('[loc] startService error: $e');
      return false;
    }
  }

  Future<bool> stopNativeService() async {
    try {
      final r = await _channel.invokeMethod<bool>('stopService');
      return r ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('[loc] stopService error: $e');
      return false;
    }
  }

  Future<bool> isNativeRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isRunning') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    if (call.method != 'onLocationUpdate') return null;
    final args = (call.arguments as Map).cast<String, dynamic>();
    await _uploadOne(args);
    return null;
  }

  Future<void> _uploadOne(Map<String, dynamic> args) async {
    // Defensive gate: only upload if the backend also thinks tracking is on.
    // A stale native service after a fresh login could otherwise leak pings.
    final status =
        await _ref.read(locationRepositoryProvider).getStatus().catchError(
              (_) => throw StateError('status_unreachable'),
            );
    if (!status.enabled) {
      if (kDebugMode) debugPrint('[loc] backend says off; discarding ping');
      return;
    }

    final ts = args['recorded_at'] as int?;
    final recordedAt = ts != null && ts > 0
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : DateTime.now();
    final batteryRaw = (args['battery_level'] as num?)?.toInt() ?? -1;

    try {
      await _ref.read(locationRepositoryProvider).recordPing(
            latitude: (args['latitude'] as num).toDouble(),
            longitude: (args['longitude'] as num).toDouble(),
            accuracyM: (args['accuracy_m'] as num?)?.toDouble(),
            speedMps: (args['speed_mps'] as num?)?.toDouble(),
            batteryLevel: batteryRaw >= 0 ? batteryRaw : null,
            recordedAt: recordedAt,
          );
      // Re-fetch status so the toggle card's "last ping at" refreshes.
      _ref.invalidate(trackingStatusProvider);
    } catch (e) {
      if (kDebugMode) debugPrint('[loc] record_ping failed: $e');
      // A single failure is fine - the next fused-location callback (1 min
      // away) will retry. We deliberately do NOT queue-and-retry client-side
      // to keep the mobile stateless.
    }
  }
}

final locationBridgeProvider = Provider<LocationBridge>((ref) {
  return LocationBridge(ref);
});

/// Full flow to turn tracking ON: request runtime permissions -> flip the
/// backend session -> start the native service. Returns null on success, or
/// an error string when the user needs to be told something.
Future<String?> enableTrackingFlow(WidgetRef ref) async {
  // 1. Foreground location (Android 12+ prompts fine + coarse).
  final fine = await ph.Permission.locationWhenInUse.request();
  if (!fine.isGranted) {
    return 'Location permission is required to share your position.';
  }
  // 2. Background location (Android 10+), behind our own disclosure. The
  // user turned tracking on themselves, so ask again even if they declined
  // the disclosure earlier.
  if (await disclosureAnswer(DataDisclosure.backgroundLocation) != true) {
    await resetDisclosure(DataDisclosure.backgroundLocation);
  }
  if (!await ensureDisclosureAccepted(DataDisclosure.backgroundLocation)) {
    return 'Location tracking needs your consent to run in the background.';
  }
  final bg = await ph.Permission.locationAlways.request();
  if (!bg.isGranted) {
    return "Grant 'Allow all the time' so tracking works when the screen is off.";
  }
  // 3. Notifications (Android 13+ - the FGS needs its notification allowed).
  final notif = await ph.Permission.notification.request();
  if (!notif.isGranted) {
    return 'Allow notifications so the tracking service can run.';
  }
  // 4. Open backend session.
  try {
    await ref.read(locationRepositoryProvider).setEnabled(true);
  } catch (e) {
    return "Couldn't turn on tracking on the server. Try again.";
  }
  // 5. Start the native foreground service.
  final started = await ref.read(locationBridgeProvider).startNativeService();
  if (!started) {
    // Roll back the server session so state stays consistent.
    try {
      await ref.read(locationRepositoryProvider).setEnabled(false);
    } catch (_) {}
    return "Couldn't start the location service on this device.";
  }
  ref.invalidate(trackingStatusProvider);
  return null;
}

/// Turn tracking OFF: stop native + close backend session.
Future<String?> disableTrackingFlow(WidgetRef ref) async {
  final stopped = await ref.read(locationBridgeProvider).stopNativeService();
  try {
    await ref.read(locationRepositoryProvider).setEnabled(false);
  } catch (e) {
    return "Couldn't turn off tracking on the server. Try again.";
  }
  if (!stopped && kDebugMode) {
    debugPrint('[loc] native stop returned false');
  }
  ref.invalidate(trackingStatusProvider);
  return null;
}
