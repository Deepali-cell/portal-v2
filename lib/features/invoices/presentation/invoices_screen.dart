import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/date_range_bar.dart';
import '../application/invoices_controller.dart';
import '../domain/models.dart';
import 'invoice_detail_screen.dart';
import 'new_invoice_sheet.dart';

final _dateFmt = DateFormat('d MMM yyyy');

/// Which slice of billing this screen shows.
/// - [finance]  : all three tabs (Sales / Purchase / Payments) — the Finance
///                module's full billing hub.
/// - [sales]    : the Sales side — sales invoices OR customer receipts.
/// - [purchase] : the Purchase side — purchase invoices OR supplier payments.
enum InvoiceScope { finance, sales, purchase }

/// For the scoped (sales/purchase) screens: which single pane to render.
/// Invoices and Payments are deliberately kept as separate screens (their own
/// routes and bottom-nav tabs), never two tabs inside one. Ignored by
/// [InvoiceScope.finance], which always shows all three tabs.
enum InvoicePane { invoices, payments }

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({
    super.key,
    this.scope = InvoiceScope.finance,
    this.pane = InvoicePane.invoices,
  });

  /// Which slice of billing to show; drives the tab set / single pane + title.
  final InvoiceScope scope;

  /// For sales/purchase scopes, whether this screen is the Invoices list or the
  /// Payments list. Finance ignores it.
  final InvoicePane pane;

  bool get isFinance => scope == InvoiceScope.finance;

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  // Only the Finance hub is tabbed; scoped screens render a single pane.
  TabController? _tabs;

  @override
  void initState() {
    super.initState();
    if (widget.isFinance) {
      _tabs = TabController(length: 3, vsync: this)
        ..addListener(() {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  bool get _isSalesSide => widget.scope != InvoiceScope.purchase;

  String get _title => switch ((widget.scope, widget.pane)) {
        (InvoiceScope.finance, _) => 'Invoices',
        (InvoiceScope.sales, InvoicePane.invoices) => 'Sales Invoices',
        (InvoiceScope.sales, InvoicePane.payments) => 'Sales Payments',
        (InvoiceScope.purchase, InvoicePane.invoices) => 'Purchase Invoices',
        (InvoiceScope.purchase, InvoicePane.payments) => 'Purchase Payments',
      };

  Future<void> _newInvoice(InvoiceKind kind) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => NewInvoiceSheet(kind: kind),
    );
    if (!mounted || result == null) return;
    final label =
        kind == InvoiceKind.sales ? 'Sales Invoice' : 'Purchase Invoice';
    final what = result == 'submitted' ? 'submitted' : 'saved as draft';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label $what.')));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(invoicesControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.read(invoicesControllerProvider.notifier).reload(),
          ),
        ],
        bottom: widget.isFinance
            ? TabBar(
                controller: _tabs,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                indicatorColor: AppColors.secondaryContainer,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Sales'),
                  Tab(text: 'Purchase'),
                  Tab(text: 'Payments'),
                ],
              )
            : null,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Err(
          msg: e is ApiException ? e.message : 'Could not load invoices.',
          onRetry: () =>
              ref.read(invoicesControllerProvider.notifier).reload(),
        ),
        data: (ctx) {
          final salesList = _InvoiceList(
            invoices: ctx.sales,
            kind: InvoiceKind.sales,
            allowed: ctx.canReadSales,
          );
          final purchaseList = _InvoiceList(
            invoices: ctx.purchase,
            kind: InvoiceKind.purchase,
            allowed: ctx.canReadPurchase,
          );
          if (widget.isFinance) {
            return TabBarView(
              controller: _tabs,
              children: [
                salesList,
                purchaseList,
                _PaymentsTab(allowed: ctx.canReadPayments),
              ],
            );
          }
          // Scoped: a single pane — Invoices OR Payments, never both.
          if (widget.pane == InvoicePane.payments) {
            return _PaymentsTab(
                allowed: ctx.canReadPayments, lockSales: _isSalesSide);
          }
          return _isSalesSide ? salesList : purchaseList;
        },
      ),
      floatingActionButton: async.when(
        loading: () => null,
        error: (_, _) => null,
        data: (ctx) {
          // No FAB on any Payments view — payments are recorded against an
          // invoice from its detail screen, never as standalone here.
          if (!widget.isFinance && widget.pane == InvoicePane.payments) {
            return null;
          }
          // Finance: FAB follows the active tab (2 = Payments → none).
          final bool onSales;
          if (widget.isFinance) {
            final i = _tabs?.index ?? 0;
            if (i == 2) return null;
            onSales = i == 0;
          } else {
            onSales = _isSalesSide;
          }
          final allowed =
              onSales ? ctx.canCreateSales : ctx.canCreatePurchase;
          if (!allowed) return null;
          return FloatingActionButton.extended(
            backgroundColor: AppColors.secondaryContainer,
            foregroundColor: AppColors.onSecondaryContainer,
            icon: const Icon(Icons.add),
            label: Text(onSales ? 'New Sales' : 'New Purchase'),
            onPressed: () => _newInvoice(
                onSales ? InvoiceKind.sales : InvoiceKind.purchase),
          );
        },
      ),
    );
  }
}

