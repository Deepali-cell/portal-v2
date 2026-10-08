import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/data_disclosure.dart';
import '../../../core/storage/secure_store.dart';
import '../data/permission_service.dart';
import '../domain/permission_status.dart';
import 'call_event_bridge.dart';

final permissionServiceProvider = Provider<CallDetectPermissionService>(
    (ref) => CallDetectPermissionService());

/// Polled snapshot of the call-detection settings UI. autoDispose +
/// invalidate() pattern so the screen always reads fresh permission state
/// when it re-opens (after the user returns from system Settings).
final callDetectSnapshotProvider =
    FutureProvider.autoDispose<CallDetectSnapshot>((ref) async {
  final svc = ref.read(permissionServiceProvider);
  final store = ref.read(secureStoreProvider);

  final enabled = await store.readCallDetectEnabled();
  final perms = await svc.checkAll();

  // Device brand probe — uses Platform info; for richer info we'd add
  // device_info_plus in D.2.2. For now we infer from Platform.operatingSystem.
  String? brand;
  String? model;
  if (!kIsWeb && Platform.isAndroid) {
    brand = Platform.operatingSystemVersion;  // best we can do without device_info
    model = null;
  }
  final (supported, hint) = DeviceSupportProbe.probe(brand, model);

  return CallDetectSnapshot(
    enabled: enabled,
    permissions: perms,
    deviceSupported: supported,
    deviceModelHint: hint,
  );
});

/// Controller for the master toggle + permission requests.
class CallDetectController extends Notifier<bool> {
  @override
  bool build() {
    // Default to false; first read will hydrate via the snapshot provider.
    Future.microtask(() async {
      final stored =
          await ref.read(secureStoreProvider).readCallDetectEnabled();
      state = stored;
      // Restore the persistent background service on app start so detection
      // keeps working after the app was closed / the phone rebooted.
      if (stored && !kIsWeb && Platform.isAndroid) {
        await ref.read(callEventBridgeProvider).startPersistentDetection();
      }
    });
    return false;
  }

  Future<void> setEnabled(bool value) async {
    if (value) {
      // Turning call logging on is the user's choice, so show the disclosure
      // again even if they declined it at first sign-in.
      if (await disclosureAnswer(DataDisclosure.calls) != true) {
        await resetDisclosure(DataDisclosure.calls);
      }
      if (!await ensureDisclosureAccepted(DataDisclosure.calls)) return;
    }
    state = value;
    await ref.read(secureStoreProvider).writeCallDetectEnabled(value);
    // Start/stop the persistent foreground service so detection survives the
    // app being closed on aggressive OEMs (Vivo/Xiaomi/Oppo/etc).
    if (!kIsWeb && Platform.isAndroid) {
      final bridge = ref.read(callEventBridgeProvider);
      if (value) {
        await bridge.startPersistentDetection();
      } else {
        await bridge.stopPersistentDetection();
      }
    }
    ref.invalidate(callDetectSnapshotProvider);
  }

  Future<PermissionState> requestPermission(CallDetectPermission p) async {
    final svc = ref.read(permissionServiceProvider);
    final result = await svc.request(p);
    ref.invalidate(callDetectSnapshotProvider);
    return result;
  }

  Future<void> openSystemAppSettings() async {
    await ref.read(permissionServiceProvider).openSystemAppSettings();
    ref.invalidate(callDetectSnapshotProvider);
  }
}

final callDetectControllerProvider =
    NotifierProvider<CallDetectController, bool>(CallDetectController.new);
