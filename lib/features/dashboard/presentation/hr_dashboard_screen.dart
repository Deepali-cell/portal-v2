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
import 'module_dashboard_scaffold.dart';
import '../../home/presentation/nav_destinations.dart';
import '../../auth/application/auth_controller.dart';

/// HR module dashboard — the manager's morning overview: approvals waiting,
/// who is absent today, upcoming exits to plan for, and the birthdays to
/// remember this week. Reuses the existing HR summary endpoint + period
/// controller, matching the Projects and Finance dashboards.
class HrDashboardScreen extends ConsumerWidget {
  const HrDashboardScreen({super.key});

  static const _amber = Color(0xFFB54708);
  static const _blue = Color(0xFF2563EB);
  static const _green = Color(0xFF15803D);
  static const _purple = Color(0xFF6941C6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hrSummaryProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('HR'),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(hrSummaryProvider);
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
                title: 'HR',
                subtitle: 'Approvals, attendance & people at a glance',
                icon: Icons.groups_outlined,
              ),
              const SizedBox(height: AppDimens.md),
              async.when(
                loading: () => const FlowSkeleton(rows: 4),
                error: (e, _) => FlowLoadError(
                  message: e is ApiException
                      ? e.message
                      : "Couldn't load HR. Try again.",
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

class _Body extends StatelessWidget {
  const _Body({required this.summary});
  final HrSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardSectionTitle(
          'Overview',
          subtitle: 'People & approvals at a glance',
        ),
        const SizedBox(height: AppDimens.sm),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Pending Expenses',
                count: summary.expenseClaims,
                icon: Icons.receipt_long_outlined,
                color: HrDashboardScreen._amber,
                route: '${Routes.expenseClaims}?filter=pending',
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _MetricCard(
                label: 'Pending Leaves',
                count: summary.pendingLeaveApps,
                icon: Icons.event_outlined,
                color: HrDashboardScreen._blue,
                route: '${Routes.leaveManagement}?tab=0&status=pending',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.sm),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Active Headcount',
                count: summary.activeHeadcount,
                icon: Icons.groups_outlined,
                color: HrDashboardScreen._green,
                route: Routes.directory,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _MetricCard(
                label: 'Pending Attendance',
                count: summary.pendingAttendance,
                icon: Icons.pending_actions_outlined,
                color: HrDashboardScreen._purple,
                route: Routes.pendingAttendance,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.lg),
        const _ApprovalFlows(),
        const SizedBox(height: AppDimens.lg),
        Consumer(
          builder: (_, ref, _) =>
              screenOn(
                ref.watch(authControllerProvider).profile,
                'hr.leave_rules',
              )
              ? const _LeavePolicyTile()
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: AppDimens.lg),
        DashboardSectionTitle(
          'Birthdays this week',
          subtitle: summary.birthdays.isEmpty
              ? 'No birthdays in the next 7 days'
              : 'A quick wish goes a long way',
        ),
        const SizedBox(height: AppDimens.sm),
        if (summary.birthdays.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.cake_outlined, color: AppColors.onSurfaceVariant),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Text(
                    'Nothing coming up this week.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          for (final b in summary.birthdays) _BirthdayRow(item: b),
      ],
    );
  }
}

/// The fixed approval routes each request type travels, shown on the HR home so
/// staff know who clears what and there is no confusion about the flow.
class _ApprovalFlows extends StatelessWidget {
  const _ApprovalFlows();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardSectionTitle(
          'Approval flows',
          subtitle: 'Who clears each request',
        ),
        const SizedBox(height: AppDimens.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md,
            vertical: AppDimens.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: const Column(
            children: [
              _FlowRow(
                title: 'Leave',
                icon: Icons.event_outlined,
                color: HrDashboardScreen._blue,
                steps: ['Employee', 'Leave Approver', 'HR'],
              ),
              Divider(height: AppDimens.md),
              _FlowRow(
                title: 'Expense',
                icon: Icons.receipt_long_outlined,
                color: HrDashboardScreen._amber,
                steps: ['Employee', 'Expense Approver', 'HR'],
              ),
              Divider(height: AppDimens.md),
              _FlowRow(
                title: 'Compensatory',
                icon: Icons.more_time_outlined,
                color: HrDashboardScreen._green,
                steps: ['Employee', 'HR'],
              ),
              Divider(height: AppDimens.md),
              _FlowRow(
                title: 'Work From Home',
                icon: Icons.home_work_outlined,
                color: HrDashboardScreen._purple,
                steps: ['Employee', 'HR'],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Entry point to the leave notice-period policy - the rules that force leave
/// to be applied a set number of days in advance. Shown on the HR home so the
/// validation the app enforces is visible and HR can change it in one tap.
class _LeavePolicyTile extends StatelessWidget {
  const _LeavePolicyTile();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardSectionTitle(
          'Leave request rules',
          subtitle: 'Advance-notice policy applied to every leave',
        ),
        const SizedBox(height: AppDimens.sm),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
            onTap: () => context.push(Routes.leaveNoticeRules),
            child: Ink(
              padding: const EdgeInsets.all(AppDimens.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: HrDashboardScreen._blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.rule_folder_outlined,
                      color: HrDashboardScreen._blue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notice-period policy',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Set how far ahead each leave must be applied',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.onSurfaceVariant),
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
          ),
        ),
      ],
    );
  }
}

/// One request type's route: a labelled icon, then its ordered stages as pills
/// joined by arrows. Wraps so the stages never overflow on a narrow screen.
class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.title,
    required this.icon,
    required this.color,
    required this.steps,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppDimens.sm),
          SizedBox(
            width: 104,
            // Wrap to a second line at word boundaries so full titles like
            // "Work From Home" and "Compensatory" show whole - never mid-word.
            child: Text(
              title,
              maxLines: 2,
              softWrap: true,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0)
                    Icon(
                      Icons.arrow_right_alt,
                      size: 16,
                      color: AppColors.onSurfaceVariant,
                    ),
                  _FlowPill(label: steps[i], last: i == steps.length - 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowPill extends StatelessWidget {
  const _FlowPill({required this.label, required this.last});
  final String label;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tint = last ? AppColors.primary : AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tint,
        ),
      ),
    );
  }
}

/// A tappable KPI tile for the HR overview grid: an icon chip, a large count
/// and a label. Deep-links to the matching list screen via [AppNav.go] so the
/// portal-wide back history stays correct.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.route,
  });
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        onTap: () => AppNav.go(context, route),
        child: Ink(
          padding: const EdgeInsets.all(AppDimens.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sm),
              Text(
                count > 999 ? '999+' : '$count',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
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

class _BirthdayRow extends StatelessWidget {
  const _BirthdayRow({required this.item});
  final HrBirthday item;

  String _when(int days) => switch (days) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => 'in $days days',
  };

  @override
  Widget build(BuildContext context) {
    final today = item.daysAway == 0;
    final tint = today ? HrDashboardScreen._green : HrDashboardScreen._blue;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: tint.withValues(alpha: 0.12),
              child: Icon(Icons.cake_outlined, size: 18, color: tint),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.employeeName.isEmpty ? '(unnamed)' : item.employeeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (item.designation.isNotEmpty)
                    Text(
                      item.designation,
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
                _when(item.daysAway),
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
