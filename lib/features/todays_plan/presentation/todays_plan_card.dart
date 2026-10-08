import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/todays_plan_controller.dart';
import '../domain/models.dart';
import '../../home/presentation/nav_destinations.dart';
import '../../auth/application/auth_controller.dart';

/// Salesperson's command-centre card. Rendered as the first card on the home
/// screen for users with sales capabilities.
///
/// Layout:
///  - Header strip with overdue / due-today / uncontacted counts as badges.
///  - Section per non-empty bucket. Skip sections when empty so the card
///    isn't a wall of placeholders.
///  - Tap a row to jump to the linked Lead/Deal/Task.
class TodaysPlanCard extends ConsumerWidget {
  const TodaysPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todaysPlanControllerProvider);
    return async.when(
      loading: () => const _CardShell(child: _Loading()),
      error: (e, _) => _CardShell(
        child: _Error(
          message: e is ApiException
              ? e.message
              : "Couldn't load today's plan. Pull to refresh.",
          onRetry: () =>
              ref.read(todaysPlanControllerProvider.notifier).reload(),
        ),
      ),
      data: (plan) => _CardShell(
        child: _Content(
          plan: plan,
          onReload: () =>
              ref.read(todaysPlanControllerProvider.notifier).reload(),
        ),
      ),
    );
  }
}

// =========================================================================
// Shell
// =========================================================================

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(AppDimens.md), child: child),
    );
  }
}

// =========================================================================
// Loading / error
// =========================================================================

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppDimens.md),
        Text(
          "Loading today's plan…",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppDimens.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// Content
// =========================================================================

class _Content extends StatelessWidget {
  const _Content({required this.plan, required this.onReload});
  final TodaysPlan plan;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    if (plan.isEmpty) return _EmptyState(onReload: onReload);
    final sections = <Widget>[];
    if (plan.overdueTasks.isNotEmpty || plan.overdueCrmTasks.isNotEmpty) {
      sections.add(
        _OverdueSection(
          tasks: plan.overdueTasks,
          crmTasks: plan.overdueCrmTasks,
        ),
      );
    }
    if (plan.tasksToday.isNotEmpty || plan.crmTasksToday.isNotEmpty) {
      sections.add(
        _DueTodaySection(tasks: plan.tasksToday, crmTasks: plan.crmTasksToday),
      );
    }
    if (plan.uncontactedLeads.isNotEmpty) {
      sections.add(_UncontactedSection(leads: plan.uncontactedLeads));
    }

    final hasMissed = plan.overdue > 0 || plan.uncontactedLeadsCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(plan: plan, onReload: onReload),
        const SizedBox(height: AppDimens.md),
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const _Divider(),
          sections[i],
        ],
        if (hasMissed) ...[
          const SizedBox(height: AppDimens.xs),
          Consumer(
            builder: (ctx, ref, _) {
              final profile = ref.watch(authControllerProvider).profile;
              if (!screenOn(profile, 'crm.missed_activities')) {
                return const SizedBox.shrink();
              }
              return Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => ctx.push(Routes.missedActivities),
                  icon: const Icon(Icons.list_alt_outlined, size: 16),
                  label: const Text('View all missed'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.plan, required this.onReload});
  final TodaysPlan plan;
  final VoidCallback onReload;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's Plan",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: AppDimens.xs,
                children: [
                  if (plan.overdue > 0)
                    _Pill(label: '${plan.overdue} overdue', tone: _Tone.danger),
                  if (plan.dueToday > 0)
                    _Pill(
                      label: '${plan.dueToday} due today',
                      tone: _Tone.warn,
                    ),
                  if (plan.uncontactedLeadsCount > 0)
                    _Pill(
                      label: '${plan.uncontactedLeadsCount} uncontacted',
                      tone: _Tone.info,
                    ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: Icon(Icons.refresh, size: 20, color: AppColors.primary),
          onPressed: onReload,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReload});
  final VoidCallback onReload;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.secondaryFixed,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.task_alt, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's Plan",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "You're all clear. No overdue items or new leads.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: Icon(Icons.refresh, size: 20, color: AppColors.primary),
          onPressed: onReload,
        ),
      ],
    );
  }
}

// =========================================================================
// Sections
// =========================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.tone = _Tone.neutral});
  final String label;
  final _Tone tone;
  @override
  Widget build(BuildContext context) {
    Color color;
    switch (tone) {
      case _Tone.danger:
        color = AppColors.danger;
        break;
      case _Tone.warn:
        color = AppColors.warning;
        break;
      case _Tone.info:
        color = AppColors.secondary;
        break;
      case _Tone.neutral:
        color = AppColors.onSurfaceVariant;
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.sm, bottom: AppDimens.xs),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _OverdueSection extends StatelessWidget {
  const _OverdueSection({required this.tasks, required this.crmTasks});
  final List<PlanTask> tasks;
  final List<PlanCrmTask> crmTasks;
  @override
  Widget build(BuildContext context) {
    final total = tasks.length + crmTasks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: 'Overdue · $total', tone: _Tone.danger),
        for (final t in tasks) _TaskRow(task: t, tone: _Tone.danger),
        for (final t in crmTasks) _CrmTaskRow(task: t, tone: _Tone.danger),
      ],
    );
  }
}

