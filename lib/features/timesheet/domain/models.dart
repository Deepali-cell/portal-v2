import 'package:flutter/foundation.dart';

@immutable
class TimesheetSummary {
  const TimesheetSummary({
    required this.name,
    required this.totalHours,
    required this.status,
    this.totalHoursDisplay,
    this.startDate,
    this.endDate,
    this.employee,
    this.employeeName,
  });

  final String name;
  final double totalHours;

  /// Server-formatted total, matching the ERPNext desk.
  final String? totalHoursDisplay;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;

  /// Owner - only sent by the All Timesheets roster (list_all), null on the
  /// personal My Timesheet view.
  final String? employee;
  final String? employeeName;

  factory TimesheetSummary.fromJson(Map<String, dynamic> j) => TimesheetSummary(
        name: j['name'] as String,
        totalHours: (j['total_hours'] as num?)?.toDouble() ?? 0,
        totalHoursDisplay: j['total_hours_display'] as String?,
        status: (j['status'] ?? '') as String,
        startDate: j['start_date'] != null
            ? DateTime.tryParse(j['start_date'].toString())
            : null,
        endDate: j['end_date'] != null
            ? DateTime.tryParse(j['end_date'].toString())
            : null,
        employee: j['employee'] as String?,
        employeeName: j['employee_name'] as String?,
      );
}

/// Response of `timesheet.list_all` - the All Timesheets roster window.
@immutable
class AllTimesheets {
  const AllTimesheets({
    required this.timesheets,
    required this.fromDate,
    required this.toDate,
  });

  final List<TimesheetSummary> timesheets;
  final DateTime fromDate;
  final DateTime toDate;

  factory AllTimesheets.fromJson(Map<String, dynamic> j) {
    final now = DateTime.now();
    return AllTimesheets(
      timesheets: ((j['timesheets'] as List?) ?? [])
          .map((e) => TimesheetSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      fromDate: j['from_date'] != null
          ? DateTime.tryParse(j['from_date'].toString()) ??
              DateTime(now.year, now.month, 1)
          : DateTime(now.year, now.month, 1),
      toDate: j['to_date'] != null
          ? DateTime.tryParse(j['to_date'].toString()) ?? now
          : now,
    );
  }
}

@immutable
class ProjectRef {
  const ProjectRef({required this.name, required this.label});
  final String name;
  final String label;
  factory ProjectRef.fromJson(Map<String, dynamic> j) => ProjectRef(
        name: j['name'] as String,
        label: (j['project_name'] ?? j['name']) as String,
      );
}

@immutable
class TimesheetContext {
  const TimesheetContext({
    required this.timesheets,
    required this.activityTypes,
    required this.projects,
    required this.fromDate,
    required this.toDate,
    this.activeTimer,
  });

  final List<TimesheetSummary> timesheets;
  final List<String> activityTypes;
  final List<ProjectRef> projects;
  final DateTime fromDate;
  final DateTime toDate;
  final ActiveTimer? activeTimer;

  double get totalHours =>
      timesheets.fold(0, (sum, t) => sum + t.totalHours);

