import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../role_dashboards/data/role_dashboards_repository.dart';
import '../../role_dashboards/domain/models.dart';
import '../domain/module_flow.dart';
import 'flow_diagram.dart';
import 'module_dashboard_scaffold.dart';

/// Projects module dashboard — the day-start overview for the project team:
/// how many projects are open, how the task pipeline looks (due vs overdue),
/// unbilled timesheet hours, and the next deadlines to watch. Reuses the
/// existing projects summary endpoint + period controller.
class ProjectsDashboardScreen extends ConsumerWidget {
  const ProjectsDashboardScreen({super.key});

  static const _blue = Color(0xFF2563EB);
  static const _amber = Color(0xFFB54708);
  static const _red = Color(0xFFB42318);
  static const _green = Color(0xFF15803D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(projectsPeriodProvider);
    final async = ref.watch(projectsSummaryProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Projects'),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(projectsSummaryProvider);
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
                title: 'Projects',
                subtitle: 'Projects, tasks & timesheets at a glance',
                icon: Icons.folder_open_outlined,
              ),
              const SizedBox(height: AppDimens.md),
              _PeriodChips(active: period),
              const SizedBox(height: AppDimens.md),
              async.when(
                loading: () => const FlowSkeleton(rows: 4),
                error: (e, _) => FlowLoadError(
                  message: e is ApiException
                      ? e.message
                      : "Couldn't load projects. Try again.",
                ),
                data: (s) => _Body(summary: s),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodChips extends ConsumerWidget {
  const _PeriodChips({required this.active});
  final RolePeriod active;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        for (final p in RolePeriod.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(projectsPeriodProvider.notifier).set(p),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p == active
                      ? AppColors.primary
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p == active
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary});
  final ProjectsSummary summary;

  @override
  Widget build(BuildContext context) {
    final teamView = summary.scope == 'team';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardSectionTitle(
          teamView ? 'Team pipeline' : 'My work',
          subtitle: teamView
              ? 'Across every project you oversee'
              : 'Projects and tasks assigned to you',
        ),
        const SizedBox(height: AppDimens.sm),
        FlowDiagram(
          stages: [
            FlowStage(
              label: 'Active Projects',
              count: summary.myActiveProjects,
              icon: Icons.folder_open_outlined,
              color: ProjectsDashboardScreen._blue,
              route: Routes.projectsProject,
              hint: 'work',
            ),
            FlowStage(
              label: 'Tasks Due',
              count: summary.tasksDueInPeriod,
              icon: Icons.task_alt_outlined,
              color: ProjectsDashboardScreen._amber,
              route: Routes.tasks,
              hint: 'finish',
            ),
            FlowStage(
              label: 'Overdue',
              count: summary.tasksOverdue,
              icon: Icons.warning_amber_rounded,
              color: ProjectsDashboardScreen._red,
              route: Routes.tasks,
            ),
          ],
        ),
        const SizedBox(height: AppDimens.lg),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Draft timesheets',
                value: '${summary.draftTimesheetCount}',
                caption: 'Not submitted · last 30d',
                icon: Icons.access_time_outlined,
                color: ProjectsDashboardScreen._green,
                route: Routes.timesheet,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _StatCard(
                label: 'Overdue tasks',
                value: '${summary.tasksOverdue}',
                caption: 'Past their end date',
                icon: Icons.error_outline,
                color: ProjectsDashboardScreen._red,
                route: Routes.tasks,
              ),
            ),
          ],
        ),
        if (summary.nextDeadlines.isNotEmpty) ...[
          const SizedBox(height: AppDimens.lg),
          const DashboardSectionTitle(
            'Next deadlines',
            subtitle: 'The tasks coming up soonest',
          ),
          const SizedBox(height: AppDimens.sm),
          for (final d in summary.nextDeadlines) _DeadlineRow(item: d),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    this.route,
  });
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
    if (route == null) return card;
    return GestureDetector(onTap: () => context.push(route!), child: card);
  }
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({required this.item});
  final ProjectsDeadline item;

  @override
  Widget build(BuildContext context) {
    final overdue = item.daysLeft < 0;
    final soon = item.daysLeft >= 0 && item.daysLeft <= 2;
    final tint = overdue
        ? ProjectsDashboardScreen._red
        : (soon
              ? ProjectsDashboardScreen._amber
              : ProjectsDashboardScreen._blue);
    final badge = overdue
        ? '${item.daysLeft.abs()}d late'
        : (item.daysLeft == 0 ? 'today' : 'in ${item.daysLeft}d');
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: tint.withValues(alpha: 0.12),
              child: Icon(Icons.flag_outlined, size: 18, color: tint),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.subject.isEmpty ? '(untitled task)' : item.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    item.project.isEmpty
                        ? item.status
                        : '${item.project} · ${item.status}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: tint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
