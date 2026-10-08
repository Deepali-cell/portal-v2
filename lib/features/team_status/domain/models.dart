import 'package:flutter/foundation.dart';

enum Presence { online, idle, offline }

extension PresenceX on Presence {
  String get label => switch (this) {
        Presence.online => 'Online',
        Presence.idle => 'Idle',
        Presence.offline => 'Offline',
      };
}

@immutable
class TeamMemberStatus {
  const TeamMemberStatus({
    required this.user,
    required this.fullName,
    required this.roleLabel,
    required this.presence,
    required this.lastActiveLabel,
    required this.callsToday,
    required this.outcomesToday,
    required this.leadsOwned,
    this.image,
  });

  final String user;
  final String fullName;
  final String roleLabel;
  final Presence presence;
  final String lastActiveLabel;
  final int callsToday;
  final int outcomesToday;
  final int leadsOwned;
  final String? image;

  factory TeamMemberStatus.fromJson(Map<String, dynamic> j) =>
      TeamMemberStatus(
        user: (j['user'] ?? '').toString(),
        fullName: (j['full_name'] ?? '').toString(),
        roleLabel: (j['role_label'] ?? 'Sales').toString(),
        presence: _parsePresence(j['presence'] as String?),
        lastActiveLabel: (j['last_active_label'] ?? '-').toString(),
        callsToday: (j['calls_today'] as num?)?.toInt() ?? 0,
        outcomesToday: (j['outcomes_today'] as num?)?.toInt() ?? 0,
        leadsOwned: (j['leads_owned'] as num?)?.toInt() ?? 0,
        image: j['image'] as String?,
      );

  String get initials {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

Presence _parsePresence(String? s) {
  switch (s) {
    case 'online':
      return Presence.online;
    case 'idle':
      return Presence.idle;
    default:
      return Presence.offline;
  }
}

@immutable
class TeamStatusSnapshot {
  const TeamStatusSnapshot({required this.users, required this.asOf});
  final List<TeamMemberStatus> users;
  final DateTime? asOf;

  factory TeamStatusSnapshot.fromJson(Map<String, dynamic> j) =>
      TeamStatusSnapshot(
        users: ((j['users'] as List?) ?? [])
            .map((e) => TeamMemberStatus.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList(),
        asOf: _parseDate(j['as_of']),
      );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}
