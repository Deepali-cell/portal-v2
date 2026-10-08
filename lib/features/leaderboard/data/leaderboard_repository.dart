import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class LeaderboardRepository {
  LeaderboardRepository(this._dio);
  final Dio _dio;
  static final _isoDate = DateFormat('yyyy-MM-dd');

  Future<LeaderboardSnapshot> fetch({
    required LeaderboardMetric metric,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final resp = await _dio.get(
        ApiPaths.leaderboard,
        queryParameters: {
          'metric': metric.backendValue,
          if (from != null) 'from_date': _isoDate.format(from),
          if (to != null) 'to_date': _isoDate.format(to),
        },
      );
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return LeaderboardSnapshot.fromJson(msg);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
}
