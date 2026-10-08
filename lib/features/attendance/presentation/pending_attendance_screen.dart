import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../data/attendance_report_repository.dart';
import '../domain/attendance_report_models.dart';
import 'widgets/month_calendar_view.dart' show attendanceStatusColors;

final _dayFmt = DateFormat('EEE, d MMM yyyy');
final _timeFmt = DateFormat('h:mm a');

/// Statuses HR can mark from the pending sheet (mirrors the calendar's list).
const List<String> _markStatuses = [
  'Present',
  'Half Day',
  'On Leave',
  'Work From Home',
  'Absent',
];

/// HR screen: employees whose attendance for a day still needs a human decision.
///
/// Auto-attendance leaves two cases unmarked - checked in but never checked out,
/// and never checked in while not on leave. Both surface here so HR can review
/// the check-in logs and mark the day by hand.
class PendingAttendanceScreen extends ConsumerStatefulWidget {
  const PendingAttendanceScreen({super.key});

  @override
  ConsumerState<PendingAttendanceScreen> createState() =>
      _PendingAttendanceScreenState();
}

class _PendingAttendanceScreenState
    extends ConsumerState<PendingAttendanceScreen> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  void _shiftDay(int delta) {
    final next = _date.add(Duration(days: delta));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (next.isAfter(today)) return; // never review a future day
    setState(() => _date = next);
  }

  Future<void> _openRow(PendingAttendanceRow row) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PendingDetailSheet(date: _date, row: row),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pendingAttendanceProvider(_date));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Pending Attendance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(pendingAttendanceProvider(_date)),
          ),
        ],
      ),
      body: Column(
        children: [
          _DateBar(
            label: _dayFmt.format(_date),
            onPrev: () => _shiftDay(-1),
            onNext: _isToday ? null : () => _shiftDay(1),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e is ApiException ? e.message : '$e',
                onRetry: () =>
                    ref.invalidate(pendingAttendanceProvider(_date)),
              ),
              data: (data) {
                if (data.rows.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(pendingAttendanceProvider(_date)),
                    child: ListView(
                      children: const [
                        SizedBox(height: 120),
                        _EmptyState(),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(pendingAttendanceProvider(_date)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.md),
                    itemCount: data.rows.length,
                    itemBuilder: (_, i) => _PendingRow(
                      row: data.rows[i],
                      onTap: () => _openRow(data.rows[i]),
                    ),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDimens.sm),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  const _DateBar({required this.label, required this.onPrev, this.onNext});
  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.md, AppDimens.sm, AppDimens.md, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.row, required this.onTap});
  final PendingAttendanceRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final noCheckin = row.reason == 'No check-in';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceContainerLow,
          child: Text(
            row.employeeName.isNotEmpty
                ? row.employeeName.substring(0, 1).toUpperCase()
                : '?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
            row.employeeName.isNotEmpty ? row.employeeName : row.employee),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReasonChip(reason: row.reason),
              if (!noCheckin) ...[
                const SizedBox(height: 4),
                Text(
                  _logSummary(row),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  static String _logSummary(PendingAttendanceRow row) {
    final parts = <String>[];
    if (row.firstIn != null) parts.add('In ${_timeFmt.format(row.firstIn!)}');
    if (row.lastOut != null) parts.add('Out ${_timeFmt.format(row.lastOut!)}');
    if (row.hours > 0) parts.add('${row.hours.toStringAsFixed(1)}h');
    return parts.isEmpty ? '—' : parts.join('  •  ');
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    // No check-out -> amber (they worked); No check-in -> red (possible absent).
    final (bg, fg) = reason == 'No check-in'
        ? (const Color(0xFFFDECEA), const Color(0xFFC62828))
        : (const Color(0xFFFFF3E0), const Color(0xFFE65100));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(reason,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

/// Detail + mark sheet for one pending employee: shows the raw check-in logs and
/// lets HR mark any status. Marking calls the same mark_attendance endpoint the
/// calendar uses, then refreshes the pending list.
class _PendingDetailSheet extends ConsumerStatefulWidget {
  const _PendingDetailSheet({required this.date, required this.row});
  final DateTime date;
  final PendingAttendanceRow row;

  @override
  ConsumerState<_PendingDetailSheet> createState() =>
      _PendingDetailSheetState();
}

class _PendingDetailSheetState extends ConsumerState<_PendingDetailSheet> {
  bool _busy = false;

  Future<void> _mark(String status) async {
    setState(() => _busy = true);
    try {
      await ref.read(attendanceReportRepositoryProvider).markStatus(
            employee: widget.row.employee,
            date: widget.date,
            status: status,
          );
      if (!mounted) return;
      ref.invalidate(pendingAttendanceProvider(
          DateTime(widget.date.year, widget.date.month, widget.date.day)));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(
                'Marked $status for ${widget.row.employeeName.isNotEmpty ? widget.row.employeeName : widget.row.employee}')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final logsAsync = ref.watch(_sheetLogsProvider((
      date: widget.date,
      employee: row.employee,
    )));
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: AppDimens.md,
          right: AppDimens.md,
          top: AppDimens.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppDimens.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.employeeName.isNotEmpty
                        ? row.employeeName
                        : row.employee,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              '${_dayFmt.format(widget.date)}  •  ${row.reason}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            if ((row.designation ?? '').isNotEmpty ||
                (row.department ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                [row.designation, row.department]
                    .where((e) => (e ?? '').isNotEmpty)
                    .join('  •  '),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppDimens.md),
            Text('Check-in logs',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppDimens.xs),
            logsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                e is ApiException ? e.message : '$e',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
              data: (logs) {
                if (logs.logs.isEmpty) {
                  return Text('No check-in logs for this day.',
                      style: TextStyle(color: AppColors.onSurfaceVariant));
                }
                return Column(
                  children: [for (final l in logs.logs) _LogRow(log: l)],
                );
              },
            ),
            const SizedBox(height: AppDimens.md),
            Text('Mark attendance',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppDimens.xs),
            Wrap(
              spacing: AppDimens.sm,
              runSpacing: AppDimens.sm,
              children: [
                for (final s in _markStatuses)
                  _MarkButton(
                    status: s,
                    enabled: !_busy,
                    onTap: () => _mark(s),
                  ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: AppDimens.sm),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

typedef _SheetLogsKey = ({DateTime date, String employee});

/// Day-detail check-in logs for the pending sheet (kept local so it never
/// clashes with the calendar's own use of dayLogs).
final _sheetLogsProvider =
    FutureProvider.autoDispose.family<DayLogs, _SheetLogsKey>((ref, key) {
  return ref
      .read(attendanceReportRepositoryProvider)
      .dayLogs(key.date, employee: key.employee);
});

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log});
  final DayLog log;

  @override
  Widget build(BuildContext context) {
    final isIn = log.logType == 'IN';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isIn ? Icons.login : Icons.logout,
            size: 18,
            color: isIn ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          ),
          const SizedBox(width: AppDimens.sm),
          Text(isIn ? 'Check in' : 'Check out',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (log.isOffsite)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.location_off,
                  size: 15, color: AppColors.onSurfaceVariant),
            ),
          Text(_timeFmt.format(log.time),
              style: TextStyle(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.status,
    required this.enabled,
    required this.onTap,
  });
  final String status;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = attendanceStatusColors(status);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(status,
              style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.md),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 48, color: AppColors.onSurfaceVariant),
          const SizedBox(height: AppDimens.sm),
          Text('Nothing pending',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Everyone for this day is marked, on leave or on a holiday.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
