import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

enum MarkStatus { synced, queued }

class MarkResult {
  const MarkResult.synced({
    required this.logType,
    required this.matchedLocation,
    required this.distanceM,
  }) : status = MarkStatus.synced;

  const MarkResult.queued({required this.logType})
      : status = MarkStatus.queued,
        matchedLocation = null,
        distanceM = null;

  final MarkStatus status;
  final LogType logType;
  final String? matchedLocation;
  final int? distanceM;
}

/// Attendance data access: context, geofenced check-in (location + selfie are
/// mandatory and posted atomically), and an offline queue (Hive) that drains
/// when connectivity returns. The server is the authority on both geofence and
/// the selfie-required rule for IN; queued items are re-validated on sync.
class AttendanceRepository {
  AttendanceRepository(this._dio, this._connectivity, this._queue);

  final Dio _dio;
  final Connectivity _connectivity;
  final Box _queue;

  static const String boxName = 'pending_checkins';

  Future<AttendanceContext> getContext() async {
    try {
      final resp = await _dio.get(ApiPaths.attendanceContext);
      return AttendanceContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
  }

  /// Marks attendance. Online → posts immediately (selfie inline as base64).
  /// Offline (or a network failure) → enqueues for later sync. A missing selfie
  /// on IN is a permanent rejection; never queued.
  ///
  /// When [offsite] is true, the geofence is skipped server-side and [reason]
  /// is mandatory (>= 4 chars). Used for WFH / client-site / field work.
  Future<MarkResult> mark({
    required double latitude,
    required double longitude,
    required LogType logType,
    String? selfiePath,
    bool offsite = false,
    String? reason,
  }) async {
    if (logType == LogType.inn && (selfiePath == null || selfiePath.isEmpty)) {
      throw const ApiException(
        ApiErrorKind.unknown,
        'A selfie is required to check in.',
      );
    }
    if (offsite && (reason == null || reason.trim().length < 4)) {
      throw const ApiException(
        ApiErrorKind.unknown,
        'Please tell us where you\'re working (at least 4 characters).',
      );
    }

    if (!await isOnline()) {
      await _enqueue(_pending(latitude, longitude, logType, selfiePath,
          offsite: offsite, reason: reason));
      return MarkResult.queued(logType: logType);
    }

    try {
      return await _postMark(
        latitude: latitude,
        longitude: longitude,
        logType: logType,
        selfiePath: selfiePath,
        offsite: offsite,
        reason: reason,
      );
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.network || e.kind == ApiErrorKind.timeout) {
        await _enqueue(_pending(latitude, longitude, logType, selfiePath,
            offsite: offsite, reason: reason));
        return MarkResult.queued(logType: logType);
      }
      rethrow;
    }
  }

  Future<MarkResult> _postMark({
    required double latitude,
    required double longitude,
    required LogType logType,
    String? selfiePath,
    DateTime? capturedAt,
    bool offsite = false,
    String? reason,
  }) async {
    String? selfieB64;
    if (selfiePath != null && selfiePath.isNotEmpty) {
      try {
        final bytes = await File(selfiePath).readAsBytes();
        selfieB64 = base64Encode(bytes);
      } on FileSystemException {
        throw const ApiException(
          ApiErrorKind.unknown,
          'Could not read the selfie file. Please retake.',
        );
      }
    }

    final payload = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'log_type': logType.api,
    };
    if (selfieB64 != null) payload['selfie'] = selfieB64;
    if (capturedAt != null) {
      payload['timestamp'] = capturedAt.toUtc().toIso8601String();
    }
    if (offsite) {
      payload['offsite'] = 1;
      payload['reason'] = reason!.trim();
    }

    try {
      final resp = await _dio.post(ApiPaths.attendanceMark, data: payload);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return MarkResult.synced(
        logType: LogTypeX.fromApi(msg['log_type'] as String?),
        matchedLocation: msg['matched_location'] as String?,
        distanceM: (msg['distance_m'] as num?)?.toInt(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  // ---- Offline queue ----

  List<PendingCheckin> pending() {
    return _queue.values
        .map((v) => PendingCheckin.fromJson(
            jsonDecode(v as String) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
  }

  int get pendingCount => _queue.length;

  Future<void> _enqueue(PendingCheckin p) =>
      _queue.put(p.id, jsonEncode(p.toJson()));

  /// Drains the queue when online. Returns the number successfully synced.
  /// Items rejected by the server (geofence, missing selfie) are dropped so the
  /// queue can't get stuck; transient failures are kept for the next attempt.
  Future<int> syncPending() async {
    if (_queue.isEmpty || !await isOnline()) return 0;

    var synced = 0;
    for (final p in pending()) {
      try {
        await _postMark(
          latitude: p.latitude,
          longitude: p.longitude,
          logType: p.logType,
          selfiePath: p.selfiePath,
          capturedAt: p.capturedAt,
          offsite: p.offsite,
          reason: p.offsiteReason,
        );
        await _queue.delete(p.id);
        synced++;
      } on ApiException catch (e) {
        if (e.kind == ApiErrorKind.network || e.kind == ApiErrorKind.timeout) {
          break;
        }
        await _queue.delete(p.id);
      }
    }
    return synced;
  }

  PendingCheckin _pending(
    double lat,
    double lon,
    LogType type,
    String? selfiePath, {
    bool offsite = false,
    String? reason,
  }) =>
      PendingCheckin(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        latitude: lat,
        longitude: lon,
        logType: type,
        capturedAt: DateTime.now(),
        selfiePath: selfiePath,
        offsite: offsite,
        offsiteReason: reason,
      );

  ApiException _asApiException(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
