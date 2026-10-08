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
import '../../../shared/widgets/date_range_bar.dart';
import '../../../shared/widgets/employee_only_notice.dart';
import '../../auth/application/auth_controller.dart';
import '../application/payslip_controller.dart';
import '../domain/models.dart';

final _monthFmt = DateFormat('MMMM yyyy');
final _shortFmt = DateFormat('MMM yyyy');
final _payDateFmt = DateFormat('d MMM yyyy');

/// Payroll amounts are sensitive — they stay masked until the user explicitly
/// reveals them. The toggle resets each time the screen is reopened.
class _RevealNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final _payrollRevealedProvider =
    NotifierProvider.autoDispose<_RevealNotifier, bool>(_RevealNotifier.new);

String _maskedMoney(double amount, String currency, {required bool revealed}) =>
    revealed ? money(amount, currency) : '••••••';

class PayslipsScreen extends ConsumerWidget {
  const PayslipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final noEmployee = profile != null && !profile.hasEmployee;
    final async = ref.watch(payslipListProvider);
    final revealed = ref.watch(_payrollRevealedProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Payroll'),
        actions: [
          if (!noEmployee) ...[
            IconButton(
              tooltip: revealed ? 'Hide amounts' : 'Show amounts',
              icon: Icon(
                  revealed
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.primary),
              onPressed: () =>
                  ref.read(_payrollRevealedProvider.notifier).toggle(),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: Icon(Icons.refresh, color: AppColors.primary),
              onPressed: () => ref.read(payslipListProvider.notifier).reload(),
            ),
          ],
        ],
      ),
      body: noEmployee
          ? const EmployeeOnlyNotice(feature: 'Payroll')
          : async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Error(
          msg: e is ApiException ? e.message : 'Could not load payslips.',
          onRetry: () => ref.read(payslipListProvider.notifier).reload(),
        ),
        data: (ctx) {
          final slips = ctx.slips;
          return RefreshIndicator(
            onRefresh: () => ref.read(payslipListProvider.notifier).reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.md,
                  AppDimens.screenPadding,
                  AppDimens.xl),
              children: [
                _SectionHeader(
                  title: 'Payroll & Payslips',
                  subtitle: 'Track your earnings, deductions and history.',
                ),
                const SizedBox(height: AppDimens.md),
                DateRangeBar(
                  from: ctx.fromDate,
                  to: ctx.toDate,
                  onChanged: (f, t) => ref
                      .read(payslipListProvider.notifier)
                      .setRange(f, t),
                ),
                const SizedBox(height: AppDimens.md),
                if (slips.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.lg),
                      child: Row(
                        children: [
                          Icon(Icons.payments_outlined,
                              color: AppColors.outline),
                          const SizedBox(width: AppDimens.md),
                          Expanded(
                              child: Text(
                                  'No payslips in the selected period.',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                  )
                else ...[
                  _NetSalaryHero(slip: slips.first),
                  const SizedBox(height: AppDimens.md),
                  _PeriodTotalCard(ctx: ctx),
                  const SizedBox(height: AppDimens.md),
                  _BreakdownSection(slipName: slips.first.name),
                  const SizedBox(height: AppDimens.lg),
                  _PastPayslipsCard(slips: slips),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _NetSalaryHero extends ConsumerWidget {
  const _NetSalaryHero({required this.slip});
  final Payslip slip;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = _monthFmt.format(slip.startDate);
    final revealed = ref.watch(_payrollRevealedProvider);
    return Card(
      child: Stack(
        children: [
          // Soft decorative blur in the top-right corner — matches the mockup.
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondaryFixedDim.withValues(alpha: 0.35),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Net Salary',
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 2),
                          Text(period,
                              style: Theme.of(context).textTheme.headlineMedium),
                        ],
                      ),
                    ),
                    _PaidChip(status: slip.status),
                  ],
                ),
                const SizedBox(height: AppDimens.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                          _maskedMoney(slip.net, slip.currency,
                              revealed: revealed),
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                    ),
                    IconButton(
                      tooltip: revealed ? 'Hide' : 'Show',
                      icon: Icon(
                          revealed
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.onSurfaceVariant),
                      onPressed: () => ref
                          .read(_payrollRevealedProvider.notifier)
                          .toggle(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    'Gross ${_maskedMoney(slip.gross, slip.currency, revealed: revealed)} · '
                    'Deductions ${_maskedMoney(slip.deduction, slip.currency, revealed: revealed)}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaidChip extends StatelessWidget {
  const _PaidChip({required this.status});
  final String? status;
  @override
  Widget build(BuildContext context) {
    final paid = (status ?? '').toLowerCase().contains('submitted') ||
        (status ?? '').toLowerCase().contains('paid');
    final color =
        paid ? AppColors.onTertiaryContainer : AppColors.warning;
    final bg = (paid ? AppColors.tertiaryFixedDim : AppColors.warning)
        .withValues(alpha: 0.18);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(paid ? Icons.check_circle : Icons.schedule, size: 14, color: color),
          const SizedBox(width: 4),
          Text(paid ? 'Paid' : (status ?? 'Pending'),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ),
    );
  }
}

class _PeriodTotalCard extends ConsumerWidget {
  const _PeriodTotalCard({required this.ctx});
  final PayslipContext ctx;
  static final _rangeFmt = DateFormat('d MMM yyyy');
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revealed = ref.watch(_payrollRevealedProvider);
    final slips = ctx.slips;
    final gross = slips.fold<double>(0, (s, p) => s + p.gross);
    final ded = slips.fold<double>(0, (s, p) => s + p.deduction);
    final net = slips.fold<double>(0, (s, p) => s + p.net);
    final currency = slips.first.currency;
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
                child: Text('Period total',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.account_balance,
                  color: AppColors.primaryFixedDim, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              '${_rangeFmt.format(ctx.fromDate)} – ${_rangeFmt.format(ctx.toDate)} · ${slips.length} ${slips.length == 1 ? 'payslip' : 'payslips'}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primaryFixedDim,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: AppDimens.md),
          Text('Total net pay',
              style: TextStyle(
                  color: AppColors.primaryFixedDim, fontSize: 12)),
          Text(_maskedMoney(net, currency, revealed: revealed),
              style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: AppDimens.md),
          Container(
              height: 1,
              color: AppColors.primaryFixedDim.withValues(alpha: 0.25)),
          const SizedBox(height: AppDimens.md),
          _periodRow(context, 'Gross',
              _maskedMoney(gross, currency, revealed: revealed)),
          const SizedBox(height: 6),
          _periodRow(context, 'Deductions',
              _maskedMoney(ded, currency, revealed: revealed)),
        ],
      ),
    );
  }

  Widget _periodRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: AppColors.primaryFixedDim, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    );
  }
}

