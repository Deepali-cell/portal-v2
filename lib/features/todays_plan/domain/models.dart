import 'package:flutter/foundation.dart';

/// Snapshot of the salesperson's day — aggregated from the backend in one
/// call so the home screen renders without N+1 round-trips.
@immutable
class TodaysPlan {
  const TodaysPlan({
    required this.asOf,
    required this.dueToday,
    required this.overdue,
    required this.uncontactedLeadsCount,
    required this.tasksToday,
    required this.crmTasksToday,
    required this.overdueTasks,
    required this.overdueCrmTasks,
    required this.uncontactedLeads,
  });

  final DateTime asOf;
  final int dueToday;
  final int overdue;
  final int uncontactedLeadsCount;
  final List<PlanTask> tasksToday;
  final List<PlanCrmTask> crmTasksToday;
  final List<PlanTask> overdueTasks;
  final List<PlanCrmTask> overdueCrmTasks;
  final List<PlanLead> uncontactedLeads;

  bool get isEmpty =>
      dueToday == 0 && overdue == 0 && uncontactedLeadsCount == 0;

  factory TodaysPlan.fromJson(Map<String, dynamic> j) {
    final counts = (j['counts'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TodaysPlan(
      asOf: DateTime.parse(j['as_of'] as String),
      dueToday: (counts['due_today'] as num?)?.toInt() ?? 0,
      overdue: (counts['overdue'] as num?)?.toInt() ?? 0,
      uncontactedLeadsCount:
          (counts['uncontacted_leads'] as num?)?.toInt() ?? 0,
      tasksToday: ((j['tasks_today'] as List?) ?? const [])
          .map((e) => PlanTask.fromJson(_asMap(e)))
          .toList(),
      crmTasksToday: ((j['crm_tasks_today'] as List?) ?? const [])
          .map((e) => PlanCrmTask.fromJson(_asMap(e)))
          .toList(),
      overdueTasks: ((j['overdue_tasks'] as List?) ?? const [])
          .map((e) => PlanTask.fromJson(_asMap(e)))
          .toList(),
      overdueCrmTasks: ((j['overdue_crm_tasks'] as List?) ?? const [])
          .map((e) => PlanCrmTask.fromJson(_asMap(e)))
          .toList(),
      uncontactedLeads: ((j['uncontacted_leads'] as List?) ?? const [])
          .map((e) => PlanLead.fromJson(_asMap(e)))
          .toList(),
    );
  }
}

@immutable
class PlanTask {
  const PlanTask({
    required this.name,
    required this.subject,
    required this.status,
    this.priority,
    this.expEndDate,
    this.project,
    this.dueLabel,
    this.daysOverdue,
  });

  final String name;
  final String subject;
  final String status;
  final String? priority;
  final DateTime? expEndDate;
  final String? project;
  final String? dueLabel;
  final int? daysOverdue;

  factory PlanTask.fromJson(Map<String, dynamic> j) => PlanTask(
    name: j['name'].toString(),
    subject: (j['subject'] ?? '').toString(),
    status: (j['status'] ?? 'Open').toString(),
    priority: j['priority'] as String?,
    expEndDate: _parseDate(j['exp_end_date']),
    project: j['project'] as String?,
    dueLabel: j['due_label'] as String?,
    daysOverdue: (j['days_overdue'] as num?)?.toInt(),
  );
}

@immutable
class PlanCrmTask {
  const PlanCrmTask({
    required this.name,
    required this.title,
    required this.status,
    this.priority,
    this.dueDate,
    this.referenceDoctype,
    this.referenceDocname,
    this.linkedLabel,
    this.dueLabel,
    this.daysOverdue,
  });

  final String name;
  final String title;
  final String status;
  final String? priority;
  final DateTime? dueDate;
  final String? referenceDoctype;
  final String? referenceDocname;
  final String? linkedLabel;
  final String? dueLabel;
  final int? daysOverdue;

  factory PlanCrmTask.fromJson(Map<String, dynamic> j) => PlanCrmTask(
    name: j['name'].toString(),
    title: (j['title'] ?? '').toString(),
    status: (j['status'] ?? 'Todo').toString(),
    priority: j['priority'] as String?,
    dueDate: _parseDate(j['due_date']),
    referenceDoctype: j['reference_doctype'] as String?,
    referenceDocname: j['reference_docname'] as String?,
    linkedLabel: j['linked_label'] as String?,
    dueLabel: j['due_label'] as String?,
    daysOverdue: (j['days_overdue'] as num?)?.toInt(),
  );
}

@immutable
class PlanLead {
  const PlanLead({
    required this.name,
    required this.leadName,
    required this.status,
    required this.creation,
    required this.daysSinceCreated,
    this.mobileNo,
    this.email,
    this.source,
  });

  final String name;
  final String leadName;
  final String status;
  final String? mobileNo;
  final String? email;
  final String? source;
  final DateTime creation;
  final int daysSinceCreated;

  factory PlanLead.fromJson(Map<String, dynamic> j) => PlanLead(
    name: j['name'].toString(),
    leadName: (j['lead_name'] ?? '').toString(),
    status: (j['status'] ?? 'New').toString(),
    mobileNo: j['mobile_no'] as String?,
    email: j['email'] as String?,
    source: j['source'] as String?,
    creation: _parseDate(j['creation']) ?? DateTime.now(),
    daysSinceCreated: (j['days_since_created'] as num?)?.toInt() ?? 0,
  );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

Map<String, dynamic> _asMap(dynamic e) => (e as Map).cast<String, dynamic>();
