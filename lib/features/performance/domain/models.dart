import 'package:flutter/foundation.dart';

/// One person's activity for the selected window.
@immutable
class PerformanceRow {
  const PerformanceRow({
    required this.user,
    required this.fullName,
    this.image,
    this.leads = 0,
    this.opps = 0,
    this.dealsWon = 0,
    this.revenue = 0,
    this.calls = 0,
  });

  final String user;
  final String fullName;
  final String? image;
  final int leads;
  final int opps;
  final int dealsWon;
  final double revenue;
  final int calls;

  /// A single "effort" number used to rank/scale bars — total touches.
  int get activity => leads + opps + calls;

  factory PerformanceRow.fromJson(Map<String, dynamic> j) => PerformanceRow(
        user: (j['user'] ?? '').toString(),
        fullName: (j['full_name'] ?? j['user'] ?? '').toString(),
        image: (j['image'] as String?)?.isNotEmpty == true
            ? j['image'] as String?
            : null,
        leads: (j['leads'] as num?)?.toInt() ?? 0,
        opps: (j['opps'] as num?)?.toInt() ?? 0,
        dealsWon: (j['deals_won'] as num?)?.toInt() ?? 0,
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0.0,
        calls: (j['calls'] as num?)?.toInt() ?? 0,
      );
}

/// Team totals + per-person breakdown (managers only).
@immutable
class PerformanceTeam {
  const PerformanceTeam({required this.totals, required this.people});
  final PerformanceRow totals;
  final List<PerformanceRow> people;

  factory PerformanceTeam.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PerformanceTeam(
      totals: PerformanceRow(
        user: '_totals',
        fullName: 'Team total',
        leads: (t['leads'] as num?)?.toInt() ?? 0,
        opps: (t['opps'] as num?)?.toInt() ?? 0,
        dealsWon: (t['deals_won'] as num?)?.toInt() ?? 0,
        revenue: (t['revenue'] as num?)?.toDouble() ?? 0.0,
        calls: (t['calls'] as num?)?.toInt() ?? 0,
      ),
      people: ((j['people'] as List?) ?? const [])
          .map((e) => PerformanceRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  int get peopleCount => people.length;
}

@immutable
class PerformanceSnapshot {
  const PerformanceSnapshot({
    required this.scope,
    required this.isManagerView,
    required this.fromDate,
    required this.toDate,
    required this.self,
    this.team,
  });

  final String scope;
  final bool isManagerView;
  final DateTime? fromDate;
  final DateTime? toDate;
  final PerformanceRow self;
  final PerformanceTeam? team;

  factory PerformanceSnapshot.fromJson(Map<String, dynamic> j) =>
      PerformanceSnapshot(
        scope: (j['scope'] ?? 'mine').toString(),
        isManagerView: j['is_manager_view'] == true,
        fromDate: DateTime.tryParse((j['from_date'] ?? '').toString()),
        toDate: DateTime.tryParse((j['to_date'] ?? '').toString()),
        self: PerformanceRow.fromJson(
            (j['self'] as Map?)?.cast<String, dynamic>() ?? const {}),
        team: j['team'] == null
            ? null
            : PerformanceTeam.fromJson((j['team'] as Map).cast<String, dynamic>()),
      );
}
