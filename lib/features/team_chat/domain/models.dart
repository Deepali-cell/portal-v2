import 'package:flutter/foundation.dart';

@immutable
class ChatChannel {
  const ChatChannel({
    required this.name,
    required this.channelType,
    required this.title,
    this.subtitle = '',
    this.memberCount = 0,
    this.lastMessage,
    this.lastAt,
  });

  final String name;
  final String channelType; // 'Direct' | 'Group'
  final String title;
  final String subtitle;
  final int memberCount;
  final String? lastMessage;
  final DateTime? lastAt;

  bool get isGroup => channelType == 'Group';

  factory ChatChannel.fromJson(Map<String, dynamic> j) => ChatChannel(
        name: (j['name'] ?? '').toString(),
        channelType: (j['channel_type'] ?? 'Direct').toString(),
        title: (j['title'] ?? '').toString(),
        subtitle: (j['subtitle'] ?? '').toString(),
        memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
        lastMessage: (j['last_message'] as String?)?.isNotEmpty == true
            ? j['last_message'] as String?
            : null,
        lastAt: DateTime.tryParse((j['last_at'] ?? '').toString()),
      );
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.name,
    required this.message,
    required this.owner,
    required this.ownerName,
    required this.mine,
    required this.creation,
  });

  final String name;
  final String message;
  final String owner;
  final String ownerName;
  final bool mine;
  final DateTime creation;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        name: (j['name'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
        owner: (j['owner'] ?? '').toString(),
        ownerName: (j['owner_name'] ?? j['owner'] ?? '').toString(),
        mine: j['mine'] == true || j['mine'] == 1,
        creation:
            DateTime.tryParse((j['creation'] ?? '').toString()) ?? DateTime.now(),
      );
}
