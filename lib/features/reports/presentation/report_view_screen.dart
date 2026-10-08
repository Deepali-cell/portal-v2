import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/reports_controller.dart';
import '../domain/models.dart';

/// Arguments to open one report.
@immutable
class ReportViewArgs {
  const ReportViewArgs({
    required this.reportKey,
    required this.label,
    this.hasDateRange = false,
  });
  final String reportKey;
  final String label;
  final bool hasDateRange;
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Runs a single report and renders its columns + rows as a styled table.
/// Every report gets a Year + Month control that re-runs it for that window.
class ReportViewScreen extends ConsumerStatefulWidget {
  const ReportViewScreen({super.key, required this.args});
  final ReportViewArgs args;

  @override
  ConsumerState<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends ConsumerState<ReportViewScreen> {
  late int _year;
  int? _month; // null = whole year ("All")

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  /// The from/to window for the current Year + Month selection.
  Map<String, dynamic> get _window {
    final from = DateTime(_year, _month ?? 1, 1);
    final to = _month == null
        ? DateTime(_year, 12, 31)
        : DateTime(_year, _month! + 1, 0); // day 0 of next month = last day
    return {'from_date': _iso(from), 'to_date': _iso(to)};
  }

  @override
  Widget build(BuildContext context) {
    final args = RunReportArgs(widget.args.reportKey, filters: _window);
    final async = ref.watch(runReportProvider(args));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.args.label),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(runReportProvider(args)),
          ),
        ],
      ),
      body: Column(
        children: [
          _PeriodBar(
            year: _year,
            month: _month,
            onPick: () => _pickPeriod(context),
          ),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorRetry(
                message: '$e',
                onRetry: () => ref.invalidate(runReportProvider(args)),
              ),
              data: (result) => _ReportTable(result: result),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPeriod(BuildContext context) async {
    final picked = await showModalBottomSheet<_Period>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => _PeriodPicker(year: _year, month: _month),
    );
    if (picked == null) return;
    setState(() {
      _year = picked.year;
      _month = picked.month;
    });
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// A compact bar showing the active period, tappable to change it.
class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.year,
    required this.month,
    required this.onPick,
  });
  final int year;
  final int? month;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final label =
        month == null ? 'Full year $year' : '${_monthNames[month! - 1]} $year';
    return Material(
      color: AppColors.surfaceContainerLow,
      child: InkWell(
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md, vertical: AppDimens.sm + 2),
          child: Row(
            children: [
              Icon(Icons.calendar_month, size: 18, color: AppColors.primary),
              const SizedBox(width: AppDimens.sm),
              Text(
                'Period',
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              Icon(Icons.expand_more, size: 20, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Period {
  const _Period(this.year, this.month);
  final int year;
  final int? month;
}

/// Bottom-sheet Year + Month picker. Month "All" means the whole year.
class _PeriodPicker extends StatefulWidget {
  const _PeriodPicker({required this.year, required this.month});
  final int year;
  final int? month;

  @override
  State<_PeriodPicker> createState() => _PeriodPickerState();
}

class _PeriodPickerState extends State<_PeriodPicker> {
  late int _year;
  int? _month;

  @override
  void initState() {
    super.initState();
    _year = widget.year;
    _month = widget.month;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    final years = [for (var y = now + 1; y >= now - 7; y--) y];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDimens.md),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text('Select period',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface)),
            const SizedBox(height: AppDimens.md),
            Text('Year',
                style: TextStyle(
                    fontSize: 13, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppDimens.sm),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: years.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppDimens.sm),
                itemBuilder: (_, i) {
                  final y = years[i];
                  return ChoiceChip(
                    label: Text('$y'),
                    selected: _year == y,
                    onSelected: (_) => setState(() => _year = y),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimens.md),
            Text('Month',
                style: TextStyle(
                    fontSize: 13, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppDimens.sm),
            Wrap(
              spacing: AppDimens.sm,
              runSpacing: AppDimens.sm,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _month == null,
                  onSelected: (_) => setState(() => _month = null),
                ),
                for (var m = 1; m <= 12; m++)
                  ChoiceChip(
                    label: Text(_monthNames[m - 1]),
                    selected: _month == m,
                    onSelected: (_) => setState(() => _month = m),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_Period(_year, _month)),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.result});
  final ReportResult result;

  @override
  Widget build(BuildContext context) {
    if (result.columns.isEmpty || result.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 44, color: AppColors.outline),
              const SizedBox(height: AppDimens.sm),
              Text('No data for the selected period.',
                  style: TextStyle(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.all(AppDimens.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              AppColors.primary.withValues(alpha: 0.08),
            ),
            headingRowHeight: 44,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 54,
            columnSpacing: 26,
            horizontalMargin: 14,
            dividerThickness: 0.6,
            columns: [
              for (final c in result.columns)
                DataColumn(
                  numeric: c.isNumeric,
                  label: Text(
                    c.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
            rows: [
              for (var r = 0; r < result.rows.length; r++)
                DataRow(
                  color: WidgetStatePropertyAll(
                    r.isEven
                        ? AppColors.surface
                        : AppColors.surfaceContainerLow,
                  ),
                  cells: [
                    for (var i = 0; i < result.columns.length; i++)
                      DataCell(
                        Text(
                          _fmtCell(
                            i < result.rows[r].length
                                ? result.rows[r][i]
                                : null,
                            result.columns[i],
                          ),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.onSurface,
                            fontWeight: result.columns[i].isNumeric
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtCell(dynamic v, ReportColumn c) {
    if (v == null || v == '') return '';
    if (v is num && c.isNumeric) {
      final decimals = c.fieldtype == 'Int' ? 0 : 2;
      return _fmtNum(v, decimals);
    }
    return v.toString();
  }

  /// Thousands-separated number with fixed decimals, no external deps.
  static String _fmtNum(num v, int decimals) {
    final neg = v < 0;
    final abs = v.abs();
    final fixed = abs.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    final out = decimals > 0 ? '$buf.${parts[1]}' : buf.toString();
    return neg ? '-$out' : out;
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: AppDimens.md),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
