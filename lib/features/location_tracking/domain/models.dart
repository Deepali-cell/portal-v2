import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

enum LiveStatus { online, stale, offline, noPermission, locationOff, gpsUnavailable, networkError }

LiveStatus liveStatusFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'online':
      return LiveStatus.online;
    case 'stale':
      return LiveStatus.stale;
    case 'no_permission':
      return LiveStatus.noPermission;
    case 'location_off':
      return LiveStatus.locationOff;
    case 'gps_unavailable':
      return LiveStatus.gpsUnavailable;
    case 'network_error':
      return LiveStatus.networkError;
    default:
      return LiveStatus.offline;
  }
}

extension LiveStatusX on LiveStatus {
  /// User-visible label. Kept short so it fits in a pin/pill.
  String get label => switch (this) {
        LiveStatus.online => 'Online',
        LiveStatus.stale => 'Stale',
        LiveStatus.offline => 'Offline',
        LiveStatus.noPermission => 'Permission off',
        LiveStatus.locationOff => 'Location off',
        LiveStatus.gpsUnavailable => 'No GPS fix',
        LiveStatus.networkError => 'No network',
      };

  /// True if the tracked person's sharing needs their attention (they
  /// should fix something on their phone).
  bool get needsAttention =>
      this == LiveStatus.noPermission ||
      this == LiveStatus.locationOff ||
      this == LiveStatus.gpsUnavailable ||
      this == LiveStatus.networkError;
}

@immutable
class TrackingStatus {
  const TrackingStatus({
    required this.enabled,
    this.employee,
    this.sessionId,
    this.startedAt,
    this.lastPingAt,
  });
  final bool enabled;
  final String? employee;
  final String? sessionId;
  final DateTime? startedAt;
  final DateTime? lastPingAt;

  factory TrackingStatus.fromJson(Map<String, dynamic> j) => TrackingStatus(
        enabled: j['enabled'] == true,
        employee: j['employee'] as String?,
        sessionId: j['session_id'] as String?,
        startedAt: _dt(j['started_at']),
        lastPingAt: _dt(j['last_ping_at']),
      );
}

@immutable
class TeamLivePerson {
  const TeamLivePerson({
    required this.employee,
    required this.employeeName,
    required this.designation,
    required this.image,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.lastPingAt,
    required this.minutesAgo,
    required this.status,
    required this.trackingEnabled,
  });
  final String employee;
  final String employeeName;
  final String designation;
  final String image;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final DateTime? lastPingAt;
  final double? minutesAgo;
  final LiveStatus status;
  final bool trackingEnabled;

  bool get hasPosition => latitude != null && longitude != null;
  LatLng? get latLng => hasPosition ? LatLng(latitude!, longitude!) : null;

  factory TeamLivePerson.fromJson(Map<String, dynamic> j) => TeamLivePerson(
        employee: (j['employee'] ?? '').toString(),
        employeeName: (j['employee_name'] ?? '').toString(),
        designation: (j['designation'] ?? '').toString(),
        image: (j['image'] ?? '').toString(),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        accuracyM: (j['accuracy_m'] as num?)?.toDouble(),
        lastPingAt: _dt(j['last_ping_at']),
        minutesAgo: (j['minutes_ago'] as num?)?.toDouble(),
        status: liveStatusFromString(j['status'] as String?),
        trackingEnabled: j['tracking_enabled'] == true,
      );
}

@immutable
class PersonCurrent {
  const PersonCurrent({
    required this.employee,
    required this.employeeName,
    required this.designation,
    required this.image,
    required this.trackingEnabled,
    required this.sessionId,
    required this.status,
    required this.unavailableReason,
    required this.latest,
  });
  final String employee;
  final String employeeName;
  final String designation;
  final String image;
  final bool trackingEnabled;
  final String? sessionId;
  final LiveStatus status;
  final String? unavailableReason;
  final LatestPing? latest;

  factory PersonCurrent.fromJson(Map<String, dynamic> j) => PersonCurrent(
        employee: (j['employee'] ?? '').toString(),
        employeeName: (j['employee_name'] ?? '').toString(),
        designation: (j['designation'] ?? '').toString(),
        image: (j['image'] ?? '').toString(),
        trackingEnabled: j['tracking_enabled'] == true,
        sessionId: j['session_id'] as String?,
        status: liveStatusFromString(j['status'] as String?),
        unavailableReason: j['unavailable_reason'] as String?,
        latest: j['latest_ping'] is Map
            ? LatestPing.fromJson(
                (j['latest_ping'] as Map).cast<String, dynamic>())
            : null,
      );
}

@immutable
class LatestPing {
  const LatestPing({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.speedMps,
    required this.batteryLevel,
    required this.recordedAt,
    required this.minutesAgo,
  });
  final double latitude;
  final double longitude;
  final double accuracyM;
  final double speedMps;
  final int batteryLevel;
  final DateTime? recordedAt;
  final double? minutesAgo;

  LatLng get latLng => LatLng(latitude, longitude);

  factory LatestPing.fromJson(Map<String, dynamic> j) => LatestPing(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        accuracyM: (j['accuracy_m'] as num?)?.toDouble() ?? 0.0,
        speedMps: (j['speed_mps'] as num?)?.toDouble() ?? 0.0,
        batteryLevel: (j['battery_level'] as num?)?.toInt() ?? 0,
        recordedAt: _dt(j['recorded_at']),
        minutesAgo: (j['minutes_ago'] as num?)?.toDouble(),
      );
}

@immutable
class TrailPoint {
  const TrailPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracyM,
  });
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? accuracyM;

  LatLng get latLng => LatLng(latitude, longitude);

  factory TrailPoint.fromJson(Map<String, dynamic> j) => TrailPoint(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        accuracyM: (j['accuracy_m'] as num?)?.toDouble(),
        recordedAt: _dt(j['recorded_at']) ?? DateTime.now(),
      );
}

@immutable
class PersonTrail {
  const PersonTrail({
    required this.employee,
    required this.fromTs,
    required this.toTs,
    required this.points,
  });
  final String employee;
  final DateTime? fromTs;
  final DateTime? toTs;
  final List<TrailPoint> points;

  factory PersonTrail.fromJson(Map<String, dynamic> j) => PersonTrail(
        employee: (j['employee'] ?? '').toString(),
        fromTs: _dt(j['from_ts']),
        toTs: _dt(j['to_ts']),
        points: ((j['points'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => TrailPoint.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

DateTime? _dt(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}
