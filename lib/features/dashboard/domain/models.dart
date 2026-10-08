import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class TodaySnapshot {
  const TodaySnapshot({
    required this.calls,
    required this.callsConnected,
    required this.leadsAdded,
    required this.tasksDue,
    required this.monthWonValue,
  });
  final int calls;
  final int callsConnected;
  final int leadsAdded;
  final int tasksDue;
  final double monthWonValue;

  factory TodaySnapshot.fromJson(Map<String, dynamic> j) => TodaySnapshot(
    calls: (j['calls'] as num?)?.toInt() ?? 0,
    callsConnected: (j['calls_connected'] as num?)?.toInt() ?? 0,
    leadsAdded: (j['leads_added'] as num?)?.toInt() ?? 0,
    tasksDue: (j['tasks_due'] as num?)?.toInt() ?? 0,
    monthWonValue: (j['month_won_value'] as num?)?.toDouble() ?? 0,
  );
}

@immutable
class FollowupItem {
  const FollowupItem({
    required this.name,
    required this.bucket,
    this.title,
    this.dueDate,
    this.status,
    this.priority,
    this.referenceDoctype,
    this.referenceDocname,
  });
  final String name;

  /// One of 'overdue', 'due_today', 'upcoming'.
  final String bucket;
  final String? title;
  final DateTime? dueDate;
  final String? status;
  final String? priority;
  final String? referenceDoctype;
  final String? referenceDocname;

  factory FollowupItem.fromJson(Map<String, dynamic> j) => FollowupItem(
    name: (j['name'] ?? '').toString(),
    bucket: (j['bucket'] ?? '').toString(),
    title: j['title'] as String?,
    dueDate: _parseDate(j['due_date']),
    status: j['status'] as String?,
    priority: j['priority'] as String?,
    referenceDoctype: j['reference_doctype'] as String?,
    referenceDocname: j['reference_docname'] as String?,
  );
}

@immutable
class FollowupsBucket {
  const FollowupsBucket({
    required this.dueToday,
    required this.overdue,
    required this.upcomingWeek,
    this.items = const [],
  });
  final int dueToday;
  final int overdue;
  final int upcomingWeek;
  final List<FollowupItem> items;

