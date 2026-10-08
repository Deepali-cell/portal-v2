import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import '../data/dashboard_repository.dart';
import '../domain/models.dart';
import '../domain/module_flow.dart';
import 'flow_diagram.dart';
import 'module_dashboard_scaffold.dart';
import 'sales_dashboard_section.dart';
import '../../home/presentation/nav_destinations.dart';

/// CRM module dashboard. The headline is the live pipeline flow —
/// Leads → Opportunities → Converted — followed by the full sales workspace
/// detail (today's KPIs, follow-ups, leads/deals by status).
class CrmDashboardScreen extends ConsumerWidget {
  const CrmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesDashboardProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('CRM'),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(salesDashboardProvider);
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
                title: 'CRM',
                subtitle: 'Your sales pipeline, end to end',
                icon: Icons.handshake_outlined,
              ),
              const SizedBox(height: AppDimens.lg),
              const DashboardSectionTitle(
                'Pipeline flow',
                subtitle: 'Tap any stage to open its list',
              ),
              const SizedBox(height: AppDimens.md),
              async.when(
                loading: () => const FlowSkeleton(),
                error: (e, _) => FlowLoadError(message: '$e'),
                data: (d) => FlowDiagram(stages: _crmStages(d)),
              ),
              const SizedBox(height: AppDimens.xl),
              const _SalesToolsSection(),
              const SizedBox(height: AppDimens.xl),
              const DashboardSectionTitle('Details'),
              const SizedBox(height: AppDimens.sm),
              // Full existing sales dashboard (KPIs, follow-ups, status grids).
              const SalesDashboardSection(),
            ],
          ),
        ),
      ),
    );
  }

  List<FlowStage> _crmStages(SalesDashboard d) {
    int sum(List<StatusBucket> b) => b.fold(0, (acc, e) => acc + e.count);
    final leads = sum(d.leadStatuses);
    final opps = sum(d.dealStatuses);
    final won = d.dealStatuses
        .where((e) => e.status.toLowerCase() == 'won')
        .fold(0, (acc, e) => acc + e.count);
    return [
      FlowStage(
        label: 'Leads',
        count: leads,
        icon: Icons.person_search_outlined,
        color: AppColors.primary,
        route: Routes.leads,
        hint: 'qualify',
      ),
      FlowStage(
        label: 'Opportunities',
        count: opps,
        icon: Icons.handshake_outlined,
        color: const Color(0xFF1F4F8E),
        route: Routes.deals,
        hint: 'convert',
      ),
      FlowStage(
        label: 'Customers',
        count: won,
        value: d.today.monthWonValue,
        icon: Icons.storefront_outlined,
        color: const Color(0xFF1B7F4D),
        route: Routes.salesCustomer,
      ),
    ];
  }
}

/// Secondary CRM surfaces that don't earn a bottom-nav tab of their own —
/// Kanban board, leaderboard and the live field-team map. Shown as compact
/// tappable chips so nothing that used to live in the old Sales Workspace is
/// lost. Each entry is role/platform gated.
class _SalesToolsSection extends ConsumerWidget {
  const _SalesToolsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    final isManager = profile?.can('manager_view') ?? false;
    final isAndroid = !kIsWeb && Platform.isAndroid;

    final tools = <_ToolChip>[
      if (screenOn(profile, 'crm.kanban'))
        const _ToolChip(
          icon: Icons.view_kanban_outlined,
          label: 'Kanban board',
          route: Routes.leadKanban,
        ),
      if (isManager && screenOn(profile, 'crm.leaderboard'))
        const _ToolChip(
          icon: Icons.emoji_events_outlined,
          label: 'Leaderboard',
          route: Routes.leaderboard,
        ),
      if (isManager && isAndroid && screenOn(profile, 'crm.field_team'))
        const _ToolChip(
          icon: Icons.map_outlined,
          label: 'Field team',
          route: Routes.locationTeam,
        ),
    ];
    if (tools.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionTitle('Sales tools', subtitle: 'More CRM views'),
        const SizedBox(height: AppDimens.md),
        Wrap(spacing: AppDimens.sm, runSpacing: AppDimens.sm, children: tools),
      ],
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md,
            vertical: AppDimens.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
