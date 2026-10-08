import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Colour-coded badge showing how many days since the last meaningful
/// contact with a lead. Used in the leads list (dense) and on the lead
/// detail header (full size). Hidden when `days` is null or 0.
///
/// Bands:
///   * 1-6 days  -> grey
///   * 7-13 days -> orange ("warning")
///   * 14+ days  -> red ("danger")
class FollowupGapBadge extends StatelessWidget {
  const FollowupGapBadge({super.key, required this.days, this.dense = true});
  final int days;
  final bool dense;

  ({Color bg, Color fg, IconData icon}) _tone() {
    if (days >= 14) {
      return (
        bg: AppColors.errorContainer,
        fg: AppColors.onErrorContainer,
        icon: Icons.error_outline,
      );
    }
    if (days >= 7) {
      return (
        bg: AppColors.warning.withValues(alpha: 0.16),
        fg: AppColors.warning,
        icon: Icons.schedule,
      );
    }
    return (
      bg: AppColors.surfaceContainer,
      fg: AppColors.onSurfaceVariant,
      icon: Icons.schedule_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _tone();
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
          Flexible(
            child: Text(
              '${days}d since last contact',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: t.fg,
                fontSize: dense ? 11 : 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
