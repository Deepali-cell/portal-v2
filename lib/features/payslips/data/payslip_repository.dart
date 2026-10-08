import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/storage/temp_file.dart';
import '../domain/models.dart';

class PayslipRepository {
  PayslipRepository(this._dio);
  final Dio _dio;

  Future<PayslipContext> getList({DateTime? from, DateTime? to}) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    try {
      final resp = await _dio.get(
        ApiPaths.payslipList,
        queryParameters: {
          if (from != null) 'from_date': fmt(from),
          if (to != null) 'to_date': fmt(to),
        },
      );
      return PayslipContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Org-wide payslip list (Finance > All Payslips). `year` scopes the list;
  /// `month` (1-12) narrows to one month; `status` is "all" | "draft" |
  /// "submitted".
  Future<AllPayslipsContext> getAllList({
    required int year,
    int? month,
    String status = 'all',
  }) async {
    try {
      final resp = await _dio.get(
        ApiPaths.payslipAllList,
        queryParameters: {
          'year': year,
          'month': ?month,
          if (status != 'all') 'status': status,
        },
      );
      return AllPayslipsContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Downloads the PDF of `name` and writes it to a temp file. Returns the
  /// absolute file path so the caller can hand it off to share_plus / open.
  Future<String> downloadPdf(String name) async {
    try {
      final resp = await _dio.post(
        ApiPaths.payslipDownloadPdf,
        data: {'name': name},
      );
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      final fileName = (msg['filename'] as String?) ?? '$name.pdf';
      final b64 = msg['content'] as String;
      final bytes = base64Decode(b64);
      return await writeTempFile(fileName, bytes);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  Future<PayslipDetail> getDetail(String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.payslipDetail,
        queryParameters: {'name': name},
      );
      return PayslipDetail.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  ApiException _asApiException(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
