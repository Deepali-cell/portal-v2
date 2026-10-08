import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class DirectoryRepository {
  DirectoryRepository(this._dio);
  final Dio _dio;

  Future<List<DirectoryEntry>> list({String? search}) async {
    try {
      final resp = await _dio.get(
        ApiPaths.directoryList,
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': 500,
        },
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) => DirectoryEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
}
