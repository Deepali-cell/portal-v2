import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/storage/temp_file.dart';
import '../domain/models.dart';

class LeaveRepository {
  LeaveRepository(this._dio);
  final Dio _dio;

  Future<LeaveApplicationDetail> getApplicationDetail(String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.leaveApplicationDetail,
        queryParameters: {'name': name},
      );
      return LeaveApplicationDetail.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Every leave application overlapping [from]..[to] — all employees' for
  /// HR/admin, the caller's own otherwise. Powers the HR Leaves management
  /// screen. Separate from [getContext] so it never changes self-service.
  Future<List<LeaveApplication>> getAllApplications({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final resp = await _dio.get(
        ApiPaths.leaveAllApplications,
        queryParameters: {
          if (from != null) 'from_date': _ymd(from),
          if (to != null) 'to_date': _ymd(to),
        },
      );
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return ((msg['applications'] as List?) ?? [])
          .map(
            (e) =>
                LeaveApplication.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Every comp-off request overlapping [from]..[to] — all employees' for
  /// HR/admin, the caller's own otherwise. Powers the Leaves management screen's
  /// Compensatory tab so oversight sees all requests with their stage.
  Future<List<CompOffApplication>> getAllCompOff({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final resp = await _dio.get(
        ApiPaths.compOffAll,
        queryParameters: {
          if (from != null) 'from_date': _ymd(from),
          if (to != null) 'to_date': _ymd(to),
        },
      );
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return ((msg['requests'] as List?) ?? [])
          .map(
            (e) =>
                CompOffApplication.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Downloads one leave attachment through the authenticated API and writes it
  /// to a temp file, returning the local path. Private proof files can't be
  /// opened by URL in an external browser (no auth token → 403), so we fetch the
  /// bytes here and hand the caller a local copy to open/share.
  Future<String> downloadAttachment(String fileName) async {
    try {
      final resp = await _dio.post(
        ApiPaths.leaveDownloadAttachment,
        data: {'file': fileName},
      );
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      final name = (msg['filename'] as String?) ?? 'attachment';
      final bytes = base64Decode(msg['content'] as String);
      return await writeTempFile(name, bytes);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  Future<LeaveContext> getContext() async {
    try {
      final resp = await _dio.get(ApiPaths.leaveContext);
      return LeaveContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Submits a leave request. Throws [ApiException] (e.g. insufficient balance,
  /// overlapping leave) for the UI to surface.
  Future<void> apply(LeaveRequest req) async {
    try {
      await _dio.post(
        ApiPaths.leaveApply,
        data: {
          'leave_type': req.leaveType,
          'from_date': _ymd(req.fromDate),
          'to_date': _ymd(req.toDate),
          'half_day': req.halfDay ? 1 : 0,
          if (req.halfDay && req.halfDayDate != null)
            'half_day_date': _ymd(req.halfDayDate!),
          if (req.description != null && req.description!.isNotEmpty)
            'description': req.description,
        },
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Submits a Compensatory Leave Request — claims comp-off for a holiday /
  /// weekend the employee worked. HR approves on the desk; ERPNext then adds
  /// the days to the employee's leave allocation. Throws [ApiException] for
  /// the UI to surface (e.g. date wasn't a holiday, no comp leave type set up).
  Future<void> applyCompOff(CompOffRequest req) async {
    final payload = <String, dynamic>{
      'work_from_date': _ymd(req.workFromDate),
      'reason': req.reason,
    };
    if (req.workEndDate != null) {
      payload['work_end_date'] = _ymd(req.workEndDate!);
    }
    if (req.leaveType != null && req.leaveType!.isNotEmpty) {
      payload['leave_type'] = req.leaveType;
    }
    try {
      await _dio.post(ApiPaths.compOffApply, data: payload);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Leave requests waiting on the signed in user, as their team's manager or
  /// as HR. The server decides which rows belong to them.
  Future<List<PendingLeaveApproval>> getPendingApprovals() async {
    try {
      final resp = await _dio.get(ApiPaths.leavePendingApprovals);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return ((msg['applications'] as List?) ?? [])
          .map(
            (e) => PendingLeaveApproval.fromJson(
              (e as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Move one request along. [action] is Approve or Reject; a rejection needs
  /// a reason, which the server also enforces.
  Future<void> actOnApplication({
    required String name,
    required String action,
    String? reason,
  }) async {
    try {
      await _dio.post(
        ApiPaths.leaveActOnApplication,
        data: {
          'name': name,
          'action': action,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Comp-off requests waiting on the signed in user, as manager or as HR.
  /// The server decides which rows belong to them.
  Future<List<PendingCompOffApproval>> getCompOffPendingApprovals() async {
    try {
      final resp = await _dio.get(ApiPaths.compOffPendingApprovals);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return ((msg['requests'] as List?) ?? [])
          .map(
            (e) => PendingCompOffApproval.fromJson(
              (e as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Approve or reject one comp-off request. A rejection needs a reason.
  Future<void> actOnCompOff({
    required String name,
    required String action,
    String? reason,
  }) async {
    try {
      await _dio.post(
        ApiPaths.compOffActOnRequest,
        data: {
          'name': name,
          'action': action,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Lists the HR-configurable leave notice-period rules, plus the available
  /// leave types for the picker. HR/admin only (server-enforced).
  Future<({List<LeaveNoticeRule> rules, List<String> leaveTypes})>
  listNoticeRules() async {
    try {
      final resp = await _dio.get(ApiPaths.leaveNoticeRulesList);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      final rules = ((msg['rules'] as List?) ?? [])
          .map(
            (e) => LeaveNoticeRule.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
      final types = ((msg['leave_types'] as List?) ?? [])
          .map((e) => e.toString())
          .toList();
      return (rules: rules, leaveTypes: types);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Creates ([name] null) or updates one leave notice rule. HR/admin only.
  Future<void> saveNoticeRule({
    String? name,
    required String ruleName,
    required double maxLeaveDays,
    required int minNoticeDays,
    bool isActive = true,
    String? leaveType,
    String? company,
    String? description,
  }) async {
    try {
      await _dio.post(
        ApiPaths.leaveNoticeRuleSave,
        data: {
          if (name != null && name.isNotEmpty) 'name': name,
          'rule_name': ruleName,
          'max_leave_days': maxLeaveDays,
          'min_notice_days': minNoticeDays,
          'is_active': isActive ? 1 : 0,
          if (leaveType != null && leaveType.isNotEmpty)
            'leave_type': leaveType,
          if (company != null && company.isNotEmpty) 'company': company,
          if (description != null && description.isNotEmpty)
            'description': description,
        },
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Deletes one leave notice rule. HR/admin only.
  Future<void> deleteNoticeRule(String name) async {
    try {
      await _dio.post(ApiPaths.leaveNoticeRuleDelete, data: {'name': name});
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Submits a Work From Home request (Attendance Request, reason
  /// "Work From Home"). Throws [ApiException] for the UI to surface.
  Future<void> applyWfh(WfhRequest req) async {
    final payload = <String, dynamic>{
      'from_date': _ymd(req.fromDate),
      'half_day': req.halfDay ? 1 : 0,
    };
    if (req.toDate != null) payload['to_date'] = _ymd(req.toDate!);
    if (req.halfDay && req.halfDayDate != null) {
      payload['half_day_date'] = _ymd(req.halfDayDate!);
    }
    if (req.explanation != null && req.explanation!.isNotEmpty) {
      payload['explanation'] = req.explanation;
    }
    try {
      await _dio.post(ApiPaths.wfhApply, data: payload);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// The signed-in user's own WFH requests, most recent first.
  Future<List<WfhSummary>> getMyWfh() async {
    try {
      final resp = await _dio.get(ApiPaths.wfhMyRequests);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return ((msg['requests'] as List?) ?? [])
          .map((e) => WfhSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// WFH requests waiting on the signed in user, as manager or as HR.
  Future<List<PendingWfhApproval>> getWfhPendingApprovals() async {
    try {
      final resp = await _dio.get(ApiPaths.wfhPendingApprovals);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return ((msg['requests'] as List?) ?? [])
          .map(
            (e) =>
                PendingWfhApproval.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Approve or reject one WFH request. A rejection needs a reason.
  Future<void> actOnWfh({
    required String name,
    required String action,
    String? reason,
  }) async {
    try {
      await _dio.post(
        ApiPaths.wfhActOnRequest,
        data: {
          'name': name,
          'action': action,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  ApiException _asApiException(DioException e) => e.error is ApiException
      ? e.error as ApiException
      : ApiException.fromDio(e);
}
