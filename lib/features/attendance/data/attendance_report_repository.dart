import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../domain/attendance_report_models.dart';

/// Attendance calendar / history / HR-management data, backed by
/// tcb_portal_erp.api.attendance_report. The everyday clock-in/out flow stays
/// in AttendanceRepository - this only covers the read-back views + HR marking.
class AttendanceReportRepository {
  AttendanceReportRepository(this._dio);
  final Dio _dio;

  Future<AttendanceMonth> monthly(int year, int month, {String? employee}) async {
    final data = await _get(ApiPaths.attendanceMonthly, {
      'year': year,
      'month': month,
      if (employee != null) 'employee': employee,
    });
    return AttendanceMonth.fromJson(data);
  }

  Future<DayLogs> dayLogs(DateTime date, {String? employee}) async {
    final data = await _get(ApiPaths.attendanceDayLogs, {
      'date': _ymd(date),
      if (employee != null) 'employee': employee,
    });
    return DayLogs.fromJson(data);
  }

  Future<AttendanceRoster> roster(int year, int month, {String? search}) async {
    final data = await _get(ApiPaths.attendanceRoster, {
      'year': year,
      'month': month,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return AttendanceRoster.fromJson(data);
  }

  Future<PendingAttendance> pending(DateTime date) async {
    final data = await _get(ApiPaths.attendancePending, {'date': _ymd(date)});
    return PendingAttendance.fromJson(data);
  }

  /// Employees on approved leave on [date]. Raw rows: employee_name,
  /// leave_type, from_date, to_date, half_day, description.
  Future<List<Map<String, dynamic>>> onLeave(DateTime date) async {
    final data = await _get(ApiPaths.hrOnLeaveList, {'date': _ymd(date)});
    final rows = (data['leaves'] as List?) ?? const [];
    return rows.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<String> markStatus({
    required String employee,
    required DateTime date,
    required String status,
    String? halfDayStatus,
  }) async {
    final data = await _post(ApiPaths.attendanceMarkStatus, {
      'employee': employee,
      'date': _ymd(date),
      'status': status,
      if (halfDayStatus != null) 'half_day_status': halfDayStatus,
    });
    return (data['name'] ?? '').toString();
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _get(String path, Map<String, dynamic> query) async {
    try {
      final resp = await _dio.get(path, queryParameters: query);
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post(path, data: data);
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final attendanceReportRepositoryProvider = Provider<AttendanceReportRepository>(
  (ref) => AttendanceReportRepository(ref.watch(dioProvider)),
);

/// Family key for a month view: (year, month, employee) - null employee = self.
typedef MonthKey = ({int year, int month, String? employee});

final monthlyAttendanceProvider =
    FutureProvider.autoDispose.family<AttendanceMonth, MonthKey>((ref, key) {
  return ref
      .read(attendanceReportRepositoryProvider)
      .monthly(key.year, key.month, employee: key.employee);
});

typedef RosterKey = ({int year, int month, String? search});

final attendanceRosterProvider =
    FutureProvider.autoDispose.family<AttendanceRoster, RosterKey>((ref, key) {
  return ref
      .read(attendanceReportRepositoryProvider)
      .roster(key.year, key.month, search: key.search);
});

/// Employees whose attendance for [date] still needs HR to decide (no check-out
/// or no check-in and not on leave). Keyed by the date so switching days refetches.
final pendingAttendanceProvider =
    FutureProvider.autoDispose.family<PendingAttendance, DateTime>((ref, date) {
  return ref
      .read(attendanceReportRepositoryProvider)
      .pending(DateTime(date.year, date.month, date.day));
});

/// Employees on approved leave on [date] (HR dashboard "On Leave" screen).
final onLeaveListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, DateTime>((ref, date) {
  return ref
      .read(attendanceReportRepositoryProvider)
      .onLeave(DateTime(date.year, date.month, date.day));
});
