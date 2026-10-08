import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class TodaysPlanRepository {
  TodaysPlanRepository(this._dio);
  final Dio _dio;

  Future<TodaysPlan> fetch() async {
    try {
      final resp = await _dio.get(ApiPaths.todaysPlan);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return TodaysPlan.fromJson(msg);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
}
