import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../auth/application/auth_controller.dart';
import '../application/call_event_bridge.dart';
import '../data/recording_repository.dart';

void _log(String msg) {
  developer.log('[DeeplinkListener] $msg', name: 'tcb.deeplink');
}

/// Mounted at the app root. Watches [pendingDeeplinkProvider] for any
/// deeplink string published by the native notification system and routes
/// the user accordingly.
///
/// Deeplink format: "kind:identifier"
///   * `lead:CRM-LEAD-2026-00050`      → /lead-detail extra=name
///   * `deal:CRM-DEAL-...`             → /deal-detail extra=name
///   * "recording:CALL-REC-2026-..."   → fetch the recording, navigate to
///                                        its linked Lead/Deal (Calls tab
///                                        renders the summary card)
///
/// Cold-start path: native cached any deeplink that arrived before the
/// MethodChannel was alive; we consume it once on first frame.
class DeeplinkListener extends ConsumerStatefulWidget {
  const DeeplinkListener({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<DeeplinkListener> createState() => _DeeplinkListenerState();
}

class _DeeplinkListenerState extends ConsumerState<DeeplinkListener> {
  bool _coldChecked = false;
  Timer? _retryTimer;
  // Re-entry guard: while true, listener rebuilds that fire on the same
  // deeplink value are ignored. Cleared once we push (or bail out) so a
  // later, DIFFERENT deeplink can still route.
  bool _handling = false;
  // The deeplink currently being handled — used to dedupe when the same
  // string is re-emitted (rare, but happens if native re-posts a cached
  // deeplink on warm-resume before we've cleared the provider).
  String? _inflight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_coldChecked) return;
      _coldChecked = true;
      final cold = await ref.read(callEventBridgeProvider).consumePendingDeeplink();
      _log('cold-start poll → ${cold ?? "(none)"}');
      if (cold != null && cold.isNotEmpty) {
        ref.read(pendingDeeplinkProvider.notifier).set(cold);
      }
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  /// Push the deeplink AS SOON AS the user is authenticated AND the router
  /// has settled past the transient routes (splash/login/unlock). Without
  /// this guard the redirect in [routerProvider] catches the push and
  /// re-routes it to splash/login, silently losing the navigation.
  Future<void> _handle(String deeplink) async {
    _log('handle deeplink=$deeplink');
    // Re-entry guard. If a previous _handle for the SAME deeplink is
    // still in flight (e.g. waiting on repo.get inside _openRecording),
    // ignore this rebuild — otherwise we'd push the same route twice
    // and Navigator throws '!keyReservation.contains(key)'.
    if (_handling && _inflight == deeplink) {
      _log('drop reentrant handle for same deeplink');
      return;
    }
    _handling = true;
    _inflight = deeplink;
    try {
      await _handleImpl(deeplink);
    } finally {
      _handling = false;
      _inflight = null;
    }
  }

  Future<void> _handleImpl(String deeplink) async {
    final idx = deeplink.indexOf(':');
    if (idx <= 0) {
      ref.read(pendingDeeplinkProvider.notifier).clear();
      return;
    }
    final kind = deeplink.substring(0, idx).toLowerCase();
    final id = deeplink.substring(idx + 1).trim();
    if (id.isEmpty) {
      ref.read(pendingDeeplinkProvider.notifier).clear();
      return;
    }

    // Poll auth + router-readiness; once green, do the push.
    Future<void> tryPush() async {
      final auth = ref.read(authControllerProvider);
      final ctx = rootNavigatorKey.currentContext;
      _log('try push: auth=${auth.status} ctxReady=${ctx != null}');
      if (auth.status != AuthStatus.authenticated || ctx == null) return;
      // Also wait until we're past the transient routes — read GoRouter's
      // current location via GoRouterState.
      final router = GoRouter.of(ctx);
      final loc = router.routerDelegate.currentConfiguration.uri.path;
      _log('current location=$loc');
      const transient = {Routes.splash, Routes.login, Routes.unlock};
      if (transient.contains(loc)) return; // not ready yet

      // All green — clear, then push.
      ref.read(pendingDeeplinkProvider.notifier).clear();
      _retryTimer?.cancel();
      _retryTimer = null;
      _log('pushing $kind:$id');

      switch (kind) {
        case 'lead':
          _safePush(ctx, Routes.leadDetail, id);
          break;
        case 'deal':
          _safePush(ctx, Routes.dealDetail, id);
          break;
        case 'recording':
          await _openRecording(ctx, id);
          break;
      }
    }

    // Try immediately; if not yet ready, retry every 250ms for up to 10s.
    await tryPush();
    if (ref.read(pendingDeeplinkProvider) == null) return; // pushed already
    _retryTimer?.cancel();
    var attempts = 0;
    _retryTimer = Timer.periodic(const Duration(milliseconds: 250), (t) async {
      attempts++;
      await tryPush();
      if (ref.read(pendingDeeplinkProvider) == null || attempts > 40) {
        t.cancel();
        _retryTimer = null;
        if (attempts > 40) {
          _log('giving up after 40 attempts');
          ref.read(pendingDeeplinkProvider.notifier).clear();
        }
      }
    });
  }

  /// Push [path] with [extra] IF the router isn't already sitting on that
  /// exact route + extra combination. Fixes the Navigator assertion
  /// '!keyReservation.contains(key)' that fired when a notification for
  /// the currently-open lead re-triggered a duplicate push.
  ///
  /// GoRouter doesn't expose a single "current extra" API, so we check
  /// the current path first, then trust GoRouter's own deduping for
  /// deep-linked entries by using go() when the path already matches
  /// (go replaces the stack top, side-stepping the double-key crash).
  void _safePush(BuildContext ctx, String path, String extra) {
    final router = GoRouter.of(ctx);
    final loc = router.routerDelegate.currentConfiguration.uri.path;
    if (loc == path) {
      // Already on this kind of screen — replace so the extra becomes
      // the new value (user may be re-opening a different lead).
      ctx.go(path, extra: extra);
    } else {
      ctx.push(path, extra: extra);
    }
  }

  Future<void> _openRecording(BuildContext ctx, String recordingName) async {
    try {
      final repo = RecordingRepository(ref.read(dioProvider));
      final rec = await repo.get(recordingName);
      final dt = rec.referenceDoctype;
      final dn = rec.referenceDocname;
      if (dt == null || dn == null || dn.isEmpty) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('Recording $recordingName has no linked lead or deal.'),
          ));
        }
        return;
      }
      if (!ctx.mounted) return;
      if (dt == 'Lead') {
        _safePush(ctx, Routes.leadDetail, dn);
      } else if (dt == 'Opportunity') {
        _safePush(ctx, Routes.dealDetail, dn);
      }
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text("Couldn't open the recording. Please try again."),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingDeeplinkProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handle(next));
      }
    });
    return widget.child;
  }
}
