import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/storage/temp_file.dart';

/// Generate a UUID-ish v4 string for upload idempotency. The mobile
/// generates one BEFORE the multipart POST and the backend stores it
/// on Tcb Call Recording.client_upload_id. If Dio later throws (e.g.
/// Cloudflare's 100s tunnel timeout fires before the server response
/// reaches us), the client re-queries find_by_client_id(<uuid>) — if
/// the server saved the row, we treat the upload as successful and
/// suppress the "Couldn't upload" notification. No external `uuid`
/// dependency, just dart:math + dart:io seed.
String _newUploadId() {
  final r = Random.secure();
  String h(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-${h(4)}-${h(4)}-${h(12)}';
}

@immutable
class CallRecording {
  const CallRecording({
    required this.name,
    required this.status,
    this.phoneNumber,
    this.direction,
    this.durationSeconds,
    this.capturedAt,
    this.recordingFile,
    this.summary,
    this.sentiment,
    this.suggestedStatus,
    this.suggestedNextAction,
    this.suggestionAppliedAt,
    this.suggestionAppliedFromStatus,
    this.aiConfidence,
    this.aiProcessedAt,
    this.transcript,
    this.keyPoints = const [],
    this.errorMessage,
    this.callLog,
    this.referenceDoctype,
    this.referenceDocname,
    this.matchedDisplay,
  });

  final String name;
  final String status; // Uploaded / Transcribing / Summarizing / Ready / Failed
  final String? phoneNumber;
  final String? direction; // "Incoming" | "Outgoing" | null
  final int? durationSeconds;
  final DateTime? capturedAt;
  final String? recordingFile;
  final String? summary;
  final String? sentiment;
  final String? suggestedStatus;
  final String? suggestedNextAction;
  /// Set atomically inside apply_suggested_status when the user taps
  /// "Apply {status}". Null means the suggestion is still actionable.
  final DateTime? suggestionAppliedAt;
  /// Lead's status snapshotted at the moment the user applied the
  /// suggestion. Used to render "Applied: {from} → {suggested}" after
  /// the fact, without having to inspect the lead's version history.
  final String? suggestionAppliedFromStatus;
  final double? aiConfidence;
  final DateTime? aiProcessedAt;
  final String? transcript;
  final List<String> keyPoints;
  final String? errorMessage;
  final String? callLog;
  final String? referenceDoctype;
  final String? referenceDocname;
  final String? matchedDisplay;

  bool get isReady => status == 'Ready';
  bool get isFailed => status == 'Failed';

  factory CallRecording.fromJson(Map<String, dynamic> j) => CallRecording(
        name: (j['name'] ?? '').toString(),
        status: (j['status'] ?? 'Uploaded').toString(),
        phoneNumber: j['phone_number'] as String?,
        direction: j['direction'] as String?,
        durationSeconds: (j['duration_seconds'] as num?)?.toInt(),
        capturedAt: _date(j['captured_at']),
        recordingFile: j['recording_file'] as String?,
        summary: j['summary'] as String?,
        sentiment: j['sentiment'] as String?,
        suggestedStatus: j['suggested_status'] as String?,
        suggestedNextAction: j['suggested_next_action'] as String?,
        suggestionAppliedAt: _date(j['suggestion_applied_at']),
        suggestionAppliedFromStatus:
            j['suggestion_applied_from_status'] as String?,
        aiConfidence: (j['ai_confidence'] as num?)?.toDouble(),
        aiProcessedAt: _date(j['ai_processed_at']),
        transcript: j['transcript'] as String?,
        keyPoints: _strList(j['key_points_parsed'] ?? j['key_points']),
        errorMessage: j['error_message'] as String?,
        callLog: j['call_log'] as String?,
        referenceDoctype: j['reference_doctype'] as String?,
        referenceDocname: j['reference_docname'] as String?,
        matchedDisplay: j['matched_display'] as String?,
      );

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
  static List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }
}

class RecordingRepository {
  RecordingRepository(this._dio);
  final Dio _dio;

