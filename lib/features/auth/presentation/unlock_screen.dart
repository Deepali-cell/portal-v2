import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../../../shared/widgets/brand_wordmark.dart';
import '../application/auth_controller.dart';
import '../application/lock_controller.dart';

/// Biometric gate shown once per session when a stored session is restored.
/// If the device has no biometrics, it unlocks automatically.
///
/// Layout note: uses a Stack with Positioned widgets rather than a Column
/// with Spacer. Column-plus-Spacer centers content in the *available*
/// space, so when the native Android BiometricPrompt appears (which some
/// OEMs — Realme, OPPO's ColorOS, OnePlus — expose to the app as a soft-
/// keyboard-style inset), the body shrinks and the whole layout squishes
/// upward or into a corner. Anchoring to `MediaQuery.size` (the full
/// screen height, unaffected by insets) keeps the brand + fingerprint
/// icon glued to their intended positions regardless of whether the
/// biometric prompt covers 40 % of the screen or 60 %. iOS shows Face ID
/// as a transient overlay that never reports as an inset, so the same
/// code path is safe there too.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attempt());
  }

  Future<void> _attempt() async {
    final biometrics = ref.read(biometricServiceProvider);
    if (!await biometrics.isAvailable()) {
      _unlock();
      return;
    }
    setState(() => _checking = true);
    final ok = await biometrics.authenticate(reason: 'Unlock ${AppConfig.brandName}');
    if (!mounted) return;
    if (ok) {
      _unlock();
    } else {
      setState(() => _checking = false);
    }
  }

  void _unlock() {
    if (!mounted) return;
    ref.read(sessionUnlockedProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // MediaQuery.of(context).size is the FULL screen size — it does NOT
    // change when the biometric prompt (or a keyboard) covers part of the
    // screen. viewInsets.bottom is what changes for those overlays, but we
    // deliberately don't consult it here: the whole point is to keep the
    // brand anchored to the same physical spot on the screen even when
    // the OS reports an inset.
    final screen = MediaQuery.of(context).size;
    return Scaffold(
      // Belt-and-braces: also disable inset resize so Scaffold doesn't try
      // to shrink the body. On most Androids this is redundant with the
      // Stack layout below, but on OEMs that treat the biometric prompt
      // like a keyboard, this flag is what stops the Scaffold from
      // resizing before our Stack even sees the constraints.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Brand block — pinned at 30% down from the top so it sits in
          // the natural focal area of the visible portion whether or not
          // the prompt is up.
          Positioned(
            top: screen.height * 0.28,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandWordmark(size: 72, showLabel: false),
                const SizedBox(height: AppDimens.xxl),
                Icon(Icons.fingerprint, size: 56, color: AppColors.navy),
                const SizedBox(height: AppDimens.lg),
                Text('Locked', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppDimens.xs),
                Text('Verify it\'s you to continue',
                    style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          // Action block — anchored to the bottom safe-area with fixed
          // padding, so it stays reachable if the prompt collapses and the
          // fallback Unlock / Sign-out buttons show up.
          Positioned(
            left: AppDimens.screenPadding,
            right: AppDimens.screenPadding,
            bottom: MediaQuery.of(context).padding.bottom + AppDimens.xl,
            child: _checking
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BrandButton(
                        label: 'Unlock',
                        icon: Icons.lock_open_outlined,
                        onPressed: _attempt,
                      ),
                      const SizedBox(height: AppDimens.md),
                      TextButton(
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .logout(),
                        child: const Text('Sign out instead'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
