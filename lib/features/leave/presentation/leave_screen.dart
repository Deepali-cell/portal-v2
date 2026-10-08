import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../../../shared/widgets/employee_only_notice.dart';
import '../../auth/application/auth_controller.dart';
import '../application/leave_controller.dart';
import '../domain/models.dart';
import 'leave_management_screen.dart'
    show showLeaveDetailSheet, showMyCompOffDetailSheet, showMyWfhDetailSheet;

final _dateFmt = DateFormat('d MMM yyyy');
final _dateShort = DateFormat('d MMM');

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final noEmployee = profile != null && !profile.hasEmployee;
    final async = ref.watch(leaveControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Leave'),
        actions: [
          if (!noEmployee)
            IconButton(
              tooltip: 'Refresh',
              icon: Icon(Icons.refresh, color: AppColors.primary),
              onPressed: () {
                ref.invalidate(myWfhProvider);
                ref.read(leaveControllerProvider.notifier).reload();
              },
            ),
        ],
      ),
      body: noEmployee
          ? const EmployeeOnlyNotice(feature: 'Leave')
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Error(
                msg: e is ApiException ? e.message : 'Could not load leave.',
                onRetry: () =>
                    ref.read(leaveControllerProvider.notifier).reload(),
              ),
              data: (ctx) => RefreshIndicator(
                onRefresh: () {
                  ref.invalidate(myWfhProvider);
                  return ref.read(leaveControllerProvider.notifier).reload();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.md,
                    AppDimens.screenPadding,
                    AppDimens.xl,
                  ),
                  children: [
                    _HeaderSection(ctx: ctx),
                    const SizedBox(height: AppDimens.lg),
                    if (ctx.balances.isEmpty)
                      _EmptyBalances()
                    else
                      _BalancesGrid(balances: ctx.balances),
                    const SizedBox(height: AppDimens.lg),
                    _MyRequestsSection(applications: ctx.applications),
                    if (ctx.compOffRequests.isNotEmpty) ...[
                      const SizedBox(height: AppDimens.lg),
                      _MyCompOffSection(requests: ctx.compOffRequests),
                    ],
                    const _MyWfhList(),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The signed-in user's own Work From Home requests. Watches its own provider
/// so it refreshes after applying, and hides itself when there are none.
class _MyWfhList extends ConsumerWidget {
  const _MyWfhList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myWfhProvider);
    return async.maybeWhen(
      data: (requests) {
        if (requests.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppDimens.lg),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.md,
                    AppDimens.md,
                    AppDimens.md,
                    AppDimens.sm,
                  ),
                  child: Text(
                    'My WFH Requests',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (var i = 0; i < requests.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 64,
                      color: AppColors.outlineVariant,
                    ),
                  _WfhRow(req: requests[i]),
                ],
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _WfhRow extends StatelessWidget {
  const _WfhRow({required this.req});
  final WfhSummary req;

  @override
  Widget build(BuildContext context) {
    final range = req.fromDate == req.toDate
        ? _dateFmt.format(req.fromDate)
        : '${_dateShort.format(req.fromDate)} – ${_dateFmt.format(req.toDate)}';
    return InkWell(
      onTap: () => showMyWfhDetailSheet(context, req),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.home_work_outlined,
                color: AppColors.onSurface,
                size: 20,
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WFH · $range${req.halfDay ? " · half day" : ""}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (req.stageLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      req.stageLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            _StatusChip(status: req.status),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

class _HeaderSection extends ConsumerWidget {
  const _HeaderSection({required this.ctx});
  final LeaveContext ctx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Leave Balances', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 4),
        Text(
          'Manage your time off efficiently.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppDimens.md),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: ctx.leaveTypes.isEmpty
                    ? null
                    : () => _openApplySheet(context, ref, ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondaryContainer,
                  foregroundColor: AppColors.onSecondaryContainer,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Apply for Leave'),
              ),
            ),
            if (ctx.supportsCompOff) ...[
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openCompOffSheet(context, ref, ctx),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.event_repeat, size: 18),
                  label: const Text('Compensatory Off'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppDimens.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openWfhSheet(context, ref),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.home_work_outlined, size: 18),
            label: const Text('Apply for Work From Home'),
          ),
        ),
      ],
    );
  }

  Future<void> _openWfhSheet(BuildContext context, WidgetRef ref) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radius3xl),
        ),
      ),
      builder: (_) => const _ApplyWfhSheet(),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('WFH request submitted for approval.')),
        );
    }
  }

  Future<void> _openApplySheet(
    BuildContext context,
    WidgetRef ref,
    LeaveContext ctx,
  ) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radius3xl),
        ),
      ),
      builder: (_) => _ApplyLeaveSheet(ctx: ctx),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Leave request submitted for approval.'),
          ),
        );
    }
  }

  Future<void> _openCompOffSheet(
    BuildContext context,
    WidgetRef ref,
    LeaveContext ctx,
  ) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radius3xl),
        ),
      ),
      builder: (_) => _ApplyCompOffSheet(
        compensatoryLeaveTypes: ctx.compensatoryLeaveTypes,
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Compensatory Off request submitted. HR will review on the desk.',
            ),
          ),
        );
    }
  }
}

