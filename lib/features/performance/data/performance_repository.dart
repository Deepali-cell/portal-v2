import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class PerformanceRepository {
  PerformanceRepository(this._dio);
  final Dio _dio;

  Future<PerformanceSnapshot> fetch({
    required String scope, // 'mine' | 'team'
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final resp = await _dio.get(ApiPaths.performance, queryParameters: {
        'scope': scope,
        'from_date': _fmt(from),
        'to_date': _fmt(to),
      });
      return PerformanceSnapshot.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, "0")}-'
      '${d.month.toString().padLeft(2, "0")}-'
      '${d.day.toString().padLeft(2, "0")}';
}
