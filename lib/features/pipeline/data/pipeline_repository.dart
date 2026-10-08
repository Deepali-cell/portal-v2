import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class PipelineRepository {
  PipelineRepository(this._dio);
  final Dio _dio;

  Future<PipelineSnapshot> fetch({
    required PipelineKind kind,
    required PipelineScope scope,
    DateTime? from,
    DateTime? to,
  }) async {
    final path = kind == PipelineKind.leads
        ? ApiPaths.leadPipeline
        : ApiPaths.dealPipeline;
    final params = <String, dynamic>{
      'scope': scope.apiValue,
      if (from != null) 'from_date': _fmt(from),
      if (to != null) 'to_date': _fmt(to),
    };
    try {
      final resp = await _dio.get(path, queryParameters: params);
      return PipelineSnapshot.fromJson(
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
