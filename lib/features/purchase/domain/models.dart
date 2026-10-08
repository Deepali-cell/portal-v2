import 'package:flutter/foundation.dart';

@immutable
class QuotationComparisonRow {
  const QuotationComparisonRow({
    required this.name,
    required this.supplier,
    required this.supplierName,
    required this.status,
    required this.grandTotal,
    required this.currency,
    required this.rates,
  });
  final String name;
  final String supplier;
  final String supplierName;
  final String status;
  final double grandTotal;
  final String currency;
  final Map<String, double?> rates;

  factory QuotationComparisonRow.fromJson(Map<String, dynamic> j) =>
      QuotationComparisonRow(
        name: (j['name'] ?? '').toString(),
        supplier: (j['supplier'] ?? '').toString(),
        supplierName: (j['supplier_name'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        grandTotal: (j['grand_total'] as num?)?.toDouble() ?? 0.0,
        currency: (j['currency'] ?? '').toString(),
        rates: ((j['rates'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble()),
        ),
      );
}

@immutable
class QuotationComparison {
  const QuotationComparison({required this.items, required this.quotations});
  final List<String> items;
  final List<QuotationComparisonRow> quotations;

  factory QuotationComparison.fromJson(Map<String, dynamic> j) =>
      QuotationComparison(
        items: ((j['items'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        quotations: ((j['quotations'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) =>
                QuotationComparisonRow.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}
