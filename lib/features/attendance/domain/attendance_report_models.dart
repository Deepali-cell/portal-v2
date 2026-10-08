import 'package:flutter/foundation.dart';

/// One calendar day's attendance, as returned by
/// tcb_portal_erp.api.attendance_report.get_monthly.
@immutable
class AttendanceDay {
  const AttendanceDay({
    required this.date,
    required this.day,
    this.status,
    this.source,
    this.inTime,
    this.outTime,
    this.workingHours,
    this.leaveType,
    this.attendance,
    this.isFuture = false,
  });

  final DateTime date;
  final int day;

  /// Present / Absent / Half Day / On Leave / Work From Home / Holiday /
  /// Week Off, or null when nothing is recorded for the day.
  final String? status;

  /// Where [status] came from: 'attendance' (marked doc), 'holiday', or
  /// 'checkin' (derived from Employee Checkin logs).
  final String? source;

  final DateTime? inTime;
  final DateTime? outTime;
  final double? workingHours;
  final String? leaveType;

  /// Name of the underlying Attendance doc, if one is marked.
  final String? attendance;
  final bool isFuture;

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  factory AttendanceDay.fromJson(Map<String, dynamic> j) => AttendanceDay(
        date: DateTime.parse(j['date'] as String),
        day: (j['day'] as num).toInt(),
        status: j['status'] as String?,
        source: j['source'] as String?,
        inTime: _dt(j['in_time']),
        outTime: _dt(j['out_time']),
        workingHours: (j['working_hours'] as num?)?.toDouble(),
        leaveType: j['leave_type'] as String?,
        attendance: j['attendance'] as String?,
        isFuture: j['is_future'] == true,
      );
}

@immutable
class AttendanceMonth {
  const AttendanceMonth({
    required this.employee,
    required this.employeeName,
    required this.year,
    required this.month,
    required this.days,
  });

  final String employee;
  final String employeeName;
  final int year;
  final int month;
  final List<AttendanceDay> days;

  AttendanceDay? dayOf(int day) {
    for (final d in days) {
      if (d.day == day) return d;
    }
    return null;
  }

  factory AttendanceMonth.fromJson(Map<String, dynamic> j) => AttendanceMonth(
        employee: (j['employee'] ?? '') as String,
        employeeName: (j['employee_name'] ?? '') as String,
        year: (j['year'] as num).toInt(),
        month: (j['month'] as num).toInt(),
        days: ((j['days'] as List?) ?? const [])
            .map((e) => AttendanceDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A single raw Employee Checkin row for the day-detail sheet.
@immutable
class DayLog {
  const DayLog({
    required this.name,
    required this.logType,
    required this.time,
    this.isOffsite = false,
    this.offsiteReason,
  });

  final String name;
  final String logType; // 'IN' | 'OUT'
  final DateTime time;
  final bool isOffsite;
  final String? offsiteReason;

  factory DayLog.fromJson(Map<String, dynamic> j) => DayLog(
        name: (j['name'] ?? '') as String,
        logType: (j['log_type'] ?? '') as String,
        time: DateTime.parse(j['time'] as String),
        isOffsite: j['custom_is_offsite'] == 1 || j['custom_is_offsite'] == true,
        offsiteReason: j['custom_offsite_reason'] as String?,
      );
}

@immutable
class DayLogs {
  const DayLogs({
    required this.employee,
    required this.employeeName,
    required this.date,
    required this.logs,
  });

  final String employee;
  final String employeeName;
  final DateTime date;
  final List<DayLog> logs;

  factory DayLogs.fromJson(Map<String, dynamic> j) => DayLogs(
        employee: (j['employee'] ?? '') as String,
        employeeName: (j['employee_name'] ?? '') as String,
        date: DateTime.parse(j['date'] as String),
        logs: ((j['logs'] as List?) ?? const [])
            .map((e) => DayLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One employee row in the All-Attendance / HR roster with month status counts.
@immutable
class AttendanceEmployeeRow {
  const AttendanceEmployeeRow({
    required this.employee,
    required this.employeeName,
    this.department,
    this.designation,
    this.image,
    this.present = 0,
    this.absent = 0,
    this.halfDay = 0,
    this.onLeave = 0,
    this.workFromHome = 0,
  });

  final String employee;
  final String employeeName;
  final String? department;
  final String? designation;
  final String? image;
  final int present;
  final int absent;
  final int halfDay;
  final int onLeave;
  final int workFromHome;

  factory AttendanceEmployeeRow.fromJson(Map<String, dynamic> j) =>
      AttendanceEmployeeRow(
        employee: (j['employee'] ?? '') as String,
        employeeName: (j['employee_name'] ?? '') as String,
        department: j['department'] as String?,
        designation: j['designation'] as String?,
        image: j['image'] as String?,
        present: (j['present'] as num?)?.toInt() ?? 0,
        absent: (j['absent'] as num?)?.toInt() ?? 0,
        halfDay: (j['half_day'] as num?)?.toInt() ?? 0,
        onLeave: (j['on_leave'] as num?)?.toInt() ?? 0,
        workFromHome: (j['work_from_home'] as num?)?.toInt() ?? 0,
      );
}

/// One employee whose attendance for a day still needs a human decision, as
/// returned by tcb_portal_erp.api.attendance_report.get_pending_attendance.
@immutable
class PendingAttendanceRow {
  const PendingAttendanceRow({
    required this.employee,
    required this.employeeName,
    required this.reason,
    this.department,
    this.designation,
    this.image,
    this.firstIn,
    this.lastOut,
    this.hours = 0,
    this.checkinCount = 0,
  });

  final String employee;
  final String employeeName;

  /// 'No check-out' (checked in, never out) or 'No check-in' (never came,
  /// not on leave).
  final String reason;

  final String? department;
  final String? designation;
  final String? image;
  final DateTime? firstIn;
  final DateTime? lastOut;
  final double hours;
  final int checkinCount;

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  factory PendingAttendanceRow.fromJson(Map<String, dynamic> j) =>
      PendingAttendanceRow(
        employee: (j['employee'] ?? '') as String,
        employeeName: (j['employee_name'] ?? '') as String,
        reason: (j['reason'] ?? '') as String,
        department: j['department'] as String?,
        designation: j['designation'] as String?,
        image: j['image'] as String?,
        firstIn: _dt(j['first_in']),
        lastOut: _dt(j['last_out']),
        hours: (j['hours'] as num?)?.toDouble() ?? 0,
        checkinCount: (j['checkin_count'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class PendingAttendance {
  const PendingAttendance({required this.date, required this.rows});

  final DateTime date;
  final List<PendingAttendanceRow> rows;

  factory PendingAttendance.fromJson(Map<String, dynamic> j) => PendingAttendance(
        date: DateTime.parse(j['date'] as String),
        rows: ((j['pending'] as List?) ?? const [])
            .map((e) => PendingAttendanceRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

@immutable
class AttendanceRoster {
  const AttendanceRoster({
    required this.year,
    required this.month,
    required this.employees,
  });

  final int year;
  final int month;
  final List<AttendanceEmployeeRow> employees;

  factory AttendanceRoster.fromJson(Map<String, dynamic> j) => AttendanceRoster(
        year: (j['year'] as num).toInt(),
        month: (j['month'] as num).toInt(),
        employees: ((j['employees'] as List?) ?? const [])
            .map((e) => AttendanceEmployeeRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