  factory FollowupsBucket.fromJson(Map<String, dynamic> j) => FollowupsBucket(
    dueToday: (j['due_today'] as num?)?.toInt() ?? 0,
    overdue: (j['overdue'] as num?)?.toInt() ?? 0,
    upcomingWeek: (j['upcoming_week'] as num?)?.toInt() ?? 0,
    items: ((j['items'] as List?) ?? [])
        .map((e) => FollowupItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

@immutable
class StatusBucket {
  const StatusBucket({
    required this.status,
    required this.count,
    required this.value,
    required this.color,
    this.staleCount = 0,
  });
  final String status;
  final int count;
  final double value;
  final int staleCount;
  final Color color;

  factory StatusBucket.fromJson(Map<String, dynamic> j) => StatusBucket(
    status: (j['status'] ?? '').toString(),
    count: (j['count'] as num?)?.toInt() ?? 0,
    value: (j['value'] as num?)?.toDouble() ?? 0,
    staleCount: (j['stale_count'] as num?)?.toInt() ?? 0,
    color: _parseColor(j['color'] as String?),
  );
}

@immutable
class RecentSummary {
  const RecentSummary({
    required this.name,
    required this.displayName,
    this.summary,
    this.suggestedStatus,
    this.sentiment,
    this.aiProcessedAt,
    this.referenceDoctype,
    this.referenceDocname,
  });
  final String name;
  final String displayName;
  final String? summary;
  final String? suggestedStatus;
  final String? sentiment;
  final DateTime? aiProcessedAt;
  final String? referenceDoctype;
  final String? referenceDocname;

  factory RecentSummary.fromJson(Map<String, dynamic> j) => RecentSummary(
    name: (j['name'] ?? '').toString(),
    displayName: (j['display_name'] ?? j['phone_number'] ?? 'call').toString(),
    summary: j['summary'] as String?,
    suggestedStatus: j['suggested_status'] as String?,
    sentiment: j['sentiment'] as String?,
    aiProcessedAt: _parseDate(j['ai_processed_at']),
    referenceDoctype: j['reference_doctype'] as String?,
    referenceDocname: j['reference_docname'] as String?,
  );
}

@immutable
class QuickCounts {
  const QuickCounts({required this.uncontactedLeads, required this.openDeals});
  final int uncontactedLeads;
  final int openDeals;
  factory QuickCounts.fromJson(Map<String, dynamic> j) => QuickCounts(
    uncontactedLeads: (j['uncontacted_leads'] as num?)?.toInt() ?? 0,
    openDeals: (j['open_deals'] as num?)?.toInt() ?? 0,
  );
}

@immutable
class PerRepCard {
  const PerRepCard({
    required this.user,
    required this.fullName,
    this.image,
    this.leadsOwned = 0,
    this.leadsStale = 0,
    this.callsToday = 0,
    this.tasksDue = 0,
    this.tasksOverdue = 0,
    this.dealsWonMonth = 0,
  });
  final String user;
  final String fullName;
  final String? image;
  final int leadsOwned;
  final int leadsStale;
  final int callsToday;
  final int tasksDue;
  final int tasksOverdue;
  final int dealsWonMonth;

  factory PerRepCard.fromJson(Map<String, dynamic> j) => PerRepCard(
    user: (j['user'] ?? '').toString(),
    fullName: (j['full_name'] ?? '').toString(),
    image: j['image'] as String?,
    leadsOwned: (j['leads_owned'] as num?)?.toInt() ?? 0,
    leadsStale: (j['leads_stale'] as num?)?.toInt() ?? 0,
    callsToday: (j['calls_today'] as num?)?.toInt() ?? 0,
    tasksDue: (j['tasks_due'] as num?)?.toInt() ?? 0,
    tasksOverdue: (j['tasks_overdue'] as num?)?.toInt() ?? 0,
    dealsWonMonth: (j['deals_won_month'] as num?)?.toInt() ?? 0,
  );

  String get initials {
    final parts = fullName.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

@immutable
class SalesDashboard {
  const SalesDashboard({
    required this.scope,
    required this.isManagerView,
    required this.canLead,
    required this.canDeal,
    required this.today,
    required this.followups,
    required this.leadStatuses,
    required this.dealStatuses,
    required this.recentSummaries,
    required this.quickCounts,
    required this.perRep,
    this.asOf,
  });
  final String scope;
  final bool isManagerView;
  final bool canLead;
  final bool canDeal;
  final TodaySnapshot today;
  final FollowupsBucket followups;
  final List<StatusBucket> leadStatuses;
  final List<StatusBucket> dealStatuses;
  final List<RecentSummary> recentSummaries;
  final QuickCounts quickCounts;
  final List<PerRepCard> perRep;
  final DateTime? asOf;

  factory SalesDashboard.fromJson(Map<String, dynamic> j) => SalesDashboard(
    scope: (j['scope'] ?? 'mine').toString(),
    isManagerView: j['is_manager_view'] == true,
    canLead: j['can_lead'] == true,
    canDeal: j['can_deal'] == true,
    today: TodaySnapshot.fromJson(
      (j['today_snapshot'] as Map?)?.cast<String, dynamic>() ?? {},
    ),
    followups: FollowupsBucket.fromJson(
      (j['followups'] as Map?)?.cast<String, dynamic>() ?? {},
    ),
    leadStatuses: ((j['lead_statuses'] as List?) ?? [])
        .map((e) => StatusBucket.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    dealStatuses: ((j['deal_statuses'] as List?) ?? [])
        .map((e) => StatusBucket.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    recentSummaries: ((j['recent_summaries'] as List?) ?? [])
        .map((e) => RecentSummary.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    quickCounts: QuickCounts.fromJson(
      (j['quick_counts'] as Map?)?.cast<String, dynamic>() ?? {},
    ),
    perRep: ((j['per_rep'] as List?) ?? [])
        .map((e) => PerRepCard.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    asOf: _parseDate(j['as_of']),
  );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

Color _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF022B60);
  final cleaned = hex.replaceFirst('#', '');
  final n = int.tryParse(cleaned, radix: 16);
  if (n == null) return const Color(0xFF022B60);
  return Color(cleaned.length == 6 ? (0xFF000000 | n) : n);
}
