import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart' as ph;

import '../domain/permission_status.dart';

/// Wraps permission_handler with our specific permission set + iOS fallback.
///
/// All methods are no-ops on iOS (return notApplicable) because Apple's
/// sandbox prevents call interception entirely.
class CallDetectPermissionService {
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  // Recordings are audio files in shared storage, so the plain media
  // permission is enough: READ_MEDIA_AUDIO on Android 13+, READ_EXTERNAL_STORAGE
  // below. No "All files access" (Play only allows it for file managers).
  static const _storagePerms = [ph.Permission.audio, ph.Permission.storage];

  /// Fetch the current status of a single permission.
  Future<PermissionState> check(CallDetectPermission p) async {
    if (!_isAndroid) return PermissionState.notApplicable;
    if (p == CallDetectPermission.storage) {
      return _checkStorage();
    }
    final perm = _map(p);
    if (perm == null) return PermissionState.notApplicable;
    final status = await perm.status;
    return _fromHandler(status);
  }

  Future<List<CallDetectStatus>> checkAll() async {
    return Future.wait(
      CallDetectPermission.values.map((p) async =>
          CallDetectStatus(permission: p, state: await check(p))),
    );
  }

  /// Request a permission. Returns the new state after the dialog flow.
  Future<PermissionState> request(CallDetectPermission p) async {
    if (!_isAndroid) return PermissionState.notApplicable;
    if (p == CallDetectPermission.storage) {
      for (final perm in _storagePerms) {
        try {
          await perm.request();
        } catch (_) {/* not applicable on this Android version */}
      }
      return _checkStorage();
    }
    final perm = _map(p);
    if (perm == null) return PermissionState.notApplicable;
    final newStatus = await perm.request();
    return _fromHandler(newStatus);
  }

  /// Open the app's system Settings page (for permanentlyDenied recovery).
  Future<bool> openSystemAppSettings() async {
    if (!_isAndroid) return false;
    return ph.openAppSettings();
  }

  /// Granted when either media permission is (each applies to a different
  /// Android version, and the other one never grants). Only "permanently
  /// denied" when neither can be asked for again.
  Future<PermissionState> _checkStorage() async {
    final states = <PermissionState>[];
    for (final perm in _storagePerms) {
      try {
        states.add(_fromHandler(await perm.status));
      } catch (_) {/* not applicable on this Android version */}
    }
    if (states.contains(PermissionState.granted)) return PermissionState.granted;
    if (states.contains(PermissionState.denied)) return PermissionState.denied;
    return states.isEmpty ? PermissionState.denied : PermissionState.permanentlyDenied;
  }

  // ---- internals ----

  ph.Permission? _map(CallDetectPermission p) {
    switch (p) {
      case CallDetectPermission.phoneState:
      case CallDetectPermission.callLog:
        // permission_handler bundles READ_PHONE_STATE + READ_CALL_LOG under
        // Permission.phone. The native module in D.2.2 will explicitly
        // request READ_CALL_LOG via a platform channel if OEM requires it.
        return ph.Permission.phone;
      case CallDetectPermission.storage:
        // Handled by _checkStorage / request; unreachable in practice.
        return null;
      case CallDetectPermission.notifications:
        return ph.Permission.notification;
    }
  }

  PermissionState _fromHandler(ph.PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isRestricted) {
      return PermissionState.granted;
    }
    if (s.isPermanentlyDenied) return PermissionState.permanentlyDenied;
    return PermissionState.denied;
  }
}

/// Probes whether the running device is on the supported OEM list for
/// OEM-recorder-folder scraping (Phase D.2.4).
class DeviceSupportProbe {
  static const _supportedBrands = {
    'samsung', 'vivo', 'realme', 'oppo', 'xiaomi', 'redmi',
    'poco', 'motorola', 'moto',
  };
  static const _unsupportedBrands = {
    'google', 'nothing', 'oneplus',
  };

  /// Returns (supported, hintText).
  static (bool, String) probe(String? brand, String? model) {
    final b = (brand ?? '').toLowerCase().trim();
    final m = (model ?? '').trim();
    final brandLabel = brand ?? 'Unknown';
    final hint = m.isEmpty ? brandLabel : '$brandLabel $m';
    if (_unsupportedBrands.any((x) => b.contains(x))) {
      return (false, '$hint: OEM call recording not supported');
    }
    if (_supportedBrands.any((x) => b.contains(x))) {
      return (true, '$hint: supported');
    }
    return (true, '$hint: likely supported, will verify');
  }
}
