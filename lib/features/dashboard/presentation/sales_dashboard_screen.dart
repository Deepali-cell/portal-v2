import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../data/sales_cycle_repository.dart';
import '../domain/module_flow.dart';
import 'flow_diagram.dart';
import 'module_dashboard_scaffold.dart';

/// Sales module dashboard. The headline is the live order-to-cash flow:
/// Customer → Quotation → Sales Order → Delivery Note → Invoice, each stage
/// with a live count + value and a tap-through to its list.
class SalesDashboardScreen extends ConsumerWidget {
  const SalesDashboardScreen({super.key});

  static const _hints = ['order', 'deliver', 'bill', 'collect'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesCycleProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Sales'),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(salesCycleProvider);
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              AppDimens.md,
              AppDimens.screenPadding,
              AppDimens.xl,
            ),
            children: [
              const ModuleDashboardHeader(
                title: 'Sales',
                subtitle: 'Quotation to payment, stage by stage',
                icon: Icons.point_of_sale_outlined,
              ),
              const SizedBox(height: AppDimens.lg),
              const DashboardSectionTitle(
                'Sales flow',
                subtitle: 'Tap any stage to open its list',
              ),
              const SizedBox(height: AppDimens.md),
              async.when(
                loading: () => const FlowSkeleton(rows: 5),
                error: (e, _) => FlowLoadError(message: '$e'),
                data: (flow) => FlowDiagram(stages: _stages(flow)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<FlowStage> _stages(ModuleFlow flow) {
    final out = <FlowStage>[];
    for (var i = 0; i < flow.stages.length; i++) {
      final s = flow.stages[i];
      out.add(
        FlowStage(
          label: s.label,
          count: s.count,
          value: s.value,
          icon: flowIconFor(s.icon),
          color: flowColorFor(s.color),
          route: s.route,
          hint: i < _hints.length ? _hints[i] : null,
        ),
      );
    }
    return out;
  }
}
