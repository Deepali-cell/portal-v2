import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class TeamStatusRepository {
  TeamStatusRepository(this._dio);
  final Dio _dio;

  Future<TeamStatusSnapshot> fetch() async {
    try {
      final resp = await _dio.get(ApiPaths.teamStatus);
      return TeamStatusSnapshot.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
}
