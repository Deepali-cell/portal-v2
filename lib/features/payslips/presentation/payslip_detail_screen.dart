import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/payslip_controller.dart';
import '../domain/models.dart';

final _rangeFmt = DateFormat('d MMM');
final _rangeFmtFull = DateFormat('d MMM yyyy');

/// Payslip detail amounts are sensitive — masked until the user reveals them.
class _RevealNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final _revealedProvider =
    NotifierProvider.autoDispose<_RevealNotifier, bool>(_RevealNotifier.new);

String _mask(double v, String currency, bool revealed) =>
    revealed ? money(v, currency) : '••••••';

class PayslipDetailScreen extends ConsumerStatefulWidget {
  const PayslipDetailScreen({super.key, required this.name});
  final String name;

  @override
  ConsumerState<PayslipDetailScreen> createState() =>
      _PayslipDetailScreenState();
}

class _PayslipDetailScreenState extends ConsumerState<PayslipDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(payslipDetailProvider(widget.name));
    final revealed = ref.watch(_revealedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payslip'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(payslipDetailProvider(widget.name)),
          ),
          IconButton(
            tooltip: revealed ? 'Hide amounts' : 'Show amounts',
            icon: Icon(revealed
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
            onPressed: () => ref.read(_revealedProvider.notifier).toggle(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(payslipDetailProvider(widget.name));
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: Text(e is ApiException ? e.message : 'Could not load payslip.',
                  textAlign: TextAlign.center),
            ),
          ],
        ),
        data: (d) => _Detail(d: d),
        ),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.d});
  final PayslipDetail d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      children: [
        _NetCard(d: d),
        const SizedBox(height: AppDimens.xl),
        if (d.earnings.isNotEmpty) ...[
          const _SectionTitle('Earnings'),
          const SizedBox(height: AppDimens.sm),
          _LinesCard(
              lines: d.earnings,
              currency: d.currency,
              total: d.gross,
              totalLabel: 'Gross pay'),
          const SizedBox(height: AppDimens.lg),
        ],
        if (d.deductions.isNotEmpty) ...[
          const _SectionTitle('Deductions'),
          const SizedBox(height: AppDimens.sm),
          _LinesCard(
              lines: d.deductions,
              currency: d.currency,
              total: d.deduction,
              totalLabel: 'Total deductions'),
        ],
      ],
    );
  }
}

class _NetCard extends ConsumerWidget {
  const _NetCard({required this.d});
  final PayslipDetail d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revealed = ref.watch(_revealedProvider);
    final period = '${_rangeFmt.format(d.startDate)} – '
        '${_rangeFmtFull.format(d.endDate)}';
    return Container(
      padding: const EdgeInsets.all(AppDimens.xl),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net pay',
              style: TextStyle(color: AppColors.canvas.withValues(alpha: 0.8))),
          const SizedBox(height: AppDimens.xs),
          Text(_mask(d.net, d.currency, revealed),
              style: TextStyle(
                  color: AppColors.canvas,
                  fontSize: 30,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: AppDimens.sm),
          Text(period,
              style: TextStyle(color: AppColors.canvas.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);
}

class _LinesCard extends ConsumerWidget {
  const _LinesCard({
    required this.lines,
    required this.currency,
    required this.total,
    required this.totalLabel,
  });
  final List<PayslipLine> lines;
  final String currency;
  final double total;
  final String totalLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revealed = ref.watch(_revealedProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.lg, vertical: AppDimens.sm),
        child: Column(
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l.component),
                    Text(_mask(l.amount, currency, revealed),
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(totalLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(_mask(total, currency, revealed),
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.navy)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
