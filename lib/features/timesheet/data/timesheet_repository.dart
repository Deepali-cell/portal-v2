import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class TimesheetRepository {
  TimesheetRepository(this._dio);
  final Dio _dio;

  Future<TimesheetContext> getContext({DateTime? from, DateTime? to}) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    try {
      final resp = await _dio.get(
        ApiPaths.timesheetContext,
        queryParameters: {
          if (from != null) 'from_date': fmt(from),
          if (to != null) 'to_date': fmt(to),
        },
      );
      return TimesheetContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  /// All Timesheets roster: every permitted employee's timesheets in the
  /// window. Fails with a permission error for users without Timesheet read.
  Future<AllTimesheets> listAll({
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    try {
      final resp = await _dio.get(
        ApiPaths.timesheetListAll,
        queryParameters: {
          if (from != null) 'from_date': fmt(from),
          if (to != null) 'to_date': fmt(to),
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      return AllTimesheets.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> submitTimesheet(String name) async {
    try {
      await _dio.post(ApiPaths.timesheetSubmit, data: {'name': name});
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<TimesheetDetail> getDetail(String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.timesheetDetail,
        queryParameters: {'name': name},
      );
      return TimesheetDetail.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<ActiveTimer?> getActiveTimer() async {
    try {
      final resp = await _dio.get(ApiPaths.activeTimer);
      final msg = resp.data['message'];
      if (msg is Map) {
        return ActiveTimer.fromJson(msg.cast<String, dynamic>());
      }
      return null;
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<ActiveTimer> startTimer({
    required String activityType,
    required String project,
    required String task,
  }) async {
    try {
      final resp = await _dio.post(ApiPaths.timerStart, data: {
        'activity_type': activityType,
        'project': project,
        'task': task,
      });
      return ActiveTimer.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> stopTimer(String description) async {
    try {
      await _dio
          .post(ApiPaths.timerStop, data: {'description': description});
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<List<TaskRef>> getProjectTasks(String project, {String? query}) async {
    try {
      final resp = await _dio.get(ApiPaths.projectTasks, queryParameters: {
        'project': project,
        if (query != null && query.isNotEmpty) 'query': query,
      });
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) => TaskRef.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  /// Datetime in the shape Frappe parses without a timezone shift. The server
  /// stores naive local datetimes, so the offset and microseconds are dropped.
  static String _dt(DateTime d) =>
      d.toLocal().toIso8601String().split('.').first.replaceFirst('T', ' ');

  Future<void> addLog({
    String? timesheet,
    required String activityType,
    required DateTime fromTime,
    required DateTime toTime,
    required String project,
    required String task,
    required String description,
    required bool billable,
  }) async {
    try {
      await _dio.post(ApiPaths.timesheetAddLog, data: {
        // Omitted when null: the server reuses/creates the caller's open draft.
        if (timesheet != null && timesheet.isNotEmpty) 'timesheet': timesheet,
        'activity_type': activityType,
        'from_time': _dt(fromTime),
        'to_time': _dt(toTime),
        'project': project,
        'task': task,
        'description': description,
        'is_billable': billable ? 1 : 0,
      });
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> updateLog({
    required String timesheet,
    required String rowName,
    required String activityType,
    required DateTime fromTime,
    required DateTime toTime,
    required String project,
    required String task,
    required String description,
    required bool billable,
  }) async {
    try {
      await _dio.post(ApiPaths.timesheetUpdateLog, data: {
        'timesheet': timesheet,
        'row_name': rowName,
        'activity_type': activityType,
        'from_time': _dt(fromTime),
        'to_time': _dt(toTime),
        'project': project,
        'task': task,
        'description': description,
        'is_billable': billable ? 1 : 0,
      });
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> deleteLog({
    required String timesheet,
    required String rowName,
  }) async {
    try {
      await _dio.post(ApiPaths.timesheetDeleteLog, data: {
        'timesheet': timesheet,
        'row_name': rowName,
      });
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> create(List<TimeLog> logs, {String? note}) async {
    try {
      await _dio.post(ApiPaths.timesheetCreate, data: {
        'logs': jsonEncode(logs.map((e) => e.toJson()).toList()),
        if (note != null && note.isNotEmpty) 'note': note,
      });
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  ApiException _err(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