  /// Uploads the local MP3/M4A to the backend. Returns the new Tcb Call
  /// Recording name + initial status. The backend kicks off AI processing
  /// in a background worker; mobile polls [get] to see when it's Ready.
  Future<CallRecording> upload({
    required String localPath,
    String? callLog,
    String? referenceDoctype,
    String? referenceDocname,
    String? phoneNumber,
    int? durationSeconds,
    String? sourceFolder,
    String? direction, // "Incoming" | "Outgoing"
    DateTime? startTime,
    String? contactNameHint,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw const ApiException(
          ApiErrorKind.unknown, "Recording file disappeared before upload.");
    }
    final uploadId = _newUploadId();
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(localPath,
            filename: localPath.split('/').last),
        if (callLog != null) 'call_log': callLog,
        if (referenceDoctype != null) 'reference_doctype': referenceDoctype,
        if (referenceDocname != null) 'reference_docname': referenceDocname,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (durationSeconds != null)
          'duration_seconds': durationSeconds.toString(),
        if (sourceFolder != null) 'source_oem_folder': sourceFolder,
        if (direction != null) 'direction': direction,
        if (startTime != null) 'start_time': startTime.toIso8601String(),
        if (contactNameHint != null) 'contact_name_hint': contactNameHint,
        'client_upload_id': uploadId,
      });
      // Multipart MP3 uploads can take 30-60s on slow mobile networks —
      // override Dio's default timeouts so we don't fire a false-positive
      // "couldn't upload" notification when the server is just being slow.
      final resp = await _dio.post(
        ApiPaths.uploadRecording,
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return CallRecording.fromJson(msg);
    } on DioException catch (e) {
      // Cloudflare tunnels enforce a 100s edge timeout regardless of our
      // Dio settings. If the server already saved the row but Cloudflare
      // returned 524 before our response arrived, we'd otherwise post a
      // false-positive "Couldn't upload" notification. Verify via the
      // idempotency key before giving up.
      final recovered = await _confirmByUploadId(uploadId);
      if (recovered != null) return recovered;
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }

  /// Look up a recording the backend already saved under this client-side
  /// upload id. Polls a few times because the backend insert + commit
  /// might still be in flight when Dio throws. Returns null if the upload
  /// genuinely didn't reach the server.
  Future<CallRecording?> _confirmByUploadId(String uploadId) async {
    for (var i = 0; i < 6; i++) {
      try {
        final resp = await _dio.get(
          ApiPaths.findRecordingByClientId,
          queryParameters: {'client_upload_id': uploadId},
          options: Options(receiveTimeout: const Duration(seconds: 10)),
        );
        final msg = resp.data['message'];
        if (msg is Map && msg.isNotEmpty) {
          return CallRecording.fromJson(msg.cast<String, dynamic>());
        }
      } on DioException {
        // swallow — we're already in a retry loop
      }
      await Future.delayed(Duration(seconds: 2 + i));
    }
    return null;
  }

  /// Latest state of a single recording (used to poll until status==Ready).
  Future<CallRecording> get(String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.getRecording,
        queryParameters: {'name': name},
      );
      return CallRecording.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }

  /// All recordings linked to a given Lead/Deal.
  Future<List<CallRecording>> listFor({
    required String referenceDoctype,
    required String referenceDocname,
  }) async {
    try {
      final resp = await _dio.get(
        ApiPaths.listRecordingsFor,
        queryParameters: {
          'reference_doctype': referenceDoctype,
          'reference_docname': referenceDocname,
        },
      );
      final list = (resp.data['message'] as List).cast<dynamic>();
      return list
          .map((e) => CallRecording.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }

  /// Every recording the signed-in user can see (their own, or all when the
  /// user is an admin/HR), newest first. Powers the global "Recordings" screen.
  Future<List<CallRecording>> listMine({int limit = 100}) async {
    try {
      final resp = await _dio.get(
        ApiPaths.listMyRecordings,
        queryParameters: {'limit': limit},
      );
      final list = (resp.data['message'] as List).cast<dynamic>();
      return list
          .map((e) => CallRecording.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }

  /// Downloads a recording's audio through the authenticated API and writes it
  /// to a temp file, returning the local path to feed an audio player. Private
  /// recording files can't be streamed by URL (no auth token → 403), so we
  /// fetch the bytes and play the local copy.
  Future<String> downloadRecording(String name) async {
    try {
      final resp = await _dio.post(
        ApiPaths.downloadRecording,
        data: {'name': name},
      );
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      final filename = (msg['filename'] as String?) ?? '$name.mp3';
      final bytes = base64Decode(msg['content'] as String);
      return await writeTempFile(filename, bytes);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }

  /// One-tap "apply suggested status" — backend flips the linked Lead's status.
  Future<Map<String, dynamic>> applySuggestedStatus(
      String recordingName, {String? override}) async {
    try {
      final resp = await _dio.post(
        ApiPaths.applySuggestedStatus,
        data: {
          'recording_name': recordingName,
          if (override != null) 'override_status': override,
        },
      );
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
}
