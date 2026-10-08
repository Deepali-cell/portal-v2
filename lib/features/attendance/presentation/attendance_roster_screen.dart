import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../data/attendance_report_repository.dart';
import '../domain/attendance_report_models.dart';
import 'employee_attendance_screen.dart';
import 'widgets/month_calendar_view.dart';

final _monthLabelFmt = DateFormat('MMMM yyyy');

/// All Attendance (canManage=false) and HR Attendance Management
/// (canManage=true) share this roster: month picker + employee search +
/// per-employee month status counts, drilling into a full calendar.
class AttendanceRosterScreen extends ConsumerStatefulWidget {
  const AttendanceRosterScreen({
    super.key,
    required this.title,
    this.canManage = false,
  });

  final String title;
  final bool canManage;

  @override
  ConsumerState<AttendanceRosterScreen> createState() =>
      _AttendanceRosterScreenState();
}

class _AttendanceRosterScreenState
    extends ConsumerState<AttendanceRosterScreen> {
  late int _year;
  late int _month;
  String _search = '';
  Timer? _debounce;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _search = v.trim());
    });
  }

  void _shiftMonth(int delta) {
    final base = DateTime(_year, _month + delta, 1);
    setState(() {
      _year = base.year;
      _month = base.month;
    });
  }

  RosterKey get _key =>
      (year: _year, month: _month, search: _search.isEmpty ? null : _search);

  void _openEmployee(AttendanceEmployeeRow row) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EmployeeAttendanceScreen(
        employee: row.employee,
        employeeName: row.employeeName,
        canManage: widget.canManage,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(attendanceRosterProvider(_key));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(attendanceRosterProvider(_key)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.md, AppDimens.sm, AppDimens.md, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _monthLabelFmt.format(DateTime(_year, _month)),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.md, AppDimens.sm, AppDimens.md, AppDimens.sm),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search employee',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e is ApiException ? e.message : '$e',
                          textAlign: TextAlign.center),
                      const SizedBox(height: AppDimens.md),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(attendanceRosterProvider(_key)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (roster) {
                if (roster.employees.isEmpty) {
                  return Center(
                    child: Text('No employees found',
                        style: TextStyle(color: AppColors.onSurfaceVariant)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(attendanceRosterProvider(_key)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.md),
                    itemCount: roster.employees.length,
                    itemBuilder: (_, i) => _EmployeeRow(
                      row: roster.employees[i],
                      onTap: () => _openEmployee(roster.employees[i]),
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

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({required this.row, required this.onTap});
  final AttendanceEmployeeRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
        title: Text(row.employeeName.isNotEmpty ? row.employeeName : row.employee),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (row.present > 0) _CountChip('P', row.present, 'Present'),
              if (row.absent > 0) _CountChip('A', row.absent, 'Absent'),
              if (row.halfDay > 0) _CountChip('H', row.halfDay, 'Half Day'),
              if (row.onLeave > 0) _CountChip('L', row.onLeave, 'On Leave'),
              if (row.workFromHome > 0)
                _CountChip('W', row.workFromHome, 'Work From Home'),
              if (row.present == 0 &&
                  row.absent == 0 &&
                  row.halfDay == 0 &&
                  row.onLeave == 0 &&
                  row.workFromHome == 0)
                Text('No records this month',
                    style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.letter, this.count, this.status);
  final String letter;
  final int count;
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = attendanceStatusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$letter $count',
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