class _BalancesGrid extends StatelessWidget {
  const _BalancesGrid({required this.balances});
  final List<LeaveBalance> balances;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final cards = balances.map((b) => _BalanceCard(balance: b)).toList();
    if (wide) {
      return GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: AppDimens.md,
        mainAxisSpacing: AppDimens.md,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.5,
        children: cards,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDimens.md),
          cards[i],
        ],
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(balance.leaveType);
    final pct = balance.total > 0
        ? (balance.remaining / balance.total).clamp(0, 1).toDouble()
        : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: spec.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    balance.leaveType,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  spec.icon,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.55),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _n(balance.remaining),
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'days',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Available out of ${_n(balance.total)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          value: pct,
                          strokeWidth: 4,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          valueColor: AlwaysStoppedAnimation(spec.color),
                        ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: Text(
                            '${(pct * 100).round()}%',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.onSurface),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  ({IconData icon, Color color}) _specFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('sick')) {
      return (icon: Icons.medical_services_outlined, color: AppColors.error);
    }
    if (t.contains('casual')) {
      return (icon: Icons.coffee_outlined, color: AppColors.tertiaryFixedDim);
    }
    if (t.contains('compensatory') || t.contains('comp')) {
      return (icon: Icons.savings_outlined, color: AppColors.tertiaryFixedDim);
    }
    if (t.contains('without') || t.contains('lwp')) {
      return (icon: Icons.event_busy_outlined, color: AppColors.outline);
    }
    return (
      icon: Icons.flight_takeoff_outlined,
      color: AppColors.secondaryContainer,
    );
  }
}

class _EmptyBalances extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.onSurfaceVariant),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Text(
                'No leave balances allocated yet. You can still apply for Leave Without Pay.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyRequestsSection extends StatelessWidget {
  const _MyRequestsSection({required this.applications});
  final List<LeaveApplication> applications;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.md,
              AppDimens.md,
              AppDimens.md,
              AppDimens.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'My Requests',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (applications.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.md,
                0,
                AppDimens.md,
                AppDimens.md,
              ),
              child: Text(
                'You haven\'t applied for leave yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (var i = 0; i < applications.length; i++) ...[
              if (i > 0)
                Divider(height: 1, indent: 64, color: AppColors.outlineVariant),
              _RequestRow(app: applications[i]),
            ],
        ],
      ),
    );
  }
}

/// The signed-in user's own comp-off requests, with the stage each has reached.
class _MyCompOffSection extends StatelessWidget {
  const _MyCompOffSection({required this.requests});
  final List<CompOffSummary> requests;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.md,
              AppDimens.md,
              AppDimens.md,
              AppDimens.sm,
            ),
            child: Text(
              'My Compensatory Off Requests',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (var i = 0; i < requests.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 64, color: AppColors.outlineVariant),
            _CompOffRow(req: requests[i]),
          ],
        ],
      ),
    );
  }
}

class _CompOffRow extends StatelessWidget {
  const _CompOffRow({required this.req});
  final CompOffSummary req;

