import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../application/post_call_pending.dart';
import 'call_outcome_sheet.dart';

/// Wraps the app and watches for `AppLifecycleState.resumed`. If the user
/// tapped a quick-call icon (Runo R.1) within [kPostCallWindow], opens the
/// post-call outcome sheet automatically when they return.
///
/// Plugged in once at the root of the widget tree so it survives screen
/// changes and tenant switches.
class PostCallResumeListener extends ConsumerStatefulWidget {
  const PostCallResumeListener({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PostCallResumeListener> createState() =>
      _PostCallResumeListenerState();
}

class _PostCallResumeListenerState
    extends ConsumerState<PostCallResumeListener> with WidgetsBindingObserver {
  // Prevents double-fire if the lifecycle flickers (e.g. some Android OEMs
  // toggle inactive→resumed twice for a single dialer trip).
  bool _firing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _maybeFireSheet();
  }

  Future<void> _maybeFireSheet() async {
    if (_firing) return;
    final intent = ref.read(postCallPendingProvider);
    if (intent == null) return;

    final notifier = ref.read(postCallPendingProvider.notifier);
    if (intent.isExpired(kPostCallWindow)) {
      notifier.clear();
      return;
    }

    // Defer to next frame so the navigator is settled before we present the
    // sheet — otherwise on cold-ish resume we'd race the route stack.
    _firing = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      final navState = rootNavigatorKey.currentState;
      if (navState == null || !navState.mounted) return;

      // Clear the intent BEFORE the sheet opens so a second resume during the
      // sheet's life (rare, but possible if user backgrounds the sheet
      // itself) doesn't re-trigger.
      notifier.clear();

      await showCallOutcomeSheet(
        navState.context,
        referenceDoctype: intent.referenceDoctype,
        referenceDocname: intent.referenceDocname,
        parentLabel: intent.parentLabel,
      );
    } finally {
      _firing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
