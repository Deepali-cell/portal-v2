import 'package:flutter/foundation.dart';

enum LogType { inn, out }

extension LogTypeX on LogType {
  /// Frappe value (`IN` / `OUT`).
  String get api => this == LogType.inn ? 'IN' : 'OUT';
  String get label => this == LogType.inn ? 'Check in' : 'Check out';

  static LogType fromApi(String? v) =>
      (v ?? '').toUpperCase() == 'OUT' ? LogType.out : LogType.inn;
}

@immutable
class OfficeLocation {
  const OfficeLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  final String name;
  final double latitude;
  final double longitude;
  final int radius; // metres

  factory OfficeLocation.fromJson(Map<String, dynamic> j) => OfficeLocation(
        name: (j['location_name'] ?? j['name']) as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        radius: (j['radius'] as num).toInt(),
      );
}

@immutable
class Checkin {
  const Checkin({
    required this.name,
    required this.logType,
    required this.time,
    this.latitude,
    this.longitude,
    this.isOffsite = false,
    this.offsiteReason,
  });

  final String name;
  final LogType logType;
  final DateTime time;
  final double? latitude;
  final double? longitude;
  final bool isOffsite;
  final String? offsiteReason;

  factory Checkin.fromJson(Map<String, dynamic> j) => Checkin(
        name: j['name'] as String,
        logType: LogTypeX.fromApi(j['log_type'] as String?),
        time: DateTime.parse(j['time'] as String),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        isOffsite: (j['custom_is_offsite'] as num?)?.toInt() == 1,
        offsiteReason: j['custom_offsite_reason'] as String?,
      );
}

@immutable
class AttendanceContext {
  const AttendanceContext({
    required this.employee,
    required this.employeeName,
    required this.suggestedLogType,
    required this.locations,
    required this.todaysLogs,
  });

  final String employee;
  final String employeeName;
  final LogType suggestedLogType;
  final List<OfficeLocation> locations;
  final List<Checkin> todaysLogs;

  factory AttendanceContext.fromJson(Map<String, dynamic> j) =>
      AttendanceContext(
        employee: j['employee'] as String,
        employeeName: (j['employee_name'] ?? '') as String,
        suggestedLogType: LogTypeX.fromApi(j['suggested_log_type'] as String?),
        locations: ((j['locations'] as List?) ?? [])
            .map((e) => OfficeLocation.fromJson(e as Map<String, dynamic>))
            .toList(),
        todaysLogs: ((j['todays_logs'] as List?) ?? [])
            .map((e) => Checkin.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A check-in captured on-device while offline, awaiting sync. JSON-serialised
/// into a Hive box. [selfiePath] is a local file path (uploaded on sync).
@immutable
class PendingCheckin {
  const PendingCheckin({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.logType,
    required this.capturedAt,
    this.selfiePath,
    this.lastError,
    this.offsite = false,
    this.offsiteReason,
  });

  final String id;
  final double latitude;
  final double longitude;
  final LogType logType;
  final DateTime capturedAt;
  final String? selfiePath;
  final String? lastError;
  final bool offsite;
  final String? offsiteReason;

  PendingCheckin copyWith({String? lastError}) => PendingCheckin(
        id: id,
        latitude: latitude,
        longitude: longitude,
        logType: logType,
        capturedAt: capturedAt,
        selfiePath: selfiePath,
        lastError: lastError ?? this.lastError,
        offsite: offsite,
        offsiteReason: offsiteReason,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'log_type': logType.api,
        'captured_at': capturedAt.toIso8601String(),
        'selfie_path': selfiePath,
        'last_error': lastError,
        'offsite': offsite,
        'offsite_reason': offsiteReason,
      };

  factory PendingCheckin.fromJson(Map<String, dynamic> j) => PendingCheckin(
        id: j['id'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        logType: LogTypeX.fromApi(j['log_type'] as String?),
        capturedAt: DateTime.parse(j['captured_at'] as String),
        selfiePath: j['selfie_path'] as String?,
        lastError: j['last_error'] as String?,
        offsite: (j['offsite'] as bool?) ?? false,
        offsiteReason: j['offsite_reason'] as String?,
      );
}
