import 'package:intl/intl.dart';

/// Formats an amount in the given currency (ISO code, e.g. "INR").
/// Uses the locale's symbol where known, falling back to the code.
String money(num? amount, String? currencyCode) {
  final value = amount ?? 0;
  final code = currencyCode ?? 'INR';
  final symbol = _symbols[code];
  final fmt = symbol != null
      ? NumberFormat.currency(symbol: symbol, decimalDigits: 2)
      : NumberFormat.currency(name: '$code ', decimalDigits: 2);
  return fmt.format(value);
}

const Map<String, String> _symbols = {
  'INR': '₹', // ₹
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'AED': 'AED ',
};

/// Compact rupee/currency format for tight UI (pipeline bars, dashboards):
/// 1234567 -> "₹12.3L", 12345678 -> "₹1.2Cr", 1234 -> "₹1.2K".
String moneyShort(num? amount, {String currencyCode = 'INR'}) {
  final v = (amount ?? 0).toDouble();
  final symbol = _symbols[currencyCode] ?? '$currencyCode ';
  final abs = v.abs();
  String body;
  if (abs >= 1e7) {
    body = '${(v / 1e7).toStringAsFixed(v.abs() >= 1e8 ? 0 : 1)}Cr';
  } else if (abs >= 1e5) {
    body = '${(v / 1e5).toStringAsFixed(v.abs() >= 1e6 ? 0 : 1)}L';
  } else if (abs >= 1000) {
    body = '${(v / 1000).toStringAsFixed(v.abs() >= 1e4 ? 0 : 1)}K';
  } else {
    body = v.toStringAsFixed(0);
  }
  return '$symbol$body';
}
