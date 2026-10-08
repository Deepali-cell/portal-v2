import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';

/// Shared chrome for every per-module dashboard: a branded gradient header
/// that names the module and explains, in one line, that the diagram below is
/// the module's live flow. Keeps all module dashboards visually consistent.
class ModuleDashboardHeader extends StatelessWidget {
  const ModuleDashboardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.graphite, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.graphite.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder rows shown while a flow's counts are loading.
class FlowSkeleton extends StatelessWidget {
  const FlowSkeleton({super.key, this.rows = 3});
  final int rows;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        rows,
        (i) => Container(
          margin: EdgeInsets.only(bottom: i == rows - 1 ? 0 : AppDimens.md),
          height: 66,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          ),
        ),
      ),
    );
  }
}

/// Error card for a failed flow fetch.
class FlowLoadError extends StatelessWidget {
  const FlowLoadError({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.onErrorContainer),
      ),
    );
  }
}

/// Small section title used between dashboard blocks (flow / details).
class DashboardSectionTitle extends StatelessWidget {
  const DashboardSectionTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
