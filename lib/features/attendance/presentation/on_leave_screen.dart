import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../data/attendance_report_repository.dart';

final _dayFmt = DateFormat('EEE, d MMM yyyy');

/// Who is on approved leave on a chosen day. Opens on TODAY (the HR dashboard
/// "On Leave" card), with a date filter to look at any other day. Read-only.
class OnLeaveScreen extends ConsumerStatefulWidget {
  const OnLeaveScreen({super.key});

  @override
  ConsumerState<OnLeaveScreen> createState() => _OnLeaveScreenState();
}

class _OnLeaveScreenState extends ConsumerState<OnLeaveScreen> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  void _shiftDay(int delta) =>
      setState(() => _date = _date.add(Duration(days: delta)));

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day));
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(onLeaveListProvider(_date));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('On Leave'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(onLeaveListProvider(_date)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Day filter: prev / label (tap to pick) / next.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.md, AppDimens.sm, AppDimens.md, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shiftDay(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickDay,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppDimens.sm),
                      child: Column(
                        children: [
                          Text(
                            _isToday ? 'Today' : _dayFmt.format(_date),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (_isToday)
                            Text(_dayFmt.format(_date),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftDay(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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
                            ref.invalidate(onLeaveListProvider(_date)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (leaves) {
                if (leaves.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.beach_access_outlined,
                              size: 40, color: AppColors.onSurfaceVariant),
                          const SizedBox(height: AppDimens.md),
                          Text(
                            _isToday
                                ? 'No one is on leave today'
                                : 'No one on leave on this day',
                            style: TextStyle(
                                color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async =>
                      ref.invalidate(onLeaveListProvider(_date)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.md),
                    itemCount: leaves.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDimens.sm),
                    itemBuilder: (_, i) => _OnLeaveRow(row: leaves[i]),
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

class _OnLeaveRow extends StatelessWidget {
  const _OnLeaveRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final name = (row['employee_name'] ?? row['employee'] ?? '').toString();
    final leaveType = (row['leave_type'] ?? '').toString();
    final from = (row['from_date'] ?? '').toString();
    final to = (row['to_date'] ?? '').toString();
    final halfDay = row['half_day'] == 1 || row['half_day'] == true;
    final range = from == to ? from : '$from  →  $to';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFB42318).withValues(alpha: 0.12),
              child: Text(
                name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Color(0xFFB42318)),
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isNotEmpty ? name : '(unnamed)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(range,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (leaveType.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(leaveType,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                if (halfDay) ...[
                  const SizedBox(height: 4),
                  Text('Half day',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
