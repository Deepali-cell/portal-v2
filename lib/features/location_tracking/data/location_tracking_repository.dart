import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../domain/models.dart';

class LocationTrackingRepository {
  LocationTrackingRepository(this._dio);
  final Dio _dio;

  Future<TrackingStatus> getStatus() async {
    final data = await _get(ApiPaths.locTrackingStatus);
    return TrackingStatus.fromJson(data);
  }

  Future<TrackingStatus> setEnabled(bool enabled) async {
    final data = await _post(
      ApiPaths.locSetTrackingEnabled,
      {'enabled': enabled ? 1 : 0},
    );
    return TrackingStatus.fromJson(data);
  }

  Future<Map<String, dynamic>> recordHeartbeat({
    required String reason,
    int? batteryLevel,
  }) async {
    return _post(ApiPaths.locRecordHeartbeat, {
      'reason': reason,
      if (batteryLevel != null) 'battery_level': batteryLevel,
    });
  }

  Future<Map<String, dynamic>> recordPing({
    required double latitude,
    required double longitude,
    double? accuracyM,
    double? speedMps,
    int? batteryLevel,
    DateTime? recordedAt,
    String source = 'auto',
  }) async {
    return _post(ApiPaths.locRecordPing, {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (speedMps != null) 'speed_mps': speedMps,
      if (batteryLevel != null) 'battery_level': batteryLevel,
      if (recordedAt != null) 'recorded_at': recordedAt.toIso8601String(),
      'source': source,
    });
  }

  Future<List<TeamLivePerson>> myTeamLive() async {
    final data = await _get(ApiPaths.locMyTeamLive);
    final list = (data['people'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => TeamLivePerson.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<PersonCurrent> personCurrent(String employee) async {
    final data = await _get(
      ApiPaths.locPersonCurrent,
      query: {'employee': employee},
    );
    return PersonCurrent.fromJson(data);
  }

  Future<PersonTrail> personTrail(
    String employee, {
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) async {
    final data = await _get(ApiPaths.locPersonTrail, query: {
      'employee': employee,
      if (from != null) 'from_ts': from.toIso8601String(),
      if (to != null) 'to_ts': to.toIso8601String(),
      'limit': limit,
    });
    return PersonTrail.fromJson(data);
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, dynamic>? query}) async {
    try {
      final resp = await _dio.get(path, queryParameters: query);
      final msg = resp.data['message'];
      if (msg is Map) return msg.cast<String, dynamic>();
      return <String, dynamic>{};
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final resp = await _dio.post(path, data: body);
      final msg = resp.data['message'];
      if (msg is Map) return msg.cast<String, dynamic>();
      return <String, dynamic>{};
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
}

final locationRepositoryProvider = Provider<LocationTrackingRepository>(
  (ref) => LocationTrackingRepository(ref.watch(dioProvider)),
);

/// Own tracking status. `autoDispose` so it refreshes when the Home screen
/// remounts (e.g. after granting a permission and coming back from Settings).
final trackingStatusProvider =
    FutureProvider.autoDispose<TrackingStatus>((ref) {
  return ref.read(locationRepositoryProvider).getStatus();
});

/// Manager's live team snapshot. Auto-refresh every 60 s while the map is open.
final teamLiveProvider =
    FutureProvider.autoDispose<List<TeamLivePerson>>((ref) {
  return ref.read(locationRepositoryProvider).myTeamLive();
});

final personCurrentProvider = FutureProvider.autoDispose
    .family<PersonCurrent, String>((ref, employee) {
  return ref.read(locationRepositoryProvider).personCurrent(employee);
});

final personTrailProvider =
    FutureProvider.autoDispose.family<PersonTrail, String>((ref, employee) {
  return ref.read(locationRepositoryProvider).personTrail(employee);
});
