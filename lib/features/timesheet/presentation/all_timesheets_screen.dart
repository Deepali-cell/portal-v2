import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/date_range_bar.dart';
import '../application/timesheet_controller.dart';
import '../domain/models.dart';
import 'timesheet_detail_screen.dart';

final _dFmt = DateFormat('d MMM');
final _rangeFmt = DateFormat('d MMM yyyy');

/// All Timesheets: the org-wide roster for users who hold Timesheet read.
/// Lists every permitted employee's timesheets in a date window with an
/// employee search and a status filter. Tapping a row opens the shared
/// timesheet detail (its time entries), same as My Timesheet.
class AllTimesheetsScreen extends ConsumerStatefulWidget {
  const AllTimesheetsScreen({super.key});

  @override
  ConsumerState<AllTimesheetsScreen> createState() =>
      _AllTimesheetsScreenState();
}

class _AllTimesheetsScreenState extends ConsumerState<AllTimesheetsScreen> {
  late DateTime _from;
  late DateTime _to;
  String _search = '';
  String _status = 'All';
  Timer? _debounce;
  final _searchCtrl = TextEditingController();

  static const _statuses = ['All', 'Draft', 'Submitted', 'Billed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = now;
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

  AllTimesheetsKey get _key =>
      (from: _from, to: _to, search: _search.isEmpty ? null : _search);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allTimesheetsProvider(_key));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('All Timesheets'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(allTimesheetsProvider(_key)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding, AppDimens.md, AppDimens.screenPadding, 0),
            child: DateRangeBar(
              from: _from,
              to: _to,
              onChanged: (f, t) => setState(() {
                _from = f;
                _to = t;
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
                AppDimens.sm, AppDimens.screenPadding, AppDimens.sm),
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: AppDimens.sm),
                DropdownButton<String>(
                  value: _status,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final s in _statuses)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) =>
                      setState(() => _status = v ?? 'All'),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 40, color: AppColors.error),
                      const SizedBox(height: AppDimens.md),
                      Text(e is ApiException ? e.message : '$e',
                          textAlign: TextAlign.center),
                      const SizedBox(height: AppDimens.md),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(allTimesheetsProvider(_key)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) {
                final rows = _status == 'All'
                    ? data.timesheets
                    : data.timesheets
                        .where((t) =>
                            t.status.toLowerCase() == _status.toLowerCase())
                        .toList();
                if (rows.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.xl),
                      child: Text(
                        'No timesheets between ${_rangeFmt.format(data.fromDate)} and ${_rangeFmt.format(data.toDate)}.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(allTimesheetsProvider(_key)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.md),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => _TsRow(ts: rows[i]),
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

class _TsRow extends StatelessWidget {
  const _TsRow({required this.ts});
  final TimesheetSummary ts;

  @override
  Widget build(BuildContext context) {
    final name = (ts.employeeName?.isNotEmpty ?? false)
        ? ts.employeeName!
        : (ts.employee ?? '?');
    final period = (ts.startDate != null)
        ? '${_dFmt.format(ts.startDate!)}'
            '${ts.endDate != null && ts.endDate != ts.startDate ? ' – ${_dFmt.format(ts.endDate!)}' : ''}'
        : '';
    final hours = ts.totalHoursDisplay ??
        (ts.totalHours == ts.totalHours.truncate()
            ? ts.totalHours.toInt().toString()
            : ts.totalHours.toStringAsFixed(1));
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TimesheetDetailScreen(name: ts.name),
        )),
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceContainerLow,
          child: Text(
            name.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            [
              ts.name,
              if (period.isNotEmpty) period,
              ts.status,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$hours h',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}
