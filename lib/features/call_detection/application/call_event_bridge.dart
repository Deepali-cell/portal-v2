import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../../phone_lookup/data/lookup_repository.dart';
import '../data/recording_repository.dart';

/// Single event emitted from native (D.2.2 — Kotlin foreground service)
/// representing a phone-call state change observed on the device.
@immutable
class CallDetectEvent {
  const CallDetectEvent({
    required this.kind,
    required this.number,
    required this.direction,
    required this.at,
  });
  final CallEventKind kind;
  final String number;
  final String direction; // "incoming" | "outgoing" | ""
  final DateTime at;
}

enum CallEventKind { detected, ended, recordingFound, recordingUploaded, recordingFailed }

/// Most-recent deeplink string ("recording:CALL-REC-...", "lead:CRM-LEAD-...",
/// "lookup:+91...") received from the native notification system. The router
/// observes this provider and pushes the appropriate Flutter route.
class PendingDeeplinkController extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
  void clear() => state = null;
}

final pendingDeeplinkProvider =
    NotifierProvider<PendingDeeplinkController, String?>(
        PendingDeeplinkController.new);

/// Latest recording-upload progress so the UI banner can show "Uploading…"
/// → "Uploaded, AI processing…" → "Ready" without each screen subscribing
/// to the bridge directly.
class RecordingUploadProgress {
  RecordingUploadProgress({
    required this.path,
    required this.number,
    required this.state,
    this.recordingName,
    this.errorMessage,
  });
  final String path;
  final String number;
  final String state; // 'uploading' | 'uploaded' | 'failed'
  final String? recordingName;
  final String? errorMessage;
}

class RecordingUploadController extends Notifier<RecordingUploadProgress?> {
  @override
  RecordingUploadProgress? build() => null;
  void set(RecordingUploadProgress p) => state = p;
}

final recordingUploadProvider =
    NotifierProvider<RecordingUploadController, RecordingUploadProgress?>(
        RecordingUploadController.new);

/// Holds the latest [CallDetectEvent] from the native module. Null until
/// the first event arrives. Any widget can `watch` for live updates.
class LastCallEventController extends Notifier<CallDetectEvent?> {
  @override
  CallDetectEvent? build() => null;
  void set(CallDetectEvent e) => state = e;
}

final lastCallEventProvider =
    NotifierProvider<LastCallEventController, CallDetectEvent?>(
        LastCallEventController.new);

/// Top-level service that owns the MethodChannel to native. Initialised once
/// in app startup. On every event from native, updates
/// [lastCallEventProvider] so any widget can listen.
class CallEventBridge {
  static const _channel = MethodChannel('tcb_portal/call_detect');

  CallEventBridge(this._ref);
  final Ref _ref;

  // Short-lived memory cache of "is this number linked to a Lead/Deal?"
  // Both `onCallLogReady` and `onRecordingFound` may fire back-to-back
  // for the same call; this stops us from hitting lookup_by_phone twice.
  // TTL is deliberately short so a newly-added lead is picked up quickly.
  static const _lookupTtl = Duration(minutes: 5);
  final Map<String, ({bool matched, DateTime at})> _lookupCache = {};

