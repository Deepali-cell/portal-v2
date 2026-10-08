import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/leave_controller.dart';
import '../domain/models.dart';

final _dateFmt = DateFormat('d MMM yyyy');

class LeaveDetailScreen extends ConsumerWidget {
  const LeaveDetailScreen({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaveApplicationDetailProvider(name));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Leave Application'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.invalidate(leaveApplicationDetailProvider(name)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(leaveApplicationDetailProvider(name));
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimens.xl),
                child: Text(
                  e is ApiException
                      ? e.message
                      : 'Could not open the leave application.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          data: (d) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              AppDimens.lg,
              AppDimens.screenPadding,
              AppDimens.xl,
            ),
            children: [
              _Hero(d: d),
              const SizedBox(height: AppDimens.lg),
              _InfoCard(
                rows: [
                  _Row(label: 'Leave Type', value: d.leaveType),
                  _Row(label: 'From', value: _dateFmt.format(d.fromDate)),
                  _Row(label: 'To', value: _dateFmt.format(d.toDate)),
                  _Row(label: 'Days', value: _formatDays(d.totalLeaveDays)),
                  if (d.halfDay)
                    _Row(
                      label: 'Half Day',
                      value: d.halfDayDate != null
                          ? _dateFmt.format(d.halfDayDate!)
                          : 'Yes',
                    ),
                  if (d.postingDate != null)
                    _Row(
                      label: 'Posted',
                      value: _dateFmt.format(d.postingDate!),
                    ),
                  if (d.leaveApprover != null && d.leaveApprover!.isNotEmpty)
                    _Row(
                      label: 'Approver',
                      value: d.leaveApproverName ?? d.leaveApprover!,
                    ),
                ],
              ),
              if (d.description != null && d.description!.isNotEmpty) ...[
                const SizedBox(height: AppDimens.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reason',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: AppDimens.sm),
                        Text(
                          d.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDays(double v) =>
      v == v.truncate() ? '${v.toInt()}' : v.toStringAsFixed(1);
}

class _Hero extends StatelessWidget {
  const _Hero({required this.d});
  final LeaveApplicationDetail d;
  @override
  Widget build(BuildContext context) {
    final s = _statusSpec(d.status);
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.name,
                  style: TextStyle(
                    color: AppColors.primaryFixedDim,
                    fontSize: 12,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: s.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  s.label,
                  style: TextStyle(
                    color: s.fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            d.leaveType,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_dateFmt.format(d.fromDate)} → ${_dateFmt.format(d.toDate)}',
            style: TextStyle(color: AppColors.primaryFixedDim, fontSize: 13),
          ),
        ],
      ),
    );
  }

  ({String label, Color bg, Color fg}) _statusSpec(LeaveStatus s) {
    switch (s) {
      case LeaveStatus.approved:
        return (
          label: 'Approved',
          bg: AppColors.tertiaryFixed,
          fg: AppColors.onTertiaryFixedVariant,
        );
      case LeaveStatus.rejected:
        return (
          label: 'Rejected',
          bg: AppColors.errorContainer,
          fg: AppColors.onErrorContainer,
        );
      case LeaveStatus.cancelled:
        return (
          label: 'Cancelled',
          bg: AppColors.surfaceContainerHigh,
          fg: AppColors.onSurfaceVariant,
        );
      case LeaveStatus.open:
        return (
          label: 'Pending',
          bg: const Color(0xFFFFF3E0),
          fg: const Color(0xFFE65100),
        );
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<_Row> rows;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 16, color: AppColors.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.md,
                vertical: AppDimens.sm + 2,
              ),
              child: rows[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: AppDimens.sm),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
