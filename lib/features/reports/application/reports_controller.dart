import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/reports_repository.dart';
import '../domain/models.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>(
    (ref) => ReportsRepository(ref.watch(dioProvider)));

/// The reports visible to the current user inside one module.
final moduleReportsProvider =
    FutureProvider.family<List<ReportModule>, String>((ref, module) {
  return ref.read(reportsRepositoryProvider).listReports(module: module);
});

/// Arguments for running one report: its key plus any filter overrides.
class RunReportArgs {
  const RunReportArgs(this.key, {this.filters});
  final String key;
  final Map<String, dynamic>? filters;

  @override
  bool operator ==(Object other) =>
      other is RunReportArgs &&
      other.key == key &&
      _mapEquals(other.filters, filters);

  @override
  int get hashCode => Object.hash(key, filters?.length ?? 0);
}

bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (a[k] != b[k]) return false;
  }
  return true;
}

/// Runs one report (with optional filter overrides) and returns its result.
final runReportProvider =
    FutureProvider.family<ReportResult, RunReportArgs>((ref, args) {
  return ref
      .read(reportsRepositoryProvider)
      .runReport(args.key, filters: args.filters);
});