class _DueTodaySection extends StatelessWidget {
  const _DueTodaySection({required this.tasks, required this.crmTasks});
  final List<PlanTask> tasks;
  final List<PlanCrmTask> crmTasks;
  @override
  Widget build(BuildContext context) {
    final total = tasks.length + crmTasks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: 'Due today · $total', tone: _Tone.warn),
        for (final t in tasks) _TaskRow(task: t, tone: _Tone.warn),
        for (final t in crmTasks) _CrmTaskRow(task: t, tone: _Tone.warn),
      ],
    );
  }
}

class _UncontactedSection extends StatelessWidget {
  const _UncontactedSection({required this.leads});
  final List<PlanLead> leads;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          label: 'Uncontacted leads · ${leads.length}',
          tone: _Tone.info,
        ),
        for (final l in leads) _LeadRow(lead: l),
      ],
    );
  }
}

// =========================================================================
// Rows
// =========================================================================

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.tone});
  final PlanTask task;
  final _Tone tone;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => AppNav.go(context, Routes.tasks),
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.subject.isEmpty ? '(no subject)' : task.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (task.dueLabel != null ||
                      task.daysOverdue != null ||
                      task.priority != null ||
                      task.project != null)
                    Text(
                      [
                        if (task.daysOverdue != null && task.daysOverdue! > 0)
                          '${task.daysOverdue} ${task.daysOverdue == 1 ? "day" : "days"} overdue',
                        if (task.dueLabel != null && task.daysOverdue == null)
                          task.dueLabel!,
                        if (task.priority != null) task.priority!,
                        if (task.project != null) task.project!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _CrmTaskRow extends StatelessWidget {
  const _CrmTaskRow({required this.task, required this.tone});
  final PlanCrmTask task;
  final _Tone tone;

  void _openLinked(BuildContext context) {
    final dt = task.referenceDoctype;
    final dn = task.referenceDocname;
    if (dt == 'Lead' && dn != null) {
      context.push(Routes.leadDetail, extra: dn);
    } else if (dt == 'Opportunity' && dn != null) {
      context.push(Routes.dealDetail, extra: dn);
    } else {
      AppNav.go(context, Routes.tasks);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFollowup =
        task.referenceDoctype == 'Lead' ||
        task.referenceDoctype == 'Opportunity';
    return InkWell(
      onTap: () => _openLinked(context),
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isFollowup ? Icons.phone_outlined : Icons.task_alt_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title.isEmpty ? '(no title)' : task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    [
                      if (task.daysOverdue != null && task.daysOverdue! > 0)
                        '${task.daysOverdue} ${task.daysOverdue == 1 ? "day" : "days"} overdue',
                      if (task.dueLabel != null && task.daysOverdue == null)
                        task.dueLabel!,
                      if (task.linkedLabel != null) task.linkedLabel!,
                      if (task.priority != null) task.priority!,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadRow extends StatelessWidget {
  const _LeadRow({required this.lead});
  final PlanLead lead;

  Future<void> _call(BuildContext context) async {
    final num = lead.mobileNo?.trim();
    if (num == null || num.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: num);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the dialer.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push(Routes.leadDetail, extra: lead.name),
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 18, color: AppColors.primary),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.leadName.isEmpty ? '(unnamed lead)' : lead.leadName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    [
                      '${lead.daysSinceCreated} ${lead.daysSinceCreated == 1 ? "day" : "days"} old',
                      if (lead.source != null && lead.source!.isNotEmpty)
                        lead.source!,
                      if (lead.mobileNo != null && lead.mobileNo!.isNotEmpty)
                        lead.mobileNo!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
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
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// Bits
// =========================================================================

enum _Tone { neutral, danger, warn, info }

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});
  final String label;
  final _Tone tone;
  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (tone) {
      case _Tone.danger:
        bg = AppColors.errorContainer;
        fg = AppColors.onErrorContainer;
        break;
      case _Tone.warn:
        bg = AppColors.warning.withValues(alpha: 0.16);
        fg = AppColors.warning;
        break;
      case _Tone.info:
        bg = AppColors.secondaryFixed;
        fg = AppColors.onSecondaryFixed;
        break;
      case _Tone.neutral:
        bg = AppColors.surfaceContainer;
        fg = AppColors.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
      child: Divider(height: 1, color: AppColors.outlineVariant),
    );
  }
}