  factory TimesheetContext.fromJson(Map<String, dynamic> j) {
    final now = DateTime.now();
    return TimesheetContext(
      timesheets: ((j['timesheets'] as List?) ?? [])
          .map((e) => TimesheetSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      activityTypes: ((j['activity_types'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      projects: ((j['projects'] as List?) ?? [])
          .map((e) => ProjectRef.fromJson(e as Map<String, dynamic>))
          .toList(),
      fromDate: j['from_date'] != null
          ? DateTime.tryParse(j['from_date'].toString()) ??
              DateTime(now.year, now.month, 1)
          : DateTime(now.year, now.month, 1),
      toDate: j['to_date'] != null
          ? DateTime.tryParse(j['to_date'].toString()) ?? now
          : now,
      activeTimer: j['active_timer'] is Map<String, dynamic>
          ? ActiveTimer.fromJson(j['active_timer'] as Map<String, dynamic>)
          : null,
    );
  }
}

@immutable
class TimesheetLogRow {
  const TimesheetLogRow({
    required this.fromTime,
    required this.hours,
    this.name,
    this.hoursDisplay,
    this.toTime,
    this.activityType,
    this.project,
    this.task,
    this.description,
    this.billable = false,
  });

  /// Child row id on the Timesheet. Needed to edit or delete this row.
  final String? name;
  final DateTime? fromTime;
  final DateTime? toTime;
  final double hours;

  /// Hours already formatted by the server the way the ERPNext desk shows
  /// them. Prefer this over formatting [hours] here, so the app and the desk
  /// never disagree.
  final String? hoursDisplay;
  final String? activityType;
  final String? project;
  final String? task;
  final String? description;
  final bool billable;

  /// A row with a start but no end is the timer that is still running.
  bool get isRunning => fromTime != null && toTime == null;

  factory TimesheetLogRow.fromJson(Map<String, dynamic> j) => TimesheetLogRow(
        name: j['name'] as String?,
        fromTime: j['from_time'] != null
            ? DateTime.tryParse(j['from_time'].toString())
            : null,
        toTime: j['to_time'] != null
            ? DateTime.tryParse(j['to_time'].toString())
            : null,
        hours: (j['hours'] as num?)?.toDouble() ?? 0,
        hoursDisplay: j['hours_display'] as String?,
        activityType: j['activity_type'] as String?,
        project: j['project'] as String?,
        task: j['task'] as String?,
        description: j['description'] as String?,
        billable: ((j['billable'] as num?)?.toInt() ?? 0) == 1,
      );
}

@immutable
class TimesheetDetail {
  const TimesheetDetail({
    required this.name,
    required this.totalHours,
    required this.status,
    required this.logs,
    required this.docstatus,
    required this.canSubmit,
    required this.hasActiveTimer,
    this.totalHoursDisplay,
    this.canEdit = false,
    this.startDate,
    this.endDate,
    this.note,
  });

  final String name;
  final double totalHours;

  /// Server-formatted total, matching the ERPNext desk. See
  /// [TimesheetLogRow.hoursDisplay].
  final String? totalHoursDisplay;
  final String status;
  final int docstatus;
  final List<TimesheetLogRow> logs;
  final bool canSubmit;

  /// True while the timesheet is a draft the caller may change. Gates the
  /// add / edit / delete affordances; the server re-checks on every write.
  final bool canEdit;
  final bool hasActiveTimer;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? note;

  bool get isDraft => docstatus == 0;

  factory TimesheetDetail.fromJson(Map<String, dynamic> j) => TimesheetDetail(
        name: j['name'] as String,
        totalHours: (j['total_hours'] as num?)?.toDouble() ?? 0,
        totalHoursDisplay: j['total_hours_display'] as String?,
        status: (j['status'] ?? '') as String,
        docstatus: (j['docstatus'] as num?)?.toInt() ?? 0,
        startDate: j['start_date'] != null
            ? DateTime.tryParse(j['start_date'].toString())
            : null,
        endDate: j['end_date'] != null
            ? DateTime.tryParse(j['end_date'].toString())
            : null,
        note: j['note'] as String?,
        logs: ((j['time_logs'] as List?) ?? [])
            .map((e) =>
                TimesheetLogRow.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        canSubmit: (j['can_submit'] ?? false) as bool,
        canEdit: (j['can_edit'] ?? false) as bool,
        hasActiveTimer: (j['has_active_timer'] ?? false) as bool,
      );
}

@immutable
class TaskRef {
  const TaskRef({required this.name, required this.subject, this.status});
  final String name;
  final String subject;
  final String? status;
  factory TaskRef.fromJson(Map<String, dynamic> j) => TaskRef(
        name: j['name'] as String,
        subject: (j['subject'] ?? j['name']) as String,
        status: j['status'] as String?,
      );
}

@immutable
class ActiveTimer {
  const ActiveTimer({
    required this.rowName,
    required this.timesheet,
    required this.activityType,
    required this.project,
    required this.task,
    required this.fromTime,
  });
  final String rowName;
  final String timesheet;
  final String activityType;
  final String project;
  final String task;
  final DateTime fromTime;

  Duration elapsedNow() => DateTime.now().difference(fromTime.toLocal());

  factory ActiveTimer.fromJson(Map<String, dynamic> j) => ActiveTimer(
        rowName: j['row_name'] as String,
        timesheet: j['timesheet'] as String,
        activityType: (j['activity_type'] ?? '') as String,
        project: (j['project'] ?? '') as String,
        task: (j['task'] ?? '') as String,
        fromTime: DateTime.parse(j['from_time'] as String),
      );
}

@immutable
class TimeLog {
  const TimeLog({
    required this.fromTime,
    required this.hours,
    this.activityType,
    this.project,
    this.task,
    this.description,
  });

  final DateTime fromTime;
  final double hours;
  final String? activityType;
  final String? project;
  final String? task;
  final String? description;

  Map<String, dynamic> toJson() => {
        'from_time': fromTime.toIso8601String().split('.').first,
        'hours': hours,
        if (activityType != null) 'activity_type': activityType,
        if (project != null) 'project': project,
        if (task != null) 'task': task,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };
}
