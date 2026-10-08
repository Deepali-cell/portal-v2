import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';

/// Colour-coded pill rendering a Deal win-probability percent.
///
/// Bands:
///   * `null`           -> muted "—" pill (probability not yet set)
///   * `< 33%`          -> grey (low confidence)
///   * `33%..66%`       -> orange (mid)
///   * `> 66%`          -> green-leaning (high confidence / closing)
///
/// Out-of-range values clamp at 0/100 in the display so corrupt server-side
/// data never renders something nonsensical like "150%".
class ProbabilityPill extends StatelessWidget {
  const ProbabilityPill({super.key, required this.percent, this.dense = true});

  /// Value 0..100. `null` → render the "not set" muted pill.
  final double? percent;
  final bool dense;

  ({Color bg, Color fg, IconData icon}) _tone() {
    final p = percent;
    if (p == null) {
      return (
        bg: AppColors.surfaceContainer,
        fg: AppColors.onSurfaceVariant,
        icon: Icons.remove,
      );
    }
    if (p > 66) {
      return (
        bg: AppColors.tertiaryFixed,
        fg: AppColors.onTertiaryFixedVariant,
        icon: Icons.trending_up,
      );
    }
    if (p >= 33) {
      return (
        bg: AppColors.warning.withValues(alpha: 0.16),
        fg: AppColors.warning,
        icon: Icons.show_chart,
      );
    }
    return (
      bg: AppColors.surfaceContainer,
      fg: AppColors.onSurfaceVariant,
      icon: Icons.trending_flat,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _tone();
    final clamped = percent?.clamp(0.0, 100.0);
    final label = clamped == null ? 'Not set' : '${clamped.round()}%';
    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(t.icon, size: dense ? 12 : 16, color: t.fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: t.fg,
              fontSize: dense ? 11 : 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
