import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../todays_plan/application/todays_plan_controller.dart';
import '../../todays_plan/domain/models.dart';

/// Full-screen dashboard of everything the user has missed.
///
/// Reuses the `todaysPlanControllerProvider` data — the endpoint already
/// returns the overdue + uncontacted-leads buckets. This screen just gives
/// them a permanent home (the home-screen card is a summary; this is the
/// drill-down where the user can work through the backlog).
///
/// Filter chips let the user focus on one bucket at a time (overdue tasks
/// vs overdue follow-ups vs uncontacted leads).
class MissedActivitiesScreen extends ConsumerStatefulWidget {
  const MissedActivitiesScreen({super.key});

  @override
  ConsumerState<MissedActivitiesScreen> createState() =>
      _MissedActivitiesScreenState();
}

enum _Filter { all, tasks, followups, leads }

class _MissedActivitiesScreenState
    extends ConsumerState<MissedActivitiesScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(todaysPlanControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Missed activities'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.read(todaysPlanControllerProvider.notifier).reload(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e is ApiException
              ? e.message
              : 'Could not load missed activities. Pull to refresh.',
          onRetry: () =>
              ref.read(todaysPlanControllerProvider.notifier).reload(),
        ),
        data: (plan) => RefreshIndicator(
          onRefresh: () =>
              ref.read(todaysPlanControllerProvider.notifier).reload(),
          child: _Body(
            plan: plan,
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: AppDimens.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.plan,
    required this.filter,
    required this.onFilter,
  });
  final TodaysPlan plan;
  final _Filter filter;
  final ValueChanged<_Filter> onFilter;

  bool get _isEmpty =>
      plan.overdueTasks.isEmpty &&
      plan.overdueCrmTasks.isEmpty &&
      plan.uncontactedLeads.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [const SizedBox(height: 80), _EmptyState()],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding, AppDimens.md, AppDimens.screenPadding, AppDimens.xl),
      children: [
        _Summary(plan: plan),
        const SizedBox(height: AppDimens.md),
        _FilterBar(active: filter, onChanged: onFilter, plan: plan),
        const SizedBox(height: AppDimens.md),
        if (filter == _Filter.all || filter == _Filter.tasks) ...[
          if (plan.overdueTasks.isNotEmpty)
            _Section(
              title: 'Overdue tasks · ${plan.overdueTasks.length}',
              tone: _Tone.danger,
              children: plan.overdueTasks.map((t) => _TaskTile(task: t)).toList(),
            ),
        ],
        if (filter == _Filter.all || filter == _Filter.followups) ...[
          if (plan.overdueCrmTasks.isNotEmpty)
            _Section(
              title: 'Overdue follow-ups · ${plan.overdueCrmTasks.length}',
              tone: _Tone.danger,
              children: plan.overdueCrmTasks
                  .map((t) => _CrmTaskTile(task: t))
                  .toList(),
            ),
        ],
        if (filter == _Filter.all || filter == _Filter.leads) ...[
          if (plan.uncontactedLeads.isNotEmpty)
            _Section(
              title: 'Uncontacted leads · ${plan.uncontactedLeads.length}',
              tone: _Tone.info,
              children: plan.uncontactedLeads
                  .map((l) => _LeadTile(lead: l))
                  .toList(),
            ),
        ],
      ],
    );
  }
}

// =========================================================================
// Summary header
// =========================================================================

class _Summary extends StatelessWidget {
  const _Summary({required this.plan});
  final TodaysPlan plan;
  @override
  Widget build(BuildContext context) {
    final overdueTotal =
        plan.overdueTasks.length + plan.overdueCrmTasks.length;
    final leadTotal = plan.uncontactedLeads.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            Expanded(
              child: _MetricBlock(
                label: 'Overdue',
                value: overdueTotal,
                colour: AppColors.error,
                icon: Icons.error_outline,
              ),
            ),
            Container(width: 1, height: 36, color: AppColors.outlineVariant),
            Expanded(
              child: _MetricBlock(
                label: 'Uncontacted',
                value: leadTotal,
                colour: AppColors.warning,
                icon: Icons.person_search,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.colour,
    required this.icon,
  });
  final String label;
  final int value;
  final Color colour;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: colour, size: 22),
        const SizedBox(height: 4),
        Text('$value',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.onSurface, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ],
    );
  }
}

