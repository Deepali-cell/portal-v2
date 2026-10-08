import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../data/attendance_report_repository.dart';
import '../../domain/attendance_report_models.dart';

final _monthLabelFmt = DateFormat('MMMM yyyy');
final _timeFmt = DateFormat('h:mm a');
final _dayHeadingFmt = DateFormat('EEEE, MMM d');

/// (background, foreground) colour for an attendance status chip / cell.
(Color, Color) attendanceStatusColors(String? status) {
  switch (status) {
    case 'Present':
      return (const Color(0xFFE6F4EA), const Color(0xFF2E7D32));
    case 'Absent':
      return (const Color(0xFFFDECEA), const Color(0xFFC62828));
    case 'Half Day':
      return (const Color(0xFFFFF3E0), const Color(0xFFE65100));
    case 'On Leave':
      return (const Color(0xFFE3F2FD), const Color(0xFF1565C0));
    case 'Work From Home':
      return (const Color(0xFFF3E5F5), const Color(0xFF6A1B9A));
    case 'Holiday':
    case 'Week Off':
      return (const Color(0xFFEEEEEE), const Color(0xFF616161));
    default:
      return (AppColors.surfaceContainerLowest, AppColors.onSurfaceVariant);
  }
}

const List<String> _hrStatuses = [
  'Present',
  'Absent',
  'Half Day',
  'On Leave',
  'Work From Home',
];

/// Month calendar for one employee. Powers My Attendance (self), All Attendance
/// (read-only drill-down) and HR Management (with mark actions when [canManage]).
class MonthCalendarView extends ConsumerStatefulWidget {
  const MonthCalendarView({
    super.key,
    this.employee,
    this.canManage = false,
  });

  /// null = the logged-in user's own attendance.
  final String? employee;

  /// Show HR "mark Present/Absent/Half Day/..." actions in the day sheet.
  final bool canManage;

  @override
  ConsumerState<MonthCalendarView> createState() => _MonthCalendarViewState();
}

