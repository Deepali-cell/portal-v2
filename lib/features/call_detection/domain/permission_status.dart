import 'package:flutter/foundation.dart';

/// The Android permissions required for full call detection + recording.
/// iOS doesn't support any of these for call interception (Apple sandbox).
enum CallDetectPermission {
  phoneState,        // READ_PHONE_STATE  — detect RINGING / OFFHOOK / IDLE
  callLog,           // READ_CALL_LOG     — resolve incoming number post-Android 10
  storage,           // READ_MEDIA_AUDIO (A13+) / READ_EXTERNAL_STORAGE — read OEM recorder folder
  notifications,     // POST_NOTIFICATIONS — Android 13+ foreground-service notif
}

extension CallDetectPermissionX on CallDetectPermission {
  String get label => switch (this) {
        CallDetectPermission.phoneState =>
            'Phone state (detect ringing)',
        CallDetectPermission.callLog =>
            'Call log (read incoming number)',
        CallDetectPermission.storage =>
            'Storage (read recording files)',
        CallDetectPermission.notifications =>
            'Notifications (background service)',
      };

  String get rationale => switch (this) {
        CallDetectPermission.phoneState =>
            'Tells us when your phone rings so we can identify the caller before you pick up.',
        CallDetectPermission.callLog =>
            'Reads the incoming number from the system call log. Required on Android 10 and above.',
        CallDetectPermission.storage =>
            "Reads the call recording from your phone's built-in recorder folder.",
        CallDetectPermission.notifications =>
            'Lets the background service keep running so we never miss a call (Android 13+).',
      };
}

enum PermissionState {
  granted,           // user said yes
  denied,            // user said no, can ask again
  permanentlyDenied, // "Don't ask again" — must open Settings
  notApplicable,     // wrong platform (e.g. iOS) or Android version doesn't need it
  unknown,           // not checked yet
}

@immutable
class CallDetectStatus {
  const CallDetectStatus({required this.permission, required this.state});
  final CallDetectPermission permission;
  final PermissionState state;

  bool get isGranted => state == PermissionState.granted;
  bool get isBlockedByUser => state == PermissionState.permanentlyDenied;
}

/// Aggregate snapshot rendered on the settings screen.
@immutable
class CallDetectSnapshot {
  const CallDetectSnapshot({
    required this.enabled,
    required this.permissions,
    required this.deviceSupported,
    required this.deviceModelHint,
  });

  /// Master toggle persisted by the user.
  final bool enabled;

  /// Per-permission status, ordered for display.
  final List<CallDetectStatus> permissions;

  /// Whether this device is on the supported OEM list for OEM-recorder-folder
  /// scraping (Samsung / Vivo / Realme / Redmi / Motorola). Pixel / Nothing /
  /// OnePlus post-OxygenOS-12 are NOT supported for recording (overlay still works).
  final bool deviceSupported;

  /// Free-text hint shown next to the support badge (e.g. "Realme detected").
  final String deviceModelHint;

  bool get allGranted => permissions.every((p) => p.isGranted);
  int get grantedCount => permissions.where((p) => p.isGranted).length;
}