// =========================================================================
// Filter chips
// =========================================================================

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.active,
    required this.onChanged,
    required this.plan,
  });
  final _Filter active;
  final ValueChanged<_Filter> onChanged;
  final TodaysPlan plan;

  @override
  Widget build(BuildContext context) {
    final all = plan.overdueTasks.length +
        plan.overdueCrmTasks.length +
        plan.uncontactedLeads.length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'All · $all',
            active: active == _Filter.all,
            onTap: () => onChanged(_Filter.all),
          ),
          const SizedBox(width: AppDimens.xs),
          _Chip(
            label: 'Tasks · ${plan.overdueTasks.length}',
            active: active == _Filter.tasks,
            onTap: () => onChanged(_Filter.tasks),
          ),
          const SizedBox(width: AppDimens.xs),
          _Chip(
            label: 'Follow-ups · ${plan.overdueCrmTasks.length}',
            active: active == _Filter.followups,
            onTap: () => onChanged(_Filter.followups),
          ),
          const SizedBox(width: AppDimens.xs),
          _Chip(
            label: 'Leads · ${plan.uncontactedLeads.length}',
            active: active == _Filter.leads,
            onTap: () => onChanged(_Filter.leads),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// Sections
// =========================================================================

enum _Tone { neutral, danger, info }

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.tone,
    required this.children,
  });
  final String title;
  final _Tone tone;
  final List<Widget> children;

  Color get _accent {
    switch (tone) {
      case _Tone.danger:
        return AppColors.error;
      case _Tone.info:
        return AppColors.secondary;
      case _Tone.neutral:
        return AppColors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.md, AppDimens.md, AppDimens.md, AppDimens.sm),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
            ),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 56, color: AppColors.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}

// =========================================================================
// Tiles
// =========================================================================

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});
  final PlanTask task;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => AppNav.go(context, Routes.tasks),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md, vertical: AppDimens.sm),
        child: Row(
          children: [
            Icon(Icons.assignment_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.subject.isEmpty ? '(no subject)' : task.subject,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (task.daysOverdue != null || task.priority != null)
                    Text(
                      [
                        if (task.daysOverdue != null && task.daysOverdue! > 0)
                          '${task.daysOverdue} ${task.daysOverdue == 1 ? "day" : "days"} overdue',
                        if (task.priority != null) task.priority!,
                        if (task.project != null) task.project!,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _CrmTaskTile extends StatelessWidget {
  const _CrmTaskTile({required this.task});
  final PlanCrmTask task;

  void _openLinked(BuildContext context) {
    final dt = task.referenceDoctype;
    final dn = task.referenceDocname;
    if (dt == 'Lead' && dn != null) {
      context.push(Routes.leadDetail, extra: dn);
    } else if (dt == 'Opportunity' && dn != null) {
      context.push(Routes.dealDetail, extra: dn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openLinked(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md, vertical: AppDimens.sm),
        child: Row(
          children: [
            Icon(Icons.phone_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title.isEmpty ? '(no title)' : task.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    [
                      if (task.daysOverdue != null && task.daysOverdue! > 0)
                        '${task.daysOverdue} ${task.daysOverdue == 1 ? "day" : "days"} overdue',
                      if (task.linkedLabel != null) task.linkedLabel!,
                      if (task.priority != null) task.priority!,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({required this.lead});
  final PlanLead lead;

  Future<void> _call(BuildContext context) async {
    final num = lead.mobileNo?.trim();
    if (num == null || num.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: num);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(Routes.leadDetail, extra: lead.name),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md, vertical: AppDimens.sm),
        child: Row(
          children: [
            Icon(Icons.person_outline, size: 18, color: AppColors.primary),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      lead.leadName.isEmpty
                          ? '(unnamed lead)'
                          : lead.leadName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    [
                      '${lead.daysSinceCreated} ${lead.daysSinceCreated == 1 ? "day" : "days"} old',
                      if (lead.source != null && lead.source!.isNotEmpty)
                        lead.source!,
                      if (lead.mobileNo != null && lead.mobileNo!.isNotEmpty)
                        lead.mobileNo!,
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (lead.mobileNo != null && lead.mobileNo!.isNotEmpty)
              IconButton(
                tooltip: 'Call',
                icon: Icon(Icons.call, size: 18, color: AppColors.primary),
                onPressed: () => _call(context),
              ),
            Icon(Icons.chevron_right,
                size: 20, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.xl),
      child: Column(
        children: [
          Icon(Icons.celebration_outlined,
              size: 48, color: AppColors.tertiaryFixedDim),
          const SizedBox(height: AppDimens.md),
          Text("Nothing missed.",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            "Every task and follow-up is on schedule, and there are no untouched leads.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
