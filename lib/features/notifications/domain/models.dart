import 'package:flutter/foundation.dart';

@immutable
class NotificationItem {
  const NotificationItem({
    required this.name,
    required this.subject,
    required this.type,
    required this.read,
    required this.creation,
    this.documentType,
    this.documentName,
    this.fromUser,
    this.emailContent,
  });

  final String name;
  final String subject;
  final String type;
  final bool read;
  final DateTime creation;
  final String? documentType;
  final String? documentName;
  final String? fromUser;
  final String? emailContent;

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        name: j['name'] as String,
        subject: (j['subject'] ?? '') as String,
        type: (j['type'] ?? 'Alert') as String,
        read: (j['read'] as num?)?.toInt() == 1,
        creation: DateTime.parse(j['creation'] as String),
        documentType: j['document_type'] as String?,
        documentName: j['document_name'] as String?,
        fromUser: j['from_user'] as String?,
        emailContent: j['email_content'] as String?,
      );
}
