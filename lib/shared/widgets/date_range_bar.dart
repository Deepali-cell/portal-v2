import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';

final _rangeFmt = DateFormat('d MMM yyyy');

/// Reusable horizontally-scrolling chips for filtering a screen by a date
/// range — "This month" (default), "Last month", "Last 7 days", "Custom range".
/// Used on Timesheet, Expenses, Payroll.
class DateRangeBar extends StatelessWidget {
  const DateRangeBar({
    super.key,
    required this.from,
    required this.to,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.showAll = false,
  });

  final DateTime from;
  final DateTime to;
  final void Function(DateTime from, DateTime to) onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// When true, an "All" preset is shown first — a window wide enough to cover
  /// every record (matches the custom picker's floor). Used by the HR
  /// management screens so a KPI card's all-time count matches the list.
  final bool showAll;

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// A window that covers every record — the full span the custom picker
  /// allows, floor to ceiling. The ceiling reaches into next year so a
  /// future-dated application (e.g. a leave booked for next month) is included,
  /// matching the dashboard's all-time counts. Kept in sync with [_custom]'s
  /// `firstDate` / `lastDate`.
  static ({DateTime from, DateTime to}) allTime() {
    final n = DateTime.now();
    return (from: DateTime(n.year - 5), to: DateTime(n.year + 1, 12, 31));
  }

  static ({DateTime from, DateTime to}) thisMonth() {
    final n = DateTime.now();
    return (from: DateTime(n.year, n.month, 1), to: n);
  }

  static ({DateTime from, DateTime to}) lastMonth() {
    final n = DateTime.now();
    final firstOfThis = DateTime(n.year, n.month, 1);
    final lastMonthEnd = firstOfThis.subtract(const Duration(days: 1));
    return (
      from: DateTime(lastMonthEnd.year, lastMonthEnd.month, 1),
      to: lastMonthEnd,
    );
  }

  static ({DateTime from, DateTime to}) last7() {
    final n = DateTime.now();
    return (from: n.subtract(const Duration(days: 6)), to: n);
  }

  String _activePreset() {
    final m = thisMonth();
    final lm = lastMonth();
    final l7 = last7();
    if (showAll) {
      final a = allTime();
      if (_isSameDay(from, a.from) && _isSameDay(to, a.to)) return 'all';
    }
    if (_isSameDay(from, m.from) && _isSameDay(to, m.to)) return 'this_month';
    if (_isSameDay(from, lm.from) && _isSameDay(to, lm.to)) return 'last_month';
    if (_isSameDay(from, l7.from) && _isSameDay(to, l7.to)) return 'last_7';
    return 'custom';
  }

  Future<void> _custom(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate ?? DateTime(DateTime.now().year - 5),
      lastDate: lastDate ?? DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: from, end: to),
    );
    if (picked == null) return;
    onChanged(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final active = _activePreset();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (showAll) ...[
            _Chip(
              label: 'All',
              selected: active == 'all',
              onTap: () {
                final r = allTime();
                onChanged(r.from, r.to);
              },
            ),
            const SizedBox(width: 8),
          ],
          _Chip(
            label: 'This month',
            selected: active == 'this_month',
            onTap: () {
              final r = thisMonth();
              onChanged(r.from, r.to);
            },
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Last month',
            selected: active == 'last_month',
            onTap: () {
              final r = lastMonth();
              onChanged(r.from, r.to);
            },
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Last 7 days',
            selected: active == 'last_7',
            onTap: () {
              final r = last7();
              onChanged(r.from, r.to);
            },
          ),
          const SizedBox(width: 8),
          _Chip(
            label: active == 'custom'
                ? '${_rangeFmt.format(from)} – ${_rangeFmt.format(to)}'
                : 'Custom…',
            selected: active == 'custom',
            icon: Icons.calendar_today_outlined,
            onTap: () => _custom(context),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondaryContainer
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected
                  ? AppColors.secondaryContainer
                  : AppColors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: selected
                      ? AppColors.onSecondaryContainer
                      : AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    color: selected
                        ? AppColors.onSecondaryContainer
                        : AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
