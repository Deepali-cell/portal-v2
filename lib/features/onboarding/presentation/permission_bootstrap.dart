import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/security/data_disclosure.dart';
import '../../auth/application/auth_controller.dart';
import '../../call_detection/application/call_event_bridge.dart';

/// First-run permission walkthrough. Mounted at the app root above the
/// router, this widget kicks off on first build of an authenticated
/// session and walks the user through granting every runtime permission
/// the app needs in one batch — so they don't have to discover each one
/// the hard way later.
///
/// Runtime permissions work IDENTICALLY for sideloaded APKs and Play
/// Store installs — there is no Play-Store-only magic that auto-grants
/// permissions. Both have to call `Permission.x.request()` from the app
/// process. Apps that "just work" without prompting either don't need
/// dangerous permissions at all, or they request them lazily on first
/// use; we batch them here because almost every feature in this app
/// (calls, attendance, recording, notifications) needs at least one.
///
/// Permissions handled here, after the user is signed in:
///   * POST_NOTIFICATIONS    (Android 13+) — every user; local notifications
///     for approvals, call captures, summaries.
///   * READ_PHONE_STATE / READ_CALL_LOG / READ_CONTACTS / READ_MEDIA_AUDIO —
///     sales users only, and only after they accept the in-app "Call
///     logging" disclosure (Play's prominent-disclosure rule).
/// Location (attendance) and the microphone (voice notes) are asked for when
/// those features are first used; background location by location tracking
/// behind its own disclosure.
///
/// Once the walkthrough has run we remember that and never run it again
/// unless the user explicitly hits "Re-check permissions" in Settings.
class PermissionBootstrap extends ConsumerStatefulWidget {
  const PermissionBootstrap({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PermissionBootstrap> createState() =>
      _PermissionBootstrapState();
}

class _PermissionBootstrapState extends ConsumerState<PermissionBootstrap> {
  static const _boxName = 'tcb_onboarding';
  static const _doneKey = 'perm_bootstrap_done_v1';

  bool _running = false;

  static const List<Permission> _callPermissions = [
    Permission.phone,
    Permission.contacts,
    Permission.audio, // READ_MEDIA_AUDIO on A13+ (call recordings)
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRun());
  }

  Future<void> _maybeRun() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_running) return;
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) return; // runs again on sign-in (see build)

    final box = await _openBox();
    if (box.get(_doneKey) == true) return;

    _running = true;
    try {
      // Already granted / permanently denied permissions are no-ops; the user
      // only sees the system dialog for the ones that still need it.
      final toRequest = <Permission>[Permission.notification];
      if (profile.can('sees_sales') &&
          await ensureDisclosureAccepted(DataDisclosure.calls)) {
        toRequest.addAll(_callPermissions);
      }
      for (final p in toRequest) {
        try {
          await p.request();
        } catch (_) {/* skip; e.g. unsupported permission on this OS ver */}
      }
      await box.put(_doneKey, true);
    } finally {
      _running = false;
    }
  }

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  @override
  Widget build(BuildContext context) {
    // Re-trigger bootstrap whenever the auth state flips to authenticated
    // (covers first login + re-login after logout).
    ref.listen(callEventBridgeProvider, (_, __) {});
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated &&
          prev?.status != AuthStatus.authenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRun());
      }
    });
    return widget.child;
  }
}