  @override
  Widget build(BuildContext context) {
    final range = req.workFromDate == req.workEndDate
        ? _dateFmt.format(req.workFromDate)
        : '${_dateShort.format(req.workFromDate)} – ${_dateFmt.format(req.workEndDate)}';
    return InkWell(
      onTap: () => showMyCompOffDetailSheet(context, req),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.savings_outlined,
                color: AppColors.onSurface,
                size: 20,
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Worked $range'
                    '${req.halfDay ? " · half day" : ""}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (req.stageLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      req.stageLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            _StatusChip(status: req.status),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.app});
  final LeaveApplication app;

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(app.leaveType);
    final range = app.fromDate == app.toDate
        ? _dateFmt.format(app.fromDate)
        : '${_dateShort.format(app.fromDate)} – ${_dateFmt.format(app.toDate)}';
    final days = app.totalLeaveDays;
    final dStr = days == days.roundToDouble()
        ? days.toInt().toString()
        : days.toString();
    return InkWell(
      onTap: () => showLeaveDetailSheet(context, app.name),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.onSurface, size: 20),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.leaveType,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$range · $dStr day${dStr == "1" ? "" : "s"}'
                    '${app.halfDay ? " · half day" : ""}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // The status chip reads Pending across both waiting hops, so
                  // the stage is what tells the applicant whether their manager
                  // has cleared it and it is now sitting with HR.
                  if (app.status == LeaveStatus.open &&
                      app.stageLabel != null &&
                      app.stageLabel!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      app.stageLabel!,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            _StatusChip(status: app.status),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('sick')) return Icons.medical_services_outlined;
    if (t.contains('casual')) return Icons.coffee_outlined;
    if (t.contains('without') || t.contains('lwp'))
      return Icons.event_busy_outlined;
    if (t.contains('compensatory')) return Icons.savings_outlined;
    return Icons.flight_takeoff_outlined;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final spec = _spec(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: spec.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: spec.fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            spec.label,
            style: TextStyle(
              color: spec.fg,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  ({Color bg, Color fg, String label}) _spec(LeaveStatus s) {
    switch (s) {
      case LeaveStatus.approved:
        return (
          bg: AppColors.tertiaryFixed,
          fg: AppColors.onTertiaryFixedVariant,
          label: 'Approved',
        );
      case LeaveStatus.rejected:
        return (
          bg: AppColors.errorContainer,
          fg: AppColors.onErrorContainer,
          label: 'Rejected',
        );
      case LeaveStatus.cancelled:
        return (
          bg: AppColors.surfaceContainerHigh,
          fg: AppColors.onSurfaceVariant,
          label: 'Cancelled',
        );
      case LeaveStatus.open:
        return (
          bg: const Color(0xFFFFF3E0),
          fg: const Color(0xFFE65100),
          label: 'Pending',
        );
    }
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.msg, required this.onRetry});
  final String msg;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.error),
          const SizedBox(height: AppDimens.md),
          Text(msg, textAlign: TextAlign.center),
          const SizedBox(height: AppDimens.lg),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

// ---- Apply sheet (kept compatible with the previous implementation) ----

class _ApplyLeaveSheet extends ConsumerStatefulWidget {
  const _ApplyLeaveSheet({required this.ctx});
  final LeaveContext ctx;
  @override
  ConsumerState<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends ConsumerState<_ApplyLeaveSheet> {
  String? _type;
  DateTime? _from;
  DateTime? _to;
  bool _halfDay = false;
  final _reason = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _singleDay => _from != null && _to != null && _from == _to;

  /// "Casual Leave  (8 left)". Leave without pay carries no allocation, so it
  /// shows no count rather than a misleading zero.
  String _typeLabel(String type) {
    final b = widget.ctx.balanceFor(type);
    if (b == null || b.isLwp) return type;
    return '$type  (${_n(b.remaining)} left)';
  }

  DateTime _nextWorkingDay(DateTime from) {
    var d = from;
    for (var i = 0; i < 60 && widget.ctx.isHoliday(d); i++) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = (isFrom ? _from : _to) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.ctx.isHoliday(initial)
          ? _nextWorkingDay(initial)
          : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
      // Holidays and weekly offs are not selectable. Spending a leave day on a
      // day the office was closed helps nobody, and HRMS would reject it later
      // anyway with an error the employee cannot act on.
      selectableDayPredicate: (d) => !widget.ctx.isHoliday(d),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to == null || _to!.isBefore(picked)) _to = picked;
      } else {
        _to = picked;
      }
      if (!_singleDay) _halfDay = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_type == null) {
      setState(() => _error = 'Select a leave type.');
      return;
    }
    if (_from == null || _to == null) {
      setState(() => _error = 'Select the leave dates.');
      return;
    }
    if (_to!.isBefore(_from!)) {
      setState(() => _error = 'End date cannot be before start date.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(leaveControllerProvider.notifier)
          .apply(
            LeaveRequest(
              leaveType: _type!,
              fromDate: _from!,
              toDate: _to!,
              halfDay: _halfDay && _singleDay,
              halfDayDate: _halfDay && _singleDay ? _from : null,
              description: _reason.text.trim(),
            ),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not submit. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.xl,
        AppDimens.xl,
        AppDimens.xl,
        AppDimens.xl + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'Apply for leave',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppDimens.xl),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Leave type'),
              items: widget.ctx.leaveTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(
                        _typeLabel(t),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v),
            ),
            if (_type != null)
              _BalanceLine(balance: widget.ctx.balanceFor(_type!)),
            const SizedBox(height: AppDimens.lg),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'From',
                    value: _from,
                    onTap: () => _pickDate(isFrom: true),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: _DateField(
                    label: 'To',
                    value: _to,
                    onTap: () => _pickDate(isFrom: false),
                  ),
                ),
              ],
            ),
            if (_singleDay) ...[
              const SizedBox(height: AppDimens.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Half day'),
                value: _halfDay,
                activeThumbColor: AppColors.secondary,
                onChanged: (v) => setState(() => _halfDay = v),
              ),
            ],
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _reason,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppDimens.xl),
            BrandButton(
              label: 'Submit request',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value == null ? 'Select' : _dateFmt.format(value!),
          style: TextStyle(
            color: value == null ? AppColors.outline : AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Apply for Comp-Off — claim a comp-off day for a holiday/weekend the
/// employee worked. Submitted as a Compensatory Leave Request; HR approves
/// on the desk → ERPNext auto-adds days to the employee's leave allocation.
class _ApplyCompOffSheet extends ConsumerStatefulWidget {
  const _ApplyCompOffSheet({required this.compensatoryLeaveTypes});
  final List<String> compensatoryLeaveTypes;
  @override
  ConsumerState<_ApplyCompOffSheet> createState() => _ApplyCompOffSheetState();
}

class _ApplyCompOffSheetState extends ConsumerState<_ApplyCompOffSheet> {
  late String? _leaveType = widget.compensatoryLeaveTypes.isNotEmpty
      ? widget.compensatoryLeaveTypes.first
      : null;
  DateTime? _workFrom;
  DateTime? _workTo;
  final _reason = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickWorkFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _workFrom ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _workFrom = picked);
  }

  Future<void> _pickWorkTo() async {
    final base = _workFrom ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _workTo ?? base,
      firstDate: base,
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _workTo = picked);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_workFrom == null) {
      setState(() => _error = 'Pick the date you worked.');
      return;
    }
    final r = _reason.text.trim();
    if (r.length < 4) {
      setState(
        () =>
            _error = 'Tell HR why you worked that day (at least 4 characters).',
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(leaveControllerProvider.notifier)
          .applyCompOff(
            CompOffRequest(
              workFromDate: _workFrom!,
              workEndDate: _workTo,
              reason: r,
              leaveType: _leaveType,
            ),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not submit. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.xl,
        AppDimens.xl,
        AppDimens.xl,
        AppDimens.xl + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'Apply for Compensatory Off',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              'Claim a comp-off day for a holiday/weekend you worked. HR will '
              'review and add the day(s) to your leave balance once approved.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppDimens.xl),

            if (widget.compensatoryLeaveTypes.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _leaveType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Leave type'),
                items: widget.compensatoryLeaveTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _leaveType = v),
              )
            else if (widget.compensatoryLeaveTypes.isNotEmpty)
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Leave type'),
                child: Text(
                  widget.compensatoryLeaveTypes.first,
                  style: TextStyle(color: AppColors.onSurface),
                ),
              ),
            const SizedBox(height: AppDimens.lg),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickWorkFrom,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Work date',
                        suffixIcon: Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                      ),
                      child: Text(
                        _workFrom == null
                            ? 'Pick the date you worked'
                            : _dateFmt.format(_workFrom!),
                        style: TextStyle(
                          color: _workFrom == null
                              ? AppColors.outline
                              : AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: InkWell(
                    onTap: _workFrom == null ? null : _pickWorkTo,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Last day (optional)',
                        suffixIcon: Icon(Icons.event_outlined, size: 18),
                      ),
                      child: Text(
                        _workTo == null
                            ? 'Same as work date'
                            : _dateFmt.format(_workTo!),
                        style: TextStyle(
                          color: _workTo == null
                              ? AppColors.outline
                              : AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.lg),

            TextField(
              controller: _reason,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Why did you work that day?',
                alignLabelWithHint: true,
                hintText: 'Required, at least 4 characters',
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppDimens.xl),
            BrandButton(
              label: 'Submit Compensatory Off',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Apply for Work From Home — creates an Attendance Request (reason
/// "Work From Home"). The reporting manager approves, then HR; on final approval
/// the WFH attendance is marked for the chosen dates.
class _ApplyWfhSheet extends ConsumerStatefulWidget {
  const _ApplyWfhSheet();
  @override
  ConsumerState<_ApplyWfhSheet> createState() => _ApplyWfhSheetState();
}

class _ApplyWfhSheetState extends ConsumerState<_ApplyWfhSheet> {
  DateTime? _from;
  DateTime? _to;
  bool _halfDay = false;
  final _reason = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _singleDay => _from != null && _to != null && _from == _to;

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _from = picked;
      if (_to == null || _to!.isBefore(picked)) _to = picked;
      if (!_singleDay) _halfDay = false;
    });
  }

  Future<void> _pickTo() async {
    final base = _from ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? base,
      firstDate: base,
      lastDate: DateTime(base.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _to = picked;
      if (!_singleDay) _halfDay = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_from == null || _to == null) {
      setState(() => _error = 'Select the dates.');
      return;
    }
    if (_to!.isBefore(_from!)) {
      setState(() => _error = 'End date cannot be before start date.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(leaveControllerProvider.notifier)
          .applyWfh(
            WfhRequest(
              fromDate: _from!,
              toDate: _to!,
              halfDay: _halfDay && _singleDay,
              halfDayDate: _halfDay && _singleDay ? _from : null,
              explanation: _reason.text.trim(),
            ),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not submit. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.xl,
        AppDimens.xl,
        AppDimens.xl,
        AppDimens.xl + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'Apply for Work From Home',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              'Request to work from home for a day or a range. Your manager and '
              'HR will approve; the days are then marked as WFH.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppDimens.xl),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'From',
                    value: _from,
                    onTap: _pickFrom,
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: _DateField(label: 'To', value: _to, onTap: _pickTo),
                ),
              ],
            ),
            if (_singleDay) ...[
              const SizedBox(height: AppDimens.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Half day'),
                value: _halfDay,
                activeThumbColor: AppColors.secondary,
                onChanged: (v) => setState(() => _halfDay = v),
              ),
            ],
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _reason,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppDimens.xl),
            BrandButton(
              label: 'Submit request',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// The selected leave type's balance, shown under the picker so the employee
/// can see what they are spending before choosing dates.
class _BalanceLine extends StatelessWidget {
  const _BalanceLine({required this.balance});
  final LeaveBalance? balance;

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final b = balance;
    if (b == null) return const SizedBox.shrink();
    final text = b.isLwp
        ? 'Leave without pay does not use your leave balance.'
        : '${_n(b.remaining)} of ${_n(b.total)} days left'
              '${b.pending > 0 ? " · ${_n(b.pending)} awaiting approval" : ""}'
              '${b.taken > 0 ? " · ${_n(b.taken)} taken" : ""}';
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.sm),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