class _BreakdownSection extends ConsumerWidget {
  const _BreakdownSection({required this.slipName});
  final String slipName;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(payslipDetailProvider(slipName));
    return async.when(
      loading: () => const _BreakdownSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (d) {
        return Row(
          children: [
            Expanded(
              child: _BreakdownCard(
                title: 'Earnings',
                total: d.gross,
                currency: d.currency,
                lines: d.earnings,
                accent: AppColors.secondaryContainer,
                icon: Icons.add,
                tone: AppColors.secondaryFixed,
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: _BreakdownCard(
                title: 'Deductions',
                total: d.deduction,
                currency: d.currency,
                lines: d.deductions,
                accent: AppColors.error,
                icon: Icons.remove,
                tone: AppColors.errorContainer,
                negate: true,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BreakdownSkeleton extends StatelessWidget {
  const _BreakdownSkeleton();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _shell()),
        const SizedBox(width: AppDimens.md),
        Expanded(child: _shell()),
      ],
    );
  }

  Widget _shell() => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: SizedBox(
            height: 120,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
}

class _BreakdownCard extends ConsumerWidget {
  const _BreakdownCard({
    required this.title,
    required this.total,
    required this.currency,
    required this.lines,
    required this.accent,
    required this.icon,
    required this.tone,
    this.negate = false,
  });
  final String title;
  final double total;
  final String currency;
  final List<PayslipLine> lines;
  final Color accent;
  final IconData icon;
  final Color tone;
  final bool negate;

  String _fmt(double v, bool revealed) {
    final s = _maskedMoney(v, currency, revealed: revealed);
    return revealed && negate ? '-$s' : s;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revealed = ref.watch(_payrollRevealedProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.onSurface)),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            Text(_fmt(total, revealed),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppDimens.sm),
            if (lines.isEmpty)
              Text('-', style: Theme.of(context).textTheme.bodySmall)
            else
              for (final l in lines.take(4))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(l.component,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      Text(_fmt(l.amount, revealed),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface)),
                    ],
                  ),
                ),
            if (lines.length > 4)
              Text('+ ${lines.length - 4} more',
                  style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _PastPayslipsCard extends StatelessWidget {
  const _PastPayslipsCard({required this.slips});
  final List<Payslip> slips;
  @override
  Widget build(BuildContext context) {
    if (slips.length <= 1) {
      return const SizedBox.shrink();
    }
    final past = slips.skip(1).toList();
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.md, AppDimens.md, AppDimens.md, AppDimens.sm),
            child: Text('Past Payslips',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          for (var i = 0; i < past.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 64, color: AppColors.outlineVariant),
            _PastRow(slip: past[i]),
          ],
        ],
      ),
    );
  }
}

class _PastRow extends ConsumerWidget {
  const _PastRow({required this.slip});
  final Payslip slip;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revealed = ref.watch(_payrollRevealedProvider);
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
              child: Icon(Icons.description_outlined,
                  color: AppColors.onSurfaceVariant, size: 20),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_shortFmt.format(slip.startDate),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                      'Paid ${_payDateFmt.format(slip.endDate)} · ${_maskedMoney(slip.net, slip.currency, revealed: revealed)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
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
