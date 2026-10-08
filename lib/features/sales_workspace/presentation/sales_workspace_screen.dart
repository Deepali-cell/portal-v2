import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/presentation/sales_dashboard_section.dart';
import '../../home/presentation/app_shell.dart';

/// The Sales workspace - one screen that hosts every CRM surface in a
/// tabbed layout so Home stays clean. Reached via the "Sales workspace"
/// card on Home (visible only to `sees_sales` users).
///
/// Four tabs:
///   Overview   – the SalesDashboardSection that used to live on Home
///   Pipeline   – funnel view (leads/deals + team/mine toggle)
///   Calls      – Call Detection settings (Android) + link to the
///                per-lead Calls tab that already exists in Lead detail
///   Team       – Leaderboard + Team status + Field team map (manager only)
///
/// The Leads and Deals *lists* keep their own bottom-nav tabs; this
/// workspace is for the "manager / analytical" surfaces.
class SalesWorkspaceScreen extends ConsumerStatefulWidget {
  const SalesWorkspaceScreen({super.key});
  @override
  ConsumerState<SalesWorkspaceScreen> createState() =>
      _SalesWorkspaceScreenState();
}

class _SalesWorkspaceScreenState extends ConsumerState<SalesWorkspaceScreen>
    with TickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    // Rebuild tab count once profile is known (managers get 4 tabs; sales
    // reps get 3). Default to 3 tabs; recreated in didChangeDependencies.
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = ref.read(authControllerProvider).profile;
    final isManager = profile?.can('manager_view') ?? false;
    final count = isManager ? 4 : 3;
    if (_tabs.length != count) {
      _tabs.dispose();
      _tabs = TabController(length: count, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    final isManager = profile?.can('manager_view') ?? false;
    final isAndroid = !kIsWeb && Platform.isAndroid;

    final tabs = <Tab>[
      const Tab(text: 'Overview'),
      const Tab(text: 'Pipeline'),
      const Tab(text: 'Calls'),
      if (isManager) const Tab(text: 'Team'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Sales workspace'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(salesDashboardProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.primary,
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const _OverviewTab(),
          const _PipelineTab(),
          _CallsTab(isAndroid: isAndroid),
          if (isManager) _TeamTab(isAndroid: isAndroid),
        ],
      ),
      bottomNavigationBar: const PersistentBottomNav(),
    );
  }
}

// ============================================================================
// Overview - the SalesDashboardSection that used to sit on Home.
// ============================================================================

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppDimens.md),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimens.md),
          child: SalesDashboardSection(),
        ),
      ],
    );
  }
}

// ============================================================================
// Pipeline - links to the Pipeline and Kanban screens (each their own route).
// ============================================================================

class _PipelineTab extends StatelessWidget {
  const _PipelineTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimens.md),
      children: [
        _WorkspaceCard(
          icon: Icons.insights_outlined,
          title: 'Funnel view',
          subtitle: 'See leads and deals by stage. Filter by period + owner.',
          onTap: () => context.push(Routes.pipeline),
        ),
        const SizedBox(height: AppDimens.md),
        _WorkspaceCard(
          icon: Icons.view_kanban_outlined,
          title: 'Kanban board',
          subtitle: 'Drag leads across stages, SalesMax-style.',
          onTap: () => context.push(Routes.leadKanban),
        ),
      ],
    );
  }
}

// ============================================================================
// Calls - Call Detection settings + shortcut copy explaining per-lead calls.
// ============================================================================

class _CallsTab extends StatelessWidget {
  const _CallsTab({required this.isAndroid});
  final bool isAndroid;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimens.md),
      children: [
        if (isAndroid)
          _WorkspaceCard(
            icon: Icons.ring_volume_outlined,
            title: 'Call detection',
            subtitle:
                'Caller-ID popup, auto recording upload, AI summaries. Manage permissions here.',
            onTap: () => context.push(Routes.callDetection),
          )
        else
          _InfoCard(
            icon: Icons.info_outline,
            title: 'Call detection (Android only)',
            body:
                'Live caller-ID and auto recording are not supported on iOS due to Apple sandbox restrictions.',
          ),
        const SizedBox(height: AppDimens.md),
        _InfoCard(
          icon: Icons.history_outlined,
          title: 'Per-lead call history',
          body:
              "Open any Lead or Deal and switch to the Calls tab there. Every logged call, recording, and AI summary lives on the record it belongs to.",
        ),
      ],
    );
  }
}

// ============================================================================
// Team - manager-only. Leaderboard + Team status + Field team map.
// ============================================================================

class _TeamTab extends StatelessWidget {
  const _TeamTab({required this.isAndroid});
  final bool isAndroid;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimens.md),
      children: [
        _WorkspaceCard(
          icon: Icons.emoji_events_outlined,
          title: 'Leaderboard',
          subtitle: 'Sales performance for the current period.',
          onTap: () => context.push(Routes.leaderboard),
        ),
        const SizedBox(height: AppDimens.md),
        _WorkspaceCard(
          icon: Icons.groups_2_outlined,
          title: 'Team status',
          subtitle: 'Live who is online, calls made today, active follow-ups.',
          onTap: () => context.push(Routes.teamStatus),
        ),
        if (isAndroid) ...[
          const SizedBox(height: AppDimens.md),
          _WorkspaceCard(
            icon: Icons.map_outlined,
            title: 'Field team',
            subtitle:
                'Live location list + map. See where every trackable reportee is right now.',
            onTap: () => context.push(Routes.locationTeam),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// Reusable card widgets
// ============================================================================

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
