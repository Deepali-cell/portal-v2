import 'dart:ui';

import 'package:flutter/foundation.dart';

enum PipelineKind { leads, deals }

extension PipelineKindX on PipelineKind {
  String get label => switch (this) {
        PipelineKind.leads => 'Leads',
        PipelineKind.deals => 'Deals',
      };
}

enum PipelineScope { mine, team }

extension PipelineScopeX on PipelineScope {
  String get apiValue => switch (this) {
        PipelineScope.mine => 'mine',
        PipelineScope.team => 'team',
      };
  String get label => switch (this) {
        PipelineScope.mine => 'My pipeline',
        PipelineScope.team => 'Team pipeline',
      };
}

@immutable
class PipelineStage {
  const PipelineStage({
    required this.status,
    required this.position,
    required this.count,
    required this.value,
    required this.staleCount,
    required this.color,
  });

  final String status;
  final int position;
  final int count;
  final double value;
  final int staleCount;
  final Color color;

  factory PipelineStage.fromJson(Map<String, dynamic> j) => PipelineStage(
        status: (j['status'] ?? '').toString(),
        position: (j['position'] as num?)?.toInt() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
        value: (j['value'] as num?)?.toDouble() ?? 0.0,
        staleCount: (j['stale_count'] as num?)?.toInt() ?? 0,
        color: _parseColor(j['color'] as String?),
      );
}

@immutable
class PipelineSnapshot {
  const PipelineSnapshot({
    required this.scope,
    required this.isManagerView,
    required this.fromDate,
    required this.toDate,
    required this.staleDays,
    required this.totalCount,
    required this.totalValue,
    required this.stages,
  });

  final String scope;
  final bool isManagerView;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int staleDays;
  final int totalCount;
  final double totalValue;
  final List<PipelineStage> stages;

  factory PipelineSnapshot.fromJson(Map<String, dynamic> j) =>
      PipelineSnapshot(
        scope: (j['scope'] ?? 'mine').toString(),
        isManagerView: j['is_manager_view'] == true,
        fromDate: _parseDate(j['from_date']),
        toDate: _parseDate(j['to_date']),
        staleDays: (j['stale_days'] as num?)?.toInt() ?? 14,
        totalCount: (j['total_count'] as num?)?.toInt() ?? 0,
        totalValue: (j['total_value'] as num?)?.toDouble() ?? 0.0,
        stages: ((j['stages'] as List?) ?? [])
            .map((e) => PipelineStage.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

Color _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF022B60);
  final cleaned = hex.replaceFirst('#', '');
  final n = int.tryParse(cleaned, radix: 16);
  if (n == null) return const Color(0xFF022B60);
  // Add full alpha if not provided.
  return Color(cleaned.length == 6 ? (0xFF000000 | n) : n);
}
