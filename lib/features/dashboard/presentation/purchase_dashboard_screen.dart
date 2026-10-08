import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../data/purchase_cycle_repository.dart';
import '../domain/module_flow.dart';
import 'flow_diagram.dart';
import 'module_dashboard_scaffold.dart';

/// Purchase module dashboard. The headline is the live procure-to-pay flow:
/// Material Request → RFQ → Supplier Quotation → Purchase Order → Goods
/// Receipt, each stage with a live count + value and a tap-through to its
/// list. Mirrors [SalesDashboardScreen] for the Purchase module.
class PurchaseDashboardScreen extends ConsumerWidget {
  const PurchaseDashboardScreen({super.key});

  // One connector hint between stages (there are up to 7 stages).
  static const _hints = ['quote', 'select', 'order', 'receive', 'bill', 'pay'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseCycleProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Purchase'),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(purchaseCycleProvider);
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
                title: 'Purchase',
                subtitle: 'Material request to payment, stage by stage',
                icon: Icons.shopping_cart_outlined,
              ),
              const SizedBox(height: AppDimens.lg),
              const DashboardSectionTitle(
                'Purchase flow',
                subtitle: 'Tap any stage to open its list',
              ),
              const SizedBox(height: AppDimens.md),
              async.when(
                loading: () => const FlowSkeleton(rows: 7),
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