class _MonthCalendarViewState extends ConsumerState<MonthCalendarView> {
  late int _year;
  late int _month;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _selectedDay = now.day;
  }

  MonthKey get _key => (year: _year, month: _month, employee: widget.employee);

  void _shiftMonth(int delta) {
    final base = DateTime(_year, _month + delta, 1);
    setState(() {
      _year = base.year;
      _month = base.month;
      _selectedDay = null;
    });
  }

  Future<void> _mark(AttendanceMonth data, int day, String status) async {
    final date = DateTime(_year, _month, day);
    try {
      await ref.read(attendanceReportRepositoryProvider).markStatus(
            employee: data.employee,
            date: date,
            status: status,
          );
      if (!mounted) return;
      ref.invalidate(monthlyAttendanceProvider(_key));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Marked $status for $day ${_monthLabelFmt.format(DateTime(_year, _month))}')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(monthlyAttendanceProvider(_key));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(monthlyAttendanceProvider(_key)),
      child: ListView(
        padding: const EdgeInsets.all(AppDimens.md),
        children: [
          _MonthPickerBar(
            label: _monthLabelFmt.format(DateTime(_year, _month)),
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
          const SizedBox(height: AppDimens.md),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Text(e is ApiException ? e.message : '$e',
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppDimens.md),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(monthlyAttendanceProvider(_key)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (data) => Column(
              children: [
                if (widget.employee != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(data.employeeName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: AppDimens.sm),
                ],
                _CalendarGrid(
                  year: _year,
                  month: _month,
                  data: data,
                  selectedDay: _selectedDay,
                  onSelect: (d) => setState(() => _selectedDay = d),
                ),
                const SizedBox(height: AppDimens.md),
                const _Legend(),
                const SizedBox(height: AppDimens.md),
                if (_selectedDay != null)
                  _DayDetail(
                    key: ValueKey('$_year-$_month-$_selectedDay'),
                    date: DateTime(_year, _month, _selectedDay!),
                    day: data.dayOf(_selectedDay!),
                    employee: data.employee,
                    canManage: widget.canManage,
                    onMark: (status) => _mark(data, _selectedDay!, status),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPickerBar extends StatelessWidget {
  const _MonthPickerBar({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.year,
    required this.month,
    required this.data,
    required this.selectedDay,
    required this.onSelect,
  });
  final int year;
  final int month;
  final AttendanceMonth data;
  final int? selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Monday-first grid: weekday 1=Mon..7=Sun -> leading blanks.
    final leading = first.weekday - 1;
    final now = DateTime.now();

    final cells = <Widget>[];
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    for (final w in weekdayLabels) {
      cells.add(Center(
        child: Text(w,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600)),
      ));
    }
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = data.dayOf(d);
      final isToday =
          now.year == year && now.month == month && now.day == d;
      cells.add(_DayCell(
        day: d,
        status: day?.status,
        isToday: isToday,
        isSelected: selectedDay == d,
        onTap: () => onSelect(d),
      ));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.sm),
        child: GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: cells,
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.status,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });
  final int day;
  final String? status;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = attendanceStatusColors(status);
    final hasStatus = status != null;
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: hasStatus ? bg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isToday
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : Colors.transparent),
            width: isSelected ? 2 : 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: hasStatus ? fg : AppColors.onSurface,
              ),
            ),
            if (hasStatus)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    const items = [
      'Present',
      'Absent',
      'Half Day',
      'On Leave',
      'Work From Home',
      'Holiday',
    ];
    return Wrap(
      spacing: AppDimens.md,
      runSpacing: AppDimens.sm,
      children: [
        for (final s in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: attendanceStatusColors(s).$2,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(s, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}

/// Selected-day details: status + in/out/hours + raw checkin logs, plus HR
/// mark actions when [canManage].
class _DayDetail extends ConsumerWidget {
  const _DayDetail({
    super.key,
    required this.date,
    required this.day,
    required this.employee,
    required this.canManage,
    required this.onMark,
  });
  final DateTime date;
  final AttendanceDay? day;
  final String employee;
  final bool canManage;
  final ValueChanged<String> onMark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = day?.status;
    final (bg, fg) = attendanceStatusColors(status);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_dayHeadingFmt.format(date),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(status ?? 'Not marked',
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ],
            ),
            if (day?.leaveType != null && day!.leaveType!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(day!.leaveType!,
                  style: Theme.of(context).textTheme.labelSmall),
            ],
            const SizedBox(height: AppDimens.md),
            Row(
              children: [
                _MiniStat(
                    label: 'Check In',
                    value: day?.inTime != null
                        ? _timeFmt.format(day!.inTime!.toLocal())
                        : '-'),
                _MiniStat(
                    label: 'Check Out',
                    value: day?.outTime != null
                        ? _timeFmt.format(day!.outTime!.toLocal())
                        : '-'),
                _MiniStat(
                    label: 'Hours',
                    value: day?.workingHours != null
                        ? day!.workingHours!.toStringAsFixed(2)
                        : '-'),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            _RawLogs(date: date, employee: employee),
            if (canManage) ...[
              const Divider(height: AppDimens.lg),
              Text('Mark attendance',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppDimens.sm),
              Wrap(
                spacing: AppDimens.sm,
                runSpacing: AppDimens.sm,
                children: [
                  for (final s in _hrStatuses)
                    OutlinedButton(
                      onPressed: date.isAfter(DateTime.now())
                          ? null
                          : () => onMark(s),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: attendanceStatusColors(s).$2,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                      ),
                      child: Text(s),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Raw Employee Checkin rows for the selected day, fetched on demand.
class _RawLogs extends ConsumerWidget {
  const _RawLogs({required this.date, required this.employee});
  final DateTime date;
  final String employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<DayLogs>(
      future: ref
          .read(attendanceReportRepositoryProvider)
          .dayLogs(date, employee: employee),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
                child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final logs = snap.data?.logs ?? const [];
        if (logs.isEmpty) {
          return Text('No check-in logs',
              style: Theme.of(context).textTheme.labelSmall);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in logs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      l.logType == 'IN'
                          ? Icons.login_rounded
                          : Icons.logout_rounded,
                      size: 16,
                      color: l.logType == 'IN'
                          ? AppColors.secondary
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(l.logType == 'IN' ? 'In' : 'Out',
                        style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    if (l.isOffsite)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text('Off-site',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontStyle: FontStyle.italic)),
                      ),
                    Text(_timeFmt.format(l.time.toLocal()),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
