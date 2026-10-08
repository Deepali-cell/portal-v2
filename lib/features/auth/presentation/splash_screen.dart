import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_wordmark.dart';

/// Shown while the persisted session is being resolved.
///
/// Uses a Stack with the brand pinned to a fixed screen fraction (not a
/// Center inside a Column, which centers within the *available* space —
/// on OEMs that treat the biometric prompt like a soft keyboard, that
/// would visibly collapse upward the moment the prompt appeared).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      // Prevent Scaffold from treating any bottom inset (biometric prompt,
      // keyboard, etc.) as a signal to shrink the body.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned(
            top: screen.height * 0.42,
            left: 0,
            right: 0,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandWordmark(size: 72),
                SizedBox(height: AppDimens.xxl),
                SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