  /// Strip formatting, spaces, and the +91 India country code so a raw
  /// dialer string ("+91 98765-43210") and the CRM's stored number
  /// ("9876543210") collapse to the same 10-digit key. Numbers shorter
  /// than 7 digits are returned as-is; the backend rejects those anyway.
  String _normalizeNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10 && digits.startsWith('91')) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// True iff the given phone number belongs to a Lead or Deal owned by
  /// the current user (or team, when manager scope is on). On network
  /// failure we return FALSE — a spam call with no lookup is worse than
  /// a missed genuine call, and the user can always retry manually.
  Future<bool> _isKnownLeadOrDeal(String number) async {
    final normalized = _normalizeNumber(number);
    if (normalized.length < 7) return false;

    final cached = _lookupCache[normalized];
    if (cached != null &&
        DateTime.now().difference(cached.at) < _lookupTtl) {
      return cached.matched;
    }

    try {
      final repo = PhoneLookupRepository(_ref.read(dioProvider));
      final result = await repo.lookup(normalized);
      _lookupCache[normalized] =
          (matched: result.matched, at: DateTime.now());
      return result.matched;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[CallDetect] lookup_by_phone failed for $normalized ($e); '
            'treating as unknown and skipping.');
      }
      return false;
    }
  }

  // ---- Background reliability (all Android brands) --------------------
  // These keep detection working when the app is closed/backgrounded by
  // running a persistent foreground service and taking the app out of the
  // OEM "stopped" state that otherwise drops the PHONE_STATE broadcast.

  /// Start the persistent foreground service + remember it across reboots.
  Future<void> startPersistentDetection() async {
    try {
      await _channel.invokeMethod('startPersistentDetection');
    } catch (_) {/* non-Android / not supported */}
  }

  /// Stop the persistent foreground service + forget it across reboots.
  Future<void> stopPersistentDetection() async {
    try {
      await _channel.invokeMethod('stopPersistentDetection');
    } catch (_) {/* non-Android / not supported */}
  }

  /// Whether the persistent foreground service is currently running.
  Future<bool?> isPersistentRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isPersistentRunning');
    } catch (_) {
      return null;
    }
  }

  /// Whether the app is exempt from Doze battery optimization (AOSP).
  Future<bool?> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
    } catch (_) {
      return null;
    }
  }

  /// Opens the standard system dialog to exempt us from battery optimization.
  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {/* swallow */}
  }

  /// Opens the device's Autostart / auto-launch manager (brand-specific,
  /// falls back to the app details page on stock Android).
  Future<void> openAutoStartSettings() async {
    try {
      await _channel.invokeMethod('openAutoStartSettings');
    } catch (_) {/* swallow */}
  }

  /// Pull any deeplink that arrived via notification tap BEFORE the channel
  /// was alive (cold-start case). The native side caches it; this consumes
  /// + clears it. Returns null if nothing was pending.
  Future<String?> consumePendingDeeplink() async {
    try {
      return await _channel.invokeMethod<String>('consumePendingDeeplink');
    } catch (_) {
      return null;
    }
  }

  /// Posts a system-tray notification via the native LocalNotifier. Used
  /// to surface call-capture + AI-summary alerts even when the app is
  /// backgrounded (the in-app banner only fires when the screen is open).
  Future<int?> postLocalNotification({
    required String title,
    required String body,
    String? deeplink,
    int? id,
  }) async {
    try {
      final r = await _channel.invokeMethod<int>('postLocalNotification', {
        'title': title,
        'body': body,
        if (deeplink != null) 'deeplink': deeplink,
        if (id != null) 'id': id,
      });
      return r;
    } catch (_) {
      return null;
    }
  }

  void start() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDeeplink':
          final args = (call.arguments as Map).cast<String, dynamic>();
          final dl = (args['deeplink'] ?? '').toString();
          if (dl.isNotEmpty) {
            _ref.read(pendingDeeplinkProvider.notifier).set(dl);
          }
          break;
        case 'onCallDetected':
          final args = (call.arguments as Map).cast<String, dynamic>();
          _ref.read(lastCallEventProvider.notifier).set(CallDetectEvent(
                kind: CallEventKind.detected,
                number: (args['number'] ?? '').toString(),
                direction: (args['direction'] ?? '').toString(),
                at: DateTime.now(),
              ));
          break;
        case 'onCallEnded':
          final args = (call.arguments as Map).cast<String, dynamic>();
          _ref.read(lastCallEventProvider.notifier).set(CallDetectEvent(
                kind: CallEventKind.ended,
                number: (args['number'] ?? '').toString(),
                direction: '',
                at: DateTime.now(),
              ));
          break;
        case 'onRecordingFound':
          final args = (call.arguments as Map).cast<String, dynamic>();
          _onRecordingFound(args);
          break;
        case 'onCallLogReady':
          // Fired post-IDLE after native re-queries CallLog. Persist a CRM
          // Call Log row even if no recording is found — so every call
          // attempt is on the activity timeline. The recording upload (if
          // it arrives) will REPLACE the from/to and link to this row via
          // the matched lead.
          final args = (call.arguments as Map).cast<String, dynamic>();
          _onCallLogReady(args);
          break;
        default:
          break;
      }
      return null;
    });
  }

  /// Native told us "here's the OEM-written MP3 for the call that just ended".
  /// Immediately upload + auto-create call log (server-side) + fire two
  /// local notifications: one when captured, one when AI summary is ready.
  ///
  /// GATE: If the number isn't linked to any Lead or Deal we drop the whole
  /// pipeline right here — no upload, no AI processing, no notification,
  /// no CRM Call Log row. Spam and personal calls should be invisible to
  /// the app.
  Future<void> _onRecordingFound(Map<String, dynamic> args) async {
    final path = (args['path'] ?? '').toString();
    final number = (args['number'] ?? '').toString();
    final folder = (args['folder'] ?? '').toString();
    final direction = (args['direction'] ?? '').toString();
    final contactHint = (args['contact_name_hint'] ?? '').toString();
    if (path.isEmpty) return;

    if (number.isEmpty || !await _isKnownLeadOrDeal(number)) {
      if (kDebugMode) {
        debugPrint(
            '[CallDetect] Ignoring recording — number "$number" is not '
            'linked to any Lead or Deal.');
      }
      return;
    }

    _ref.read(recordingUploadProvider.notifier).set(
          RecordingUploadProgress(
              path: path, number: number, state: 'uploading'),
        );

    try {
      final repo = RecordingRepository(_ref.read(dioProvider));
      // Native sends "incoming" / "outgoing" lowercase; backend enum wants
      // "Incoming" / "Outgoing".
      final dirCapitalized = direction.isEmpty
          ? null
          : '${direction[0].toUpperCase()}${direction.substring(1).toLowerCase()}';
      final r = await repo.upload(
        localPath: path,
        phoneNumber: number.isEmpty ? null : number,
        sourceFolder: folder.isEmpty ? null : folder,
        direction: dirCapitalized,
        contactNameHint: contactHint.isEmpty ? null : contactHint,
      );
      _ref.read(recordingUploadProvider.notifier).set(
            RecordingUploadProgress(
              path: path,
              number: number,
              state: 'uploaded',
              recordingName: r.name,
            ),
          );

      // First notification: call captured (immediate, user-scoped).
      final captured = r.matchedDisplay?.isNotEmpty == true
          ? r.matchedDisplay!
          : (number.isEmpty ? "call" : number);
      await postLocalNotification(
        title: "Call captured: $captured",
        body: "AI summary processing. You'll be alerted when it's ready.",
        deeplink: "recording:${r.name}",
        id: r.name.hashCode & 0x7fffffff,
      );

      // Poll for AI readiness. 90 sec budget, every 5 sec.
      _pollForSummary(repo, r.name, displayHint: captured);
    } catch (e) {
      _ref.read(recordingUploadProvider.notifier).set(
            RecordingUploadProgress(
              path: path,
              number: number,
              state: 'failed',
              errorMessage: e.toString(),
            ),
          );
      // Surface the real error so a device without USB/logcat can still be
      // diagnosed — the user reads the message back to us. Trimmed so the
      // system tray doesn't truncate the useful part.
      final diag = e.toString().replaceAll('\n', ' ');
      await postLocalNotification(
        title: "Couldn't upload recording",
        body: diag.length > 220 ? diag.substring(0, 220) : diag,
      );
    }
  }

  /// Persist a CRM Call Log row for the just-ended call. Fires from
  /// native CallDetectionService after the post-IDLE CallLog re-query,
  /// by which point we have the real dialed number (not the OFFHOOK
  /// stale value).
  ///
  /// GATE: Same rule as _onRecordingFound. Only log the call when the
  /// number matches a Lead or Deal. Spam calls, personal calls, and
  /// missed calls to unknown numbers stay out of the CRM entirely.
  Future<void> _onCallLogReady(Map<String, dynamic> args) async {
    final number = (args['number'] ?? '').toString();
    final contactName = (args['contact_name'] ?? '').toString();
    final direction = (args['direction'] ?? 'outgoing').toString();
    final status = (args['status'] ?? 'Completed').toString();
    final durationSec = (args['duration_sec'] as num?)?.toInt() ?? 0;
    if (number.isEmpty && contactName.isEmpty) return;

    if (number.isEmpty || !await _isKnownLeadOrDeal(number)) {
      if (kDebugMode) {
        debugPrint(
            '[CallDetect] Ignoring call log: number "$number" is not '
            'linked to any Lead or Deal.');
      }
      return;
    }

    try {
      final dio = _ref.read(dioProvider);
      final dirCap =
          '${direction[0].toUpperCase()}${direction.substring(1).toLowerCase()}';
      await dio.post(
        ApiPaths.logCallAttempt,
        data: {
          'phone_number': number,
          'contact_name': contactName,
          'direction': dirCap,
          'status': status,
          'duration_seconds': durationSec,
        },
      );
    } catch (_) {
      // Non-fatal — recording upload (if it arrives) will create a CRM
      // Call Log too. This endpoint exists just to cover the no-recording
      // cases (call didn't connect, OEM doesn't record outgoing, etc.).
    }
  }

  Future<void> _pollForSummary(
    RecordingRepository repo,
    String name, {
    required String displayHint,
  }) async {
    final repoStart = DateTime.now();
    while (DateTime.now().difference(repoStart).inSeconds < 90) {
      await Future<void>.delayed(const Duration(seconds: 5));
      try {
        final fresh = await repo.get(name);
        if (fresh.isReady) {
          final suggest = fresh.suggestedStatus?.isNotEmpty == true
              ? " → ${fresh.suggestedStatus}"
              : "";
          await postLocalNotification(
            title: "AI summary ready: $displayHint",
            body: "Tap to view summary + suggested next action$suggest",
            deeplink: "recording:${fresh.name}",
            id: ("ready:${fresh.name}").hashCode & 0x7fffffff,
          );
          return;
        }
        if (fresh.isFailed) {
          await postLocalNotification(
            title: "AI processing failed: $displayHint",
            body: fresh.errorMessage ?? "Open the recording for details.",
            deeplink: "recording:${fresh.name}",
          );
          return;
        }
      } catch (_) {
        // Transient — keep polling.
      }
    }
    // 90s without Ready/Failed — leave it; next app-open the summary will
    // appear inline. No noisy timeout notification.
  }
}

final callEventBridgeProvider = Provider<CallEventBridge>((ref) {
  final bridge = CallEventBridge(ref);
  bridge.start();
  return bridge;
});