class _InvoiceList extends ConsumerWidget {
  const _InvoiceList({
    required this.invoices,
    required this.kind,
    required this.allowed,
  });
  final List<Invoice> invoices;
  final InvoiceKind kind;
  final bool allowed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!allowed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: Text(
            kind == InvoiceKind.sales
                ? 'You do not have permission to view Sales Invoices.'
                : 'You do not have permission to view Purchase Invoices.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(invoicesControllerProvider.notifier).reload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
            AppDimens.md, AppDimens.screenPadding, AppDimens.xl),
        children: [
          _SummaryCard(invoices: invoices, kind: kind),
          const SizedBox(height: AppDimens.md),
          if (invoices.isEmpty)
            const _EmptyCard()
          else
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppDimens.md,
                        AppDimens.md, AppDimens.md, AppDimens.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                              kind == InvoiceKind.sales
                                  ? 'Recent Sales Invoices'
                                  : 'Recent Purchase Invoices',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                        ),
                        Text('${invoices.length}',
                            style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                  ),
                  for (var i = 0; i < invoices.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          indent: 64,
                          color: AppColors.outlineVariant),
                    _InvoiceRow(invoice: invoices[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.invoices, required this.kind});
  final List<Invoice> invoices;
  final InvoiceKind kind;

  @override
  Widget build(BuildContext context) {
    final currency =
        invoices.isNotEmpty ? invoices.first.currency : 'INR';
    final total = invoices.fold<double>(0, (s, i) => s + i.grandTotal);
    final outstanding =
        invoices.fold<double>(0, (s, i) => s + i.outstanding);
    final paid = invoices.where((i) => i.isPaid).length;
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              kind == InvoiceKind.sales
                  ? 'Sales billed'
                  : 'Purchases booked',
              style: TextStyle(
                  color: AppColors.primaryFixedDim, fontSize: 12)),
          const SizedBox(height: 4),
          Text(money(total, currency),
              style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: AppDimens.md),
          Row(children: [
            Expanded(
                child: _kv(context, 'Outstanding',
                    money(outstanding, currency))),
            Container(
                width: 1,
                height: 28,
                color: AppColors.primaryFixedDim.withValues(alpha: 0.25)),
            Expanded(
                child: _kv(context, 'Paid', '$paid / ${invoices.length}')),
          ]),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        Routes.invoiceDetail,
        extra: InvoiceDetailArgs(name: invoice.name, kind: invoice.kind),
      ),
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
            child: Icon(
                invoice.kind == InvoiceKind.sales
                    ? Icons.request_quote_outlined
                    : Icons.shopping_bag_outlined,
                color: AppColors.onSurfaceVariant,
                size: 20),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    invoice.partyDisplay.isNotEmpty
                        ? invoice.partyDisplay
                        : invoice.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    '${invoice.name} · ${_dateFmt.format(invoice.postingDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(money(invoice.grandTotal, invoice.currency),
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    if (invoice.outstanding > 0 && !invoice.isPaid) ...[
                      const SizedBox(width: AppDimens.sm),
                      Text(
                          'Due ${money(invoice.outstanding, invoice.currency)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ],
            ),
          ),
          _StatusChip(invoice: invoice),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.invoice});
  final Invoice invoice;
  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label = invoice.status.isEmpty ? 'Draft' : invoice.status;
    if (invoice.isDraft) label = 'Draft';
    final s = label.toLowerCase();

    if (invoice.isDraft) {
      bg = AppColors.surfaceContainerHigh;
      fg = AppColors.onSurfaceVariant;
    } else if (s.contains('paid') && !s.contains('unpaid') && !s.contains('partly')) {
      bg = AppColors.tertiaryFixed;
      fg = AppColors.onTertiaryFixedVariant;
    } else if (s.contains('overdue')) {
      bg = AppColors.errorContainer;
      fg = AppColors.onErrorContainer;
    } else if (s.contains('cancel')) {
      bg = AppColors.surfaceContainerHigh;
      fg = AppColors.onSurfaceVariant;
    } else if (s.contains('return') || s.contains('credit')) {
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Row(
          children: [
            Icon(Icons.receipt_outlined, color: AppColors.outline),
            const SizedBox(width: AppDimens.md),
            Expanded(
                child: Text('No invoices to show.',
                    style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

class _Err extends StatelessWidget {
  const _Err({required this.msg, required this.onRetry});
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

class _PaymentsTab extends ConsumerStatefulWidget {
  const _PaymentsTab({required this.allowed, this.lockSales});
  final bool allowed;

  /// When non-null the Sales/Purchase toggle is hidden and the list is locked
  /// to that side (true = sales receipts, false = supplier payments). Used by
  /// the Sales- and Purchase-scoped screens; null keeps the toggle (Finance).
  final bool? lockSales;
  @override
  ConsumerState<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends ConsumerState<_PaymentsTab> {
  // true  -> Sales payments (money Received from customers)
  // false -> Purchase payments (money Paid to suppliers)
  late bool _sales = widget.lockSales ?? true;

  @override
  Widget build(BuildContext context) {
    if (!widget.allowed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: Text(
            'You do not have permission to view Payment Entries.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    final async = ref.watch(paymentsControllerProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Err(
        msg: e is ApiException ? e.message : 'Could not load payments.',
        onRetry: () =>
            ref.read(paymentsControllerProvider.notifier).reload(),
      ),
      data: (ctx) {
        // Split the mixed entries: Receive = sales, Pay = purchase.
        final payments = ctx.payments.where((p) {
          final t = p.paymentType.toLowerCase();
          return _sales ? t == 'receive' : t == 'pay';
        }).toList();
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(paymentsControllerProvider.notifier).reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
                AppDimens.md, AppDimens.screenPadding, AppDimens.xl),
            children: [
              DateRangeBar(
                from: ctx.fromDate,
                to: ctx.toDate,
                onChanged: (f, t) => ref
                    .read(paymentsControllerProvider.notifier)
                    .setRange(f, t),
              ),
              const SizedBox(height: AppDimens.md),
              if (widget.lockSales == null) ...[
                _PaymentsSegmented(
                  sales: _sales,
                  onChanged: (v) => setState(() => _sales = v),
                ),
                const SizedBox(height: AppDimens.md),
              ],
              _PaymentsSummary(
                  payments: payments,
                  sales: _sales,
                  from: ctx.fromDate,
                  to: ctx.toDate),
              const SizedBox(height: AppDimens.md),
              if (payments.isEmpty)
                const _EmptyCard()
              else
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppDimens.md,
                            AppDimens.md, AppDimens.md, AppDimens.sm),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                                _sales
                                    ? 'Sales Payments'
                                    : 'Purchase Payments',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600)),
                          ),
                          Text('${payments.length}',
                              style:
                                  Theme.of(context).textTheme.labelMedium),
                        ]),
                      ),
                      for (var i = 0; i < payments.length; i++) ...[
                        if (i > 0)
                          Divider(
                              height: 1,
                              indent: 64,
                              color: AppColors.outlineVariant),
                        _PaymentRow(p: payments[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Sales / Purchase switch for the Payments tab — keeps customer receipts and
/// supplier payments in separate views instead of one mixed list.
class _PaymentsSegmented extends StatelessWidget {
  const _PaymentsSegmented({required this.sales, required this.onChanged});
  final bool sales;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _seg(context, label: 'Sales', selected: sales, onTap: () => onChanged(true)),
          _seg(context, label: 'Purchase', selected: !sales, onTap: () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context,
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentsSummary extends StatelessWidget {
  const _PaymentsSummary({
    required this.payments,
    required this.sales,
    required this.from,
    required this.to,
  });
  final List<Payment> payments;
  final bool sales;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for (final p in payments) {
      if (p.docstatus != 1) continue;
      total += p.paidAmount;
    }
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${_dateFmt.format(from)} – ${_dateFmt.format(to)} · ${payments.length} ${payments.length == 1 ? 'entry' : 'entries'}',
              style: TextStyle(
                  color: AppColors.primaryFixedDim, fontSize: 12)),
          const SizedBox(height: AppDimens.md),
          Text(sales ? 'Received from customers' : 'Paid to suppliers',
              style: TextStyle(
                  color: AppColors.primaryFixedDim, fontSize: 11)),
          const SizedBox(height: 2),
          Text(money(total, 'INR'),
              style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.p});
  final Payment p;
  @override
  Widget build(BuildContext context) {
    final isReceive = p.paymentType.toLowerCase() == 'receive';
    return Padding(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isReceive
                  ? AppColors.tertiaryFixed
                  : AppColors.secondaryFixed,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            alignment: Alignment.center,
            child: Icon(
                isReceive
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: isReceive
                    ? AppColors.onTertiaryFixedVariant
                    : AppColors.onSecondaryFixedVariant,
                size: 20),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    p.partyName.isEmpty ? p.party : p.partyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    [
                      p.name,
                      if (p.postingDate != null)
                        _dateFmt.format(p.postingDate!),
                      if (p.modeOfPayment != null) p.modeOfPayment,
                    ].whereType<String>().join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          Text(
              (isReceive ? '+ ' : '- ') + money(p.paidAmount, 'INR'),
              style: TextStyle(
                  color: isReceive
                      ? AppColors.onTertiaryFixedVariant
                      : AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
