import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../data/role_dashboards_repository.dart';
import '../domain/models.dart';

// ============================================================================
// Shared building blocks
// ============================================================================

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.periodChips,
    required this.child,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget periodChips;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFixed,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: AppDimens.sm),
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
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            periodChips,
            const SizedBox(height: AppDimens.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.active, required this.onChange});
  final RolePeriod active;
  final ValueChanged<RolePeriod> onChange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in RolePeriod.values) ...[
            _Chip(
              label: p.label,
              active: p == active,
              onTap: () => onChange(p),
            ),
            const SizedBox(width: AppDimens.xs),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.outlineVariant),
        ),
        child: Text(label,
            style: TextStyle(
              color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    this.tone = _Tone.primary,
  });

  final IconData icon;
  final String label;
  final String value;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _Tone.primary => (
          AppColors.surfaceContainerLowest,
          AppColors.primary,
        ),
      _Tone.warn => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
        ),
      _Tone.danger => (
          AppColors.errorContainer,
          AppColors.onErrorContainer,
        ),
      _Tone.success => (
          const Color(0xFFE7F5EC),
          const Color(0xFF1B7F4D),
        ),
    };

    return Container(
      constraints: const BoxConstraints(
        minHeight: 92,
      ),
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 16,
                color: fg,
              ),
              const SizedBox(width: 6),

              // Allow the label to wrap instead of showing "..."
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

enum _Tone { primary, warn, danger, success }

Widget _loading() => const SizedBox(
      height: 90,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );

Widget _error(Object e, VoidCallback onRetry) => Row(
      children: [
        Expanded(
          child: Text("Couldn't load. Tap retry.",
              style: TextStyle(color: AppColors.onSurfaceVariant)),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );

// ============================================================================
// HR section
// ============================================================================

class HrDashboardSection extends ConsumerWidget {
  const HrDashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(hrPeriodProvider);
    final async = ref.watch(hrSummaryProvider);
    return _SectionShell(
      title: 'HR at a glance',
      subtitle: 'Approvals + who needs attention',
      icon: Icons.people_alt_outlined,
      periodChips: _PeriodChips(
        active: period,
        onChange: (p) => ref.read(hrPeriodProvider.notifier).set(p),
      ),
      child: async.when(
        loading: _loading,
        error: (e, _) => _error(e, () => ref.invalidate(hrSummaryProvider)),
        data: (s) => _HrBody(summary: s),
      ),
    );
  }
}

class _HrBody extends StatelessWidget {
  const _HrBody({required this.summary});
  final HrSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.pending_actions_outlined,
                label: 'Pending leave Applications',
                value: '${summary.pendingLeaveApps}',
                tone: summary.pendingLeaveApps > 0 ? _Tone.warn : _Tone.primary,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.event_busy_outlined,
                label: 'Absent today',
                value: '${summary.absentToday}',
                tone: summary.absentToday > 0 ? _Tone.danger : _Tone.primary,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.logout_outlined,
                label: 'Exits <30d Reliving',
                value: '${summary.upcomingExits}',
              ),
            ),
          ],
        ),
        if (summary.birthdays.isNotEmpty) ...[
          const SizedBox(height: AppDimens.md),
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.cake_outlined,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Birthdays this week',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                for (final b in summary.birthdays) _birthdayRow(context, b),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _birthdayRow(BuildContext context, HrBirthday b) {
    final label = switch (b.daysAway) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => 'in ${b.daysAway} days',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              b.designation.isEmpty
                  ? b.employeeName
                  : '${b.employeeName}  ·  ${b.designation}',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ============================================================================
// Projects section
// ============================================================================

class ProjectsDashboardSection extends ConsumerWidget {
  const ProjectsDashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(projectsPeriodProvider);
    final async = ref.watch(projectsSummaryProvider);
    return _SectionShell(
      title: 'Projects',
      subtitle: 'What you own, what is due',
      icon: Icons.dashboard_customize_outlined,
      periodChips: _PeriodChips(
        active: period,
        onChange: (p) => ref.read(projectsPeriodProvider.notifier).set(p),
      ),
      child: async.when(
        loading: _loading,
        error: (e, _) =>
            _error(e, () => ref.invalidate(projectsSummaryProvider)),
        data: (s) => _ProjectsBody(summary: s),
      ),
    );
  }
}

