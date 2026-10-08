import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/reports_controller.dart';
import '../domain/models.dart';
import 'report_view_screen.dart';

/// Lists the reports the current user may run inside one module. Each report is
/// gated per-role on the backend (its ERPNext Report roles), so this only shows
/// what the user is allowed to see. Rendered as a set of tappable cards with a
/// coloured icon per report for a quick, scannable feel.
class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({
    super.key,
    required this.module,
    required this.title,
  });

  final String module;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(moduleReportsProvider(module));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(moduleReportsProvider(module)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorRetry(
          message: '$e',
          onRetry: () => ref.invalidate(moduleReportsProvider(module)),
        ),
        data: (modules) {
          final reports = [
            for (final m in modules)
              if (m.module == module) ...m.reports,
          ];
          if (reports.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(moduleReportsProvider(module)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.md, AppDimens.md, AppDimens.md, AppDimens.xl),
              children: [
                _ModuleBanner(module: module, count: reports.length),
                const SizedBox(height: AppDimens.md),
                for (var i = 0; i < reports.length; i++) ...[
                  _ReportCard(report: reports[i], index: i),
                  if (i != reports.length - 1)
                    const SizedBox(height: AppDimens.sm),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A soft gradient header that anchors the module's report list.
class _ModuleBanner extends StatelessWidget {
  const _ModuleBanner({required this.module, required this.count});
  final String module;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.onPrimaryFixedVariant],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: const Icon(Icons.insights, color: Colors.white, size: 26),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$module Reports',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count report${count == 1 ? '' : 's'} available for you',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
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

/// One report as a tappable card with a coloured leading tile.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.index});
  final ReportRef report;
  final int index;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(index);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        onTap: () => context.push(
          Routes.reportView,
          extra: ReportViewArgs(
            reportKey: report.key,
            label: report.label,
            hasDateRange: report.hasDateRange,
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Icon(_iconFor(report.key), color: accent, size: 24),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.report,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// A palette of accent colours cycled per card so the list feels lively while
/// staying tenant-neutral.
Color _accentFor(int index) {
  const palette = [
    Color(0xFF2563EB), // blue
    Color(0xFF059669), // green
    Color(0xFF7C3AED), // violet
    Color(0xFFEA580C), // orange
    Color(0xFF0891B2), // cyan
    Color(0xFFDB2777), // pink
  ];
  return palette[index % palette.length];
}

/// A best-effort icon per report key; falls back to a generic chart icon.
IconData _iconFor(String key) {
  const map = {
    'acc_pl': Icons.trending_up,
    'acc_bs': Icons.account_balance,
    'acc_tb': Icons.balance,
    'acc_gl': Icons.menu_book,
    'acc_cf': Icons.water_drop,
    'sal_register': Icons.receipt_long,
    'sal_analytics': Icons.query_stats,
    'sal_gross_profit': Icons.savings,
    'sal_receivable': Icons.call_received,
    'pur_register': Icons.shopping_cart,
    'pur_analytics': Icons.insights,
    'pur_payable': Icons.call_made,
    'stk_balance': Icons.inventory_2,
    'stk_ledger': Icons.list_alt,
  };
  return map[key] ?? Icons.assessment_outlined;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_off_outlined,
                  size: 48, color: AppColors.outline),
              const SizedBox(height: AppDimens.md),
              Text(
                'No reports available for your role in this module.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: AppDimens.md),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
