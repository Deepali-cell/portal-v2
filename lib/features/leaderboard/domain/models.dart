import 'package:flutter/foundation.dart';

enum LeaderboardMetric { dealsWon, callsLogged, leadsWorked, outcomesCaptured }

extension LeaderboardMetricX on LeaderboardMetric {
  String get backendValue => switch (this) {
        LeaderboardMetric.dealsWon => 'deals_won',
        LeaderboardMetric.callsLogged => 'calls_logged',
        LeaderboardMetric.leadsWorked => 'leads_worked',
        LeaderboardMetric.outcomesCaptured => 'outcomes_captured',
      };
  String get label => switch (this) {
        LeaderboardMetric.dealsWon => 'Deals won',
        LeaderboardMetric.callsLogged => 'Calls logged',
        LeaderboardMetric.leadsWorked => 'Leads worked',
        LeaderboardMetric.outcomesCaptured => 'Outcomes captured',
      };
}

@immutable
class LeaderboardSnapshot {
  const LeaderboardSnapshot({
    required this.isManagerView,
    required this.metric,
    required this.fromDate,
    required this.toDate,
    required this.leaders,
  });
  final bool isManagerView;
  final LeaderboardMetric metric;
  final DateTime? fromDate;
  final DateTime? toDate;
  final List<LeaderboardEntry> leaders;

  factory LeaderboardSnapshot.fromJson(Map<String, dynamic> j) {
    final period = (j['period'] as Map?)?.cast<String, dynamic>();
    return LeaderboardSnapshot(
      isManagerView: j['is_manager_view'] == true,
      metric: _parseMetric(j['metric'] as String?),
      fromDate: period == null ? null : DateTime.tryParse(period['from'] as String? ?? ''),
      toDate: period == null ? null : DateTime.tryParse(period['to'] as String? ?? ''),
      leaders: ((j['leaders'] as List?) ?? const [])
          .map((e) => LeaderboardEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

LeaderboardMetric _parseMetric(String? s) {
  for (final m in LeaderboardMetric.values) {
    if (m.backendValue == s) return m;
  }
  return LeaderboardMetric.dealsWon;
}

@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.user,
    required this.fullName,
    required this.value,
    this.image,
  });
  final String user;
  final String fullName;
  final int value;
  final String? image;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        user: j['user'].toString(),
        fullName: (j['full_name'] ?? j['user']).toString(),
        value: (j['value'] as num?)?.toInt() ?? 0,
        image: j['image'] as String?,
      );
}
