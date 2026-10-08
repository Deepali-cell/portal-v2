import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/invoices_controller.dart';
import '../domain/models.dart';
import 'record_payment_sheet.dart';

final _dateFmt = DateFormat('d MMM yyyy');

/// Route argument carried in `state.extra` for `/invoice-detail`.
class InvoiceDetailArgs {
  const InvoiceDetailArgs({required this.name, required this.kind});
  final String name;
  final InvoiceKind kind;
}

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({
    super.key,
    required this.name,
    required this.kind,
  });
  final String name;
  final InvoiceKind kind;

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _submitting = false;

  ({String name, InvoiceKind kind}) get _key =>
      (name: widget.name, kind: widget.kind);

  Future<void> _submit(InvoiceDetail d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit invoice?'),
        content: Text(
            'This will submit ${d.name}. Once submitted, the invoice cannot be edited, only cancelled.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(invoicesControllerProvider.notifier)
          .submitInvoice(widget.name, widget.kind);
      // Force re-fetch of detail
      ref.invalidate(invoiceDetailProvider(_key));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${d.name} submitted.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(invoiceDetailProvider(_key));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text(widget.kind == InvoiceKind.sales
            ? 'Sales Invoice'
            : 'Purchase Invoice'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(invoiceDetailProvider(_key)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(invoiceDetailProvider(_key));
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: Text(
                e is ApiException ? e.message : 'Could not open the invoice.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        data: (d) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
              AppDimens.lg, AppDimens.screenPadding, AppDimens.xl),
          children: [
            _Hero(d: d),
            const SizedBox(height: AppDimens.lg),
            _ItemsCard(d: d),
            if (d.taxes.isNotEmpty) ...[
              const SizedBox(height: AppDimens.md),
              _TaxesCard(d: d),
            ],
            const SizedBox(height: AppDimens.md),
            _TotalsCard(d: d),
            if (d.payments.isNotEmpty) ...[
              const SizedBox(height: AppDimens.md),
              _PaymentsTimeline(d: d),
            ],
            if (d.remarks != null && d.remarks!.isNotEmpty) ...[
              const SizedBox(height: AppDimens.md),
              _RemarksCard(remarks: d.remarks!),
            ],
            const SizedBox(height: AppDimens.xl),
          ],
        ),
        ),
      ),
      bottomNavigationBar: async.when(
        loading: () => null,
        error: (_, _) => null,
        data: (d) {
          // Action bar appears when:
          //  • draft + canSubmit  → Submit
          //  • submitted + outstanding > 0 + canRecordPayment → Record Payment
          final showSubmit = d.isDraft && d.canSubmit;
          final showRecord = !d.isDraft &&
              d.docstatus == 1 &&
              d.outstanding > 0 &&
              d.canRecordPayment;
          if (!showSubmit && !showRecord) return null;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
                  AppDimens.sm, AppDimens.screenPadding, AppDimens.md),
              child: SizedBox(
                width: double.infinity,
                child: showSubmit
                    ? FilledButton.icon(
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('Submit'),
                        onPressed:
                            _submitting ? null : () => _submit(d),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryContainer,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusLg),
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        icon: const Icon(Icons.account_balance_wallet),
                        label: Text(d.kind == InvoiceKind.sales
                            ? 'Record Receipt'
                            : 'Record Payment'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await showRecordPaymentSheet(context, d);
                          if (ok == true) {
                            ref.invalidate(invoiceDetailProvider(_key));
                            messenger.showSnackBar(const SnackBar(
                                content: Text('Payment recorded.')));
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryContainer,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusLg),
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.d});
  final InvoiceDetail d;

  @override
  Widget build(BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name,
                        style: TextStyle(
                            color: AppColors.primaryFixedDim, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(d.partyName.isEmpty ? d.party : d.partyName,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              _StatusChip(d: d),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          Text(money(d.grandTotal, d.currency),
              style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          if (d.outstanding > 0 && d.docstatus == 1)
            Text('Outstanding: ${money(d.outstanding, d.currency)}',
                style: TextStyle(
                    color: AppColors.primaryFixedDim, fontSize: 12)),
          const SizedBox(height: AppDimens.md),
          Row(children: [
            if (d.postingDate != null)
              Expanded(
                child: _kv(
                    context, 'Posted', _dateFmt.format(d.postingDate!)),
              ),
            if (d.dueDate != null)
              Expanded(
                child: _kv(context, 'Due', _dateFmt.format(d.dueDate!)),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.only(right: AppDimens.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k,
                style: TextStyle(
                    color: AppColors.primaryFixedDim, fontSize: 11)),
            const SizedBox(height: 2),
            Text(v,
                style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.d});
  final InvoiceDetail d;
  @override
  Widget build(BuildContext context) {
    String label = d.status.isEmpty ? 'Draft' : d.status;
    if (d.isDraft) label = 'Draft';
    Color bg;
    Color fg;
    final s = label.toLowerCase();
    if (d.isDraft) {
      bg = AppColors.surfaceContainerHigh;
      fg = AppColors.onSurfaceVariant;
    } else if (s.contains('paid') && !s.contains('unpaid')) {
      bg = AppColors.tertiaryFixed;
      fg = AppColors.onTertiaryFixedVariant;
    } else if (s.contains('overdue')) {
      bg = AppColors.errorContainer;
      fg = AppColors.onErrorContainer;
    } else if (s.contains('cancel')) {
      bg = AppColors.surfaceContainerHigh;
      fg = AppColors.onSurfaceVariant;
    } else {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.d});
  final InvoiceDetail d;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.md, AppDimens.md, AppDimens.md, AppDimens.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text('Items',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
                Text('${d.items.length}',
                    style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          for (var i = 0; i < d.items.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1, indent: 16, color: AppColors.outlineVariant),
            _ItemRow(line: d.items[i], currency: d.currency),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.line, required this.currency});
  final InvoiceLine line;
  final String currency;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.md),
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
                    Text(line.itemName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(line.itemCode,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Text(money(line.amount, currency),
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              '${_n(line.qty)} ${line.uom ?? ''} × ${money(line.rate, currency)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _n(double v) =>
      v == v.truncate() ? v.toInt().toString() : v.toString();
}

class _TaxesCard extends StatelessWidget {
  const _TaxesCard({required this.d});
  final InvoiceDetail d;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Taxes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppDimens.sm),
            for (final t in d.taxes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(t.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Text(money(t.taxAmount, d.currency),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                            fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.d});
  final InvoiceDetail d;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          children: [
            _row(context, 'Net total', money(d.netTotal, d.currency)),
            if (d.totalTaxes != 0)
              _row(context, 'Taxes', money(d.totalTaxes, d.currency)),
            const Divider(),
            _row(
              context,
              'Grand total',
              money(d.grandTotal, d.currency),
              emphasised: true,
            ),
            if (d.docstatus == 1 && d.outstanding > 0)
              _row(context, 'Outstanding', money(d.outstanding, d.currency)),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool emphasised = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: emphasised
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.bodyMedium),
          Text(value,
              style: emphasised
                  ? TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)
                  : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RemarksCard extends StatelessWidget {
  const _RemarksCard({required this.remarks});
  final String remarks;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remarks',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppDimens.sm),
            Text(remarks, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _PaymentsTimeline extends StatelessWidget {
  const _PaymentsTimeline({required this.d});
  final InvoiceDetail d;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.md, AppDimens.md, AppDimens.md, AppDimens.sm),
            child: Row(children: [
              Expanded(
                child: Text('Payments',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
              Text('${d.payments.length}',
                  style: Theme.of(context).textTheme.labelMedium),
            ]),
          ),
          for (var i = 0; i < d.payments.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1, indent: 16, color: AppColors.outlineVariant),
            _PaymentRow(p: d.payments[i], currency: d.currency),
          ],
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.p, required this.currency});
  final LinkedPayment p;
  final String currency;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.tertiaryFixed,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.payments_outlined,
                color: AppColors.onTertiaryFixedVariant, size: 18),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    [
                      if (p.postingDate != null)
                        DateFormat('d MMM yyyy').format(p.postingDate!),
                      if (p.modeOfPayment != null) p.modeOfPayment,
                      if (p.referenceNo != null && p.referenceNo!.isNotEmpty)
                        'ref ${p.referenceNo}',
                    ].whereType<String>().join(' · '),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(money(p.allocatedAmount, currency),
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
