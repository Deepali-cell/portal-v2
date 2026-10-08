import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/storage/temp_file.dart';
import '../domain/models.dart';

class ExpenseRepository {
  ExpenseRepository(this._dio);
  final Dio _dio;

  Future<ExpenseContext> getContext({DateTime? from, DateTime? to}) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    try {
      final resp = await _dio.get(
        ApiPaths.expenseContext,
        queryParameters: {
          if (from != null) 'from_date': fmt(from),
          if (to != null) 'to_date': fmt(to),
        },
      );
      return ExpenseContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Creates a draft expense claim and returns its name (needed to attach
  /// receipts to it afterwards). Throws [ApiException] on rejection.
  Future<String> apply(List<ExpenseItem> items, {String? remark}) async {
    try {
      final resp = await _dio.post(
        ApiPaths.expenseApply,
        data: {
          'items': jsonEncode(items.map((e) => e.toJson()).toList()),
          if (remark != null && remark.isNotEmpty) 'remark': remark,
        },
      );
      return (resp.data['message'] as Map)['name'] as String;
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Attaches one proof/receipt file to a draft claim. The file is stored
  /// private and linked to the claim, so it shows in the ERP's attachments.
  Future<void> addAttachment(String claim, String filePath) async {
    try {
      final form = FormData.fromMap({
        'claim': claim,
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
      });
      await _dio.post(ApiPaths.expenseAddAttachment, data: form);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Expense claims waiting on the signed in user, as approver or as HR.
  Future<List<PendingExpenseApproval>> getPendingApprovals() async {
    try {
      final resp = await _dio.get(ApiPaths.expensePendingApprovals);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return ((msg['claims'] as List?) ?? [])
          .map(
            (e) => PendingExpenseApproval.fromJson(
              (e as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// All expense claims in a window for HR/admin (own claims for others).
  /// Powers the HR module's Expense Claims screen; distinct from [getContext].
  Future<List<ExpenseClaim>> getAllClaims({
    DateTime? from,
    DateTime? to,
  }) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    try {
      final resp = await _dio.get(
        ApiPaths.expenseAllClaims,
        queryParameters: {
          if (from != null) 'from_date': fmt(from),
          if (to != null) 'to_date': fmt(to),
        },
      );
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return ((msg['claims'] as List?) ?? [])
          .map((e) => ExpenseClaim.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Full detail of one claim (with line items), for the owner or an approver.
  Future<ExpenseClaimDetail> getClaimDetail(String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.expenseClaimDetail,
        queryParameters: {'name': name},
      );
      return ExpenseClaimDetail.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Downloads one claim attachment through the authenticated API and writes it
  /// to a temp file, returning the local path. Private receipt files can't be
  /// opened by URL in an external browser (no auth token → 403), so we fetch
  /// the bytes here and hand the caller a local copy to open/share.
  Future<String> downloadAttachment(String fileName) async {
    try {
      final resp = await _dio.post(
        ApiPaths.expenseDownloadAttachment,
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

  /// Approve or reject one claim. A rejection needs a reason, which the server
  /// also enforces.
  Future<void> actOnClaim({
    required String name,
    required String action,
    String? reason,
  }) async {
    try {
      await _dio.post(
        ApiPaths.expenseActOnClaim,
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

  ApiException _asApiException(DioException e) => e.error is ApiException
      ? e.error as ApiException
      : ApiException.fromDio(e);
}