class _ProjectsBody extends StatelessWidget {
  const _ProjectsBody({required this.summary});
  final ProjectsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.folder_open_outlined,
                label: 'Active projects',
                value: '${summary.myActiveProjects}',
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.timer_outlined,
                label: 'Tasks due',
                value: '${summary.tasksDueInPeriod}',
                tone:
                    summary.tasksDueInPeriod > 0 ? _Tone.warn : _Tone.primary,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.error_outline,
                label: 'Overdue',
                value: '${summary.tasksOverdue}',
                tone: summary.tasksOverdue > 0 ? _Tone.danger : _Tone.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.sm),
        _KpiTile(
          icon: Icons.receipt_long_outlined,
          label: 'Unbilled timesheet hours (last 30d)',
          value: summary.unbilledTimesheetHours.toStringAsFixed(1) + ' h',
          tone: summary.unbilledTimesheetHours > 0
              ? _Tone.warn
              : _Tone.success,
        ),
        if (summary.nextDeadlines.isNotEmpty) ...[
          const SizedBox(height: AppDimens.md),
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next deadlines',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final d in summary.nextDeadlines)
                  _deadlineRow(context, d),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _deadlineRow(BuildContext context, ProjectsDeadline d) {
    final label = d.daysLeft < 0
        ? '${-d.daysLeft}d overdue'
        : d.daysLeft == 0
            ? 'Today'
            : d.daysLeft == 1
                ? 'Tomorrow'
                : 'in ${d.daysLeft}d';
    final labelColor = d.daysLeft < 0
        ? AppColors.error
        : d.daysLeft <= 2
            ? const Color(0xFFE65100)
            : AppColors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              d.subject.isEmpty ? d.project : d.subject,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: labelColor,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ============================================================================
// Accounts section
// ============================================================================

class AccountsDashboardSection extends ConsumerWidget {
  const AccountsDashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(accountsPeriodProvider);
    final async = ref.watch(accountsSummaryProvider);
    return _SectionShell(
      title: 'Accounts',
      subtitle: 'Money in, money out',
      icon: Icons.account_balance_wallet_outlined,
      periodChips: _PeriodChips(
        active: period,
        onChange: (p) => ref.read(accountsPeriodProvider.notifier).set(p),
      ),
      child: async.when(
        loading: _loading,
        error: (e, _) =>
            _error(e, () => ref.invalidate(accountsSummaryProvider)),
        data: (s) => _AccountsBody(summary: s),
      ),
    );
  }
}

class _AccountsBody extends StatelessWidget {
  const _AccountsBody({required this.summary});
  final AccountsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.call_received,
                label: 'Receivable',
                value: moneyShort(summary.receivableOutstanding),
                tone: summary.receivableOutstanding > 0
                    ? _Tone.warn
                    : _Tone.primary,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.call_made,
                label: 'Payable',
                value: moneyShort(summary.payableOutstanding),
                tone: summary.payableOutstanding > 0
                    ? _Tone.danger
                    : _Tone.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.sm),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.error_outline,
                label: 'Overdue invoices',
                value: '${summary.overdueInvoices}',
                tone: summary.overdueInvoices > 0
                    ? _Tone.danger
                    : _Tone.primary,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.trending_up,
                label: 'Receipts (period)',
                value: moneyShort(summary.receiptsInPeriod),
                tone: _Tone.success,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.trending_down,
                label: 'Payments (period)',
                value: moneyShort(summary.paymentsInPeriod),
              ),
            ),
          ],
        ),
        if (summary.topOverdue.isNotEmpty) ...[
          const SizedBox(height: AppDimens.md),
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Most overdue',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final r in summary.topOverdue) _overdueRow(context, r),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _overdueRow(BuildContext context, AccountsOverdue r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            r.isSales ? Icons.call_received : Icons.call_made,
            size: 14,
            color: r.isSales ? AppColors.primary : AppColors.error,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              r.party.isEmpty ? r.name : r.party,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text('${r.daysOverdue}d',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(width: 6),
          Text(moneyShort(r.outstanding),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
