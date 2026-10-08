import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/ui/app_message_dialog.dart';
import '../data/purchase_repository.dart';
import '../domain/models.dart';

/// Side-by-side rate comparison of every Supplier Quotation raised against an
/// RFQ. Read model built by tcb_portal_erp.api.purchase.compare_quotations.
class PurchaseComparisonScreen extends ConsumerStatefulWidget {
  const PurchaseComparisonScreen({super.key, required this.requestForQuotation});
  final String requestForQuotation;

  @override
  ConsumerState<PurchaseComparisonScreen> createState() =>
      _PurchaseComparisonScreenState();
}

class _PurchaseComparisonScreenState
    extends ConsumerState<PurchaseComparisonScreen> {
  QuotationComparison? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await ref
          .read(purchaseRepositoryProvider)
          .compareQuotations(widget.requestForQuotation);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Compare Quotations'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _load,
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Text(friendlyMessageFor(_error!).message,
              textAlign: TextAlign.center),
        ),
      );
    }
    final data = _data!;
    if (data.quotations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimens.lg),
          child: Text('No supplier quotations raised against this RFQ yet.'),
        ),
      );
    }

    // Lowest rate per item, to highlight the best price in each row.
    final lowest = <String, double>{};
    for (final item in data.items) {
      for (final q in data.quotations) {
        final r = q.rates[item];
        if (r != null && (!lowest.containsKey(item) || r < lowest[item]!)) {
          lowest[item] = r;
        }
      }
    }

    final columns = <DataColumn>[
      const DataColumn(label: Text('Item')),
      for (final q in data.quotations)
        DataColumn(
          label: Text(
            q.supplierName.isNotEmpty ? q.supplierName : q.supplier,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];

    final rows = <DataRow>[
      for (final item in data.items)
        DataRow(cells: [
          DataCell(Text(item)),
          for (final q in data.quotations)
            DataCell(_rateCell(q.rates[item], lowest[item], q.currency)),
        ]),
      // Grand total row.
      DataRow(
        color: WidgetStateProperty.all(AppColors.surfaceVariant),
        cells: [
          const DataCell(Text('Grand Total',
              style: TextStyle(fontWeight: FontWeight.w700))),
          for (final q in data.quotations)
            DataCell(Text(
              '${q.currency} ${q.grandTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            )),
        ],
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(columns: columns, rows: rows),
      ),
    );
  }

  Widget _rateCell(double? rate, double? lowest, String currency) {
    if (rate == null) {
      return Text('-', style: TextStyle(color: AppColors.onSurfaceVariant));
    }
    final isLowest = lowest != null && rate <= lowest;
    return Text(
      '$currency ${rate.toStringAsFixed(2)}',
      style: TextStyle(
        color: isLowest ? AppColors.primary : null,
        fontWeight: isLowest ? FontWeight.w700 : FontWeight.normal,
      ),
    );
  }
}
