import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/payslip_controller.dart';
import '../domain/models.dart';

final _monthName = DateFormat('MMMM');
final _shortFmt = DateFormat('MMM yyyy');

/// Finance > All Payslips: every employee's salary slips, filterable by
/// month/year and by status (draft/submitted). Shown only to people whose
/// `payslip_view_all` capability is true (Accounts Manager / HR / admin).
class AllPayslipsScreen extends ConsumerWidget {
  const AllPayslipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allPayslipsProvider);
    final ctrl = ref.read(allPayslipsProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('All Payslips'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: ctrl.reload,
          ),
        ],
      ),
      body: Column(
        children: [
          _Filters(ctrl: ctrl),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Error(
                msg: e is ApiException ? e.message : 'Could not load payslips.',
                onRetry: ctrl.reload,
              ),
              data: (ctx) => _Body(ctx: ctx, onRefresh: ctrl.reload),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.ctrl});
  final AllPayslipsController ctrl;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = [for (var y = now.year; y >= now.year - 5; y--) y];
    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding, AppDimens.sm, AppDimens.screenPadding, AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Dropdown<int>(
                  label: 'Year',
                  value: ctrl.year,
                  items: [
                    for (final y in years)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (v) {
                    if (v != null) ctrl.setYear(v);
                  },
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: _Dropdown<int?>(
                  label: 'Month',
                  value: ctrl.month,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All months')),
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(
                        value: m,
                        child: Text(_monthName.format(DateTime(2000, m))),
                      ),
                  ],
                  onChanged: ctrl.setMonth,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          Row(
            children: [
              for (final s in const [
                ('all', 'All'),
                ('draft', 'Draft'),
                ('submitted', 'Submitted'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppDimens.sm),
                  child: ChoiceChip(
                    label: Text(s.$2),
                    selected: ctrl.status == s.$1,
                    onSelected: (_) => ctrl.setStatus(s.$1),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md, vertical: AppDimens.sm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.ctx, required this.onRefresh});
  final AllPayslipsContext ctx;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (ctx.slips.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.payments_outlined,
                size: 48, color: AppColors.outline),
            const SizedBox(height: AppDimens.md),
            Center(
              child: Text('No payslips match these filters.',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      );
    }

    // Group by month (start_date) so a whole-year view reads month by month.
    final groups = <String, List<AllPayslip>>{};
    for (final s in ctx.slips) {
      final key = _shortFmt.format(s.startDate);
      groups.putIfAbsent(key, () => []).add(s);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
            AppDimens.md, AppDimens.screenPadding, AppDimens.xl),
        children: [
          _SummaryCard(ctx: ctx),
          const SizedBox(height: AppDimens.lg),
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.sm, left: 4),
              child: Text(entry.key,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
            ),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < entry.value.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          indent: 16,
                          color: AppColors.outlineVariant),
                    _SlipRow(slip: entry.value[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppDimens.md),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.ctx});
  final AllPayslipsContext ctx;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ctx.count} ${ctx.count == 1 ? 'payslip' : 'payslips'}',
                    style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Total net pay',
                    style: TextStyle(
                        color: AppColors.primaryFixedDim, fontSize: 12)),
              ],
            ),
          ),
          Text(money(ctx.totalNet, ctx.currency),
              style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SlipRow extends StatelessWidget {
  const _SlipRow({required this.slip});
  final AllPayslip slip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(Routes.payslipDetail, extra: slip.name),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.person_outline,
                  color: AppColors.onSurfaceVariant, size: 20),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slip.employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(money(slip.net, slip.currency),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            _StatusChip(isDraft: slip.isDraft),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isDraft});
  final bool isDraft;

  @override
  Widget build(BuildContext context) {
    final label = isDraft ? 'Draft' : 'Submitted';
    final color = isDraft ? AppColors.warning : AppColors.onTertiaryContainer;
    final bg = (isDraft ? AppColors.warning : AppColors.tertiaryFixedDim)
        .withValues(alpha: 0.18);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: AppDimens.md),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}
