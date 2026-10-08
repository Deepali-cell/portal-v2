import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class ReportsRepository {
  ReportsRepository(this._dio);
  final Dio _dio;

  /// Reports the current user may run, grouped by module. Pass [module] to
  /// fetch just one module's reports (Accounts/Sales/Purchase/Stock).
  Future<List<ReportModule>> listReports({String? module}) async {
    try {
      final resp = await _dio.get(
        ApiPaths.reportsList,
        queryParameters: {'module': ?module},
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) => ReportModule.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Run one allowlisted report. [filters] overrides the backend defaults.
  Future<ReportResult> runReport(
    String key, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      final resp = await _dio.post(
        ApiPaths.reportRun,
        data: {
          'key': key,
          if (filters != null && filters.isNotEmpty)
            'filters': jsonEncode(filters),
        },
      );
      return ReportResult.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
