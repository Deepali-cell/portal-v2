import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../dashboard/domain/module_flow.dart';
import '../../dashboard/presentation/flow_diagram.dart';
import '../../dashboard/presentation/module_dashboard_scaffold.dart';
import '../application/dashboard_provider.dart';
import '../domain/dashboard_models.dart';

/// Manufacturing module dashboard. Headline is the live shop-floor flow —
/// BOM → Work Orders → Job Cards → Finished — each stage tapping through to its
/// list. Below it: a work-order status breakdown and the most recent orders
/// with their production progress.
class ManufacturingDashboardScreen extends ConsumerWidget {
  const ManufacturingDashboardScreen({super.key});

  static const _wo = Color(0xFF2563EB); // blue
  static const _jc = Color(0xFF7C3AED); // violet
  static const _done = Color(0xFF15803D); // green
  static const _bom = Color(0xFF0891B2); // cyan

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(manufacturingDashboardProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Manufacturing'),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(manufacturingDashboardProvider);
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
                AppDimens.md, AppDimens.screenPadding, AppDimens.xl),
            children: [
              const ModuleDashboardHeader(
                title: 'Manufacturing',
                subtitle: 'From BOM to finished goods, stage by stage',
                icon: Icons.precision_manufacturing_outlined,
              ),
              const SizedBox(height: AppDimens.lg),
              const DashboardSectionTitle(
                'Production flow',
                subtitle: 'Tap any stage to open its list',
              ),
              const SizedBox(height: AppDimens.md),
              async.when(
                loading: () => const FlowSkeleton(rows: 4),
                error: (e, _) => FlowLoadError(message: '$e'),
                data: (d) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FlowDiagram(stages: _stages(d)),
                    const SizedBox(height: AppDimens.lg),
                    const DashboardSectionTitle('Work order status'),
                    const SizedBox(height: AppDimens.sm),
                    _StatusWrap(counts: d.workOrders),
                    const SizedBox(height: AppDimens.lg),
                    const DashboardSectionTitle('Job cards'),
                    const SizedBox(height: AppDimens.sm),
                    _JobCardWrap(counts: d.jobCards),
                    const SizedBox(height: AppDimens.lg),
                    DashboardSectionTitle(
                      'Recent work orders',
                      subtitle: d.recentWorkOrders.isEmpty
                          ? 'Nothing in production yet'
                          : 'Latest ${d.recentWorkOrders.length}',
                    ),
                    const SizedBox(height: AppDimens.sm),
                    for (final wo in d.recentWorkOrders) _RecentRow(wo: wo),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<FlowStage> _stages(ManufacturingDashboard d) => [
        FlowStage(
          label: 'BOMs',
          count: d.activeBoms,
          icon: Icons.account_tree_outlined,
          color: _bom,
          route: Routes.mfgBom,
          hint: 'produce',
        ),
        FlowStage(
          label: 'Work orders (open)',
          count: d.openWorkOrders,
          icon: Icons.precision_manufacturing_outlined,
          color: _wo,
          route: Routes.mfgWorkOrder,
          hint: 'release',
        ),
        FlowStage(
          label: 'Job cards (open)',
          count: d.openJobCards,
          icon: Icons.assignment_outlined,
          color: _jc,
          route: Routes.mfgJobCard,
          hint: 'finish',
        ),
        FlowStage(
          label: 'Completed orders',
          count: d.workOrders.completed,
          icon: Icons.check_circle_outline,
          color: _done,
          route: Routes.mfgWorkOrder,
        ),
      ];
}

class _StatusWrap extends StatelessWidget {
  const _StatusWrap({required this.counts});
  final MfgWorkOrderCounts counts;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimens.sm,
      runSpacing: AppDimens.sm,
      children: [
        _StatChip(
            label: 'Draft', value: counts.draft, color: AppColors.onSurfaceVariant),
        _StatChip(
            label: 'Not started',
            value: counts.notStarted,
            color: const Color(0xFFB54708)),
        _StatChip(
            label: 'In process',
            value: counts.inProcess,
            color: const Color(0xFF2563EB)),
        _StatChip(
            label: 'Stopped',
            value: counts.stopped,
            color: AppColors.error),
        _StatChip(
            label: 'Completed',
            value: counts.completed,
            color: const Color(0xFF15803D)),
      ],
    );
  }
}

class _JobCardWrap extends StatelessWidget {
  const _JobCardWrap({required this.counts});
  final MfgJobCardCounts counts;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimens.sm,
      runSpacing: AppDimens.sm,
      children: [
        _StatChip(label: 'Open', value: counts.open, color: const Color(0xFFB54708)),
        _StatChip(
            label: 'In progress',
            value: counts.wip,
            color: const Color(0xFF2563EB)),
        _StatChip(
            label: 'Transferred',
            value: counts.materialTransferred,
            color: const Color(0xFF7C3AED)),
        _StatChip(
            label: 'Completed',
            value: counts.completed,
            color: const Color(0xFF15803D)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.wo});
  final MfgRecentWorkOrder wo;
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        onTap: () => AppNav.go(context, Routes.mfgWorkOrder),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      wo.itemLabel.isEmpty ? wo.name : wo.itemLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _StatusBadge(status: wo.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: wo.progress,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceContainer,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF15803D)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_fmt(wo.producedQty)}/${_fmt(wo.qty)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Completed' => const Color(0xFF15803D),
      'In Process' => const Color(0xFF2563EB),
      'Stopped' => AppColors.error,
      'Not Started' => const Color(0xFFB54708),
      _ => AppColors.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.isEmpty ? 'Draft' : status,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
