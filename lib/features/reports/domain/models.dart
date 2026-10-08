import 'package:flutter/foundation.dart';

/// One report the current user may run, as returned by `reports.list_reports`.
@immutable
class ReportRef {
  const ReportRef({
    required this.key,
    required this.label,
    required this.report,
    this.filterSet,
  });

  final String key;
  final String label;

  /// The underlying ERPNext Report document name.
  final String report;

  /// Which default-filter bundle the backend applies (fiscal/date/…). The app
  /// uses it only to decide whether to offer a date-range control.
  final String? filterSet;

  factory ReportRef.fromJson(Map<String, dynamic> j) => ReportRef(
        key: j['key'] as String,
        label: (j['label'] ?? j['key']) as String,
        report: (j['report'] ?? '') as String,
        filterSet: j['filter_set'] as String?,
      );

  /// True for reports keyed off a simple from/to date window (General Ledger,
  /// Sales/Purchase Register, Stock Balance/Ledger, Gross Profit).
  bool get hasDateRange => filterSet == 'date';
}

/// A module (Accounts/Sales/Purchase/Stock) plus the reports visible in it.
@immutable
class ReportModule {
  const ReportModule({required this.module, required this.reports});
  final String module;
  final List<ReportRef> reports;

  factory ReportModule.fromJson(Map<String, dynamic> j) => ReportModule(
        module: j['module'] as String,
        reports: ((j['reports'] as List?) ?? const [])
            .map((e) => ReportRef.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// One column in a report result. Frappe returns columns either as dicts
/// ({label, fieldname, fieldtype, width}) or as legacy "Label:Type:Width"
/// strings - both are handled here.
@immutable
class ReportColumn {
  const ReportColumn({
    required this.label,
    required this.fieldname,
    this.fieldtype = 'Data',
    this.width,
  });

  final String label;
  final String fieldname;
  final String fieldtype;
  final int? width;

  bool get isNumeric => const {
        'Currency',
        'Float',
        'Int',
        'Percent',
      }.contains(fieldtype);

  factory ReportColumn.fromAny(dynamic col, int index) {
    if (col is Map) {
      final m = col.cast<String, dynamic>();
      final label = (m['label'] ?? m['fieldname'] ?? 'Col ${index + 1}')
          .toString();
      final fieldname = (m['fieldname'] ?? label).toString();
      return ReportColumn(
        label: label,
        fieldname: fieldname,
        fieldtype: (m['fieldtype'] ?? 'Data').toString(),
        width: (m['width'] is num) ? (m['width'] as num).toInt() : null,
      );
    }
    // Legacy string form: "Label:Fieldtype[/options]:Width".
    final parts = col.toString().split(':');
    final label = parts.isNotEmpty ? parts[0] : 'Col ${index + 1}';
    var fieldtype = parts.length > 1 ? parts[1] : 'Data';
    if (fieldtype.contains('/')) fieldtype = fieldtype.split('/').first;
    final width = parts.length > 2 ? int.tryParse(parts[2]) : null;
    return ReportColumn(
      label: label,
      fieldname: label.toLowerCase().replaceAll(' ', '_'),
      fieldtype: fieldtype.isEmpty ? 'Data' : fieldtype,
      width: width,
    );
  }
}

/// A fully-run report: its columns and rows, ready to render as a table.
@immutable
class ReportResult {
  const ReportResult({
    required this.label,
    required this.columns,
    required this.rows,
    this.filters = const {},
  });

  final String label;
  final List<ReportColumn> columns;

  /// Each row is a list of raw cell values aligned to [columns].
  final List<List<dynamic>> rows;
  final Map<String, dynamic> filters;

  factory ReportResult.fromJson(Map<String, dynamic> j) {
    final rawCols = (j['columns'] as List?) ?? const [];
    final columns = [
      for (var i = 0; i < rawCols.length; i++)
        ReportColumn.fromAny(rawCols[i], i),
    ];

    final rawRows = (j['result'] as List?) ?? const [];
    final rows = <List<dynamic>>[];
    for (final r in rawRows) {
      if (r is Map) {
        final m = r.cast<String, dynamic>();
        rows.add([for (final c in columns) m[c.fieldname]]);
      } else if (r is List) {
        rows.add([
          for (var i = 0; i < columns.length; i++)
            i < r.length ? r[i] : null,
        ]);
      }
      // Non-map/list rows (rare separators) are skipped.
    }

    return ReportResult(
      label: (j['label'] ?? j['report'] ?? 'Report').toString(),
      columns: columns,
      rows: rows,
      filters: ((j['filters'] as Map?) ?? const {}).cast<String, dynamic>(),
    );
  }
}
