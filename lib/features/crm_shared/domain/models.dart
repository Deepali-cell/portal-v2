import 'package:flutter/foundation.dart';

@immutable
class CrmNote {
  const CrmNote({
    required this.name,
    required this.title,
    required this.owner,
    required this.creation,
    this.content,
    this.modified,
  });

  final String name;
  final String title;
  final String? content;
  final String owner;
  final DateTime creation;
  final DateTime? modified;

  factory CrmNote.fromJson(Map<String, dynamic> j) => CrmNote(
        name: j['name'] as String,
        title: (j['title'] ?? '') as String,
        content: j['content'] as String?,
        owner: (j['owner'] ?? '') as String,
        creation: DateTime.parse(j['creation'] as String),
        modified: j['modified'] != null
            ? DateTime.tryParse(j['modified'].toString())
            : null,
      );
}

/// One WhatsApp message on a lead/deal: sent/received through the company
/// Business API, or a click-to-chat outreach the salesperson logged.
@immutable
class WhatsAppMessage {
  const WhatsAppMessage({
    required this.name,
    required this.message,
    required this.owner,
    required this.ownerName,
    required this.creation,
    this.toNumber,
    this.direction = 'Outgoing',
    this.sentVia,
    this.status,
    this.error,
  });

  final String name;
  final String message;
  final String owner;
  final String ownerName;
  final DateTime creation;
  final String? toNumber;
  final String direction; // 'Outgoing' | 'Incoming'
  final String? sentVia; // 'Click to chat' | 'WhatsApp API' | ...
  final String? status; // Sent | Delivered | Read | Failed | Received

  /// Why WhatsApp rejected the message, when [status] is Failed.
  final String? error;

  bool get isOutgoing => direction != 'Incoming';

  /// Logged-only rows from click-to-chat; only these may be deleted.
  bool get isClickToChat => sentVia == null || sentVia == 'Click to chat';

  factory WhatsAppMessage.fromJson(Map<String, dynamic> j) => WhatsAppMessage(
        name: j['name'] as String,
        message: (j['message'] ?? '') as String,
        owner: (j['owner'] ?? '') as String,
        ownerName: (j['owner_name'] ?? j['owner'] ?? '') as String,
        creation: DateTime.parse(j['creation'] as String),
        toNumber: j['to_number'] as String?,
        direction: (j['direction'] ?? 'Outgoing') as String,
        sentVia: j['sent_via'] as String?,
        status: j['status'] as String?,
        error: j['error'] as String?,
      );
}

enum CrmTaskStatus { backlog, todo, inProgress, done, canceled }

extension CrmTaskStatusX on CrmTaskStatus {
  String get api {
    switch (this) {
      case CrmTaskStatus.backlog:
        return 'Backlog';
      case CrmTaskStatus.todo:
        return 'Todo';
      case CrmTaskStatus.inProgress:
        return 'In Progress';
      case CrmTaskStatus.done:
        return 'Done';
      case CrmTaskStatus.canceled:
        return 'Canceled';
    }
  }

  static CrmTaskStatus fromApi(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'done':
        return CrmTaskStatus.done;
      case 'canceled':
      case 'cancelled':
        return CrmTaskStatus.canceled;
      case 'in progress':
        return CrmTaskStatus.inProgress;
      case 'backlog':
        return CrmTaskStatus.backlog;
      default:
        return CrmTaskStatus.todo;
    }
  }
}

const List<String> kCrmTaskStatuses = ['Backlog', 'Todo', 'In Progress', 'Done', 'Canceled'];
const List<String> kCrmTaskPriorities = ['Low', 'Medium', 'High'];

@immutable
class CrmTaskItem {
  const CrmTaskItem({
    required this.name,
    required this.title,
    required this.status,
    required this.priority,
    this.description,
    this.startDate,
    this.dueDate,
    this.assignedTo,
  });

  final String name;
  final String title;
  final CrmTaskStatus status;
  final String priority; // Low/Medium/High
  final String? description;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String? assignedTo;

  bool get isDone => status == CrmTaskStatus.done;

  factory CrmTaskItem.fromJson(Map<String, dynamic> j) => CrmTaskItem(
        name: j['name'].toString(),
        title: (j['title'] ?? '') as String,
        status: CrmTaskStatusX.fromApi(j['status'] as String?),
        priority: (j['priority'] ?? 'Medium') as String,
        description: j['description'] as String?,
        startDate: j['start_date'] != null
            ? DateTime.tryParse(j['start_date'].toString())
            : null,
        dueDate: j['due_date'] != null
            ? DateTime.tryParse(j['due_date'].toString())
            : null,
        assignedTo: j['assigned_to'] as String?,
      );
}

@immutable
class CrmComment {
  const CrmComment({
    required this.name,
    required this.content,
    required this.owner,
    required this.creation,
    this.commentEmail,
  });
  final String name;
  final String content;
  final String owner;
  final DateTime creation;
  final String? commentEmail;

  factory CrmComment.fromJson(Map<String, dynamic> j) => CrmComment(
        name: j['name'] as String,
        content: (j['content'] ?? '') as String,
        owner: (j['owner'] ?? '') as String,
        creation: DateTime.parse(j['creation'] as String),
        commentEmail: j['comment_email'] as String?,
      );
}

@immutable
class CrmAttachment {
  const CrmAttachment({
    required this.name,
    required this.fileName,
    required this.fileUrl,
    required this.absoluteUrl,
    required this.owner,
    required this.creation,
    this.fileSize = 0,
    this.isPrivate = false,
  });
  final String name;
  final String fileName;
  final String fileUrl;
  final String absoluteUrl;
  final int fileSize;
  final bool isPrivate;
  final String owner;
  final DateTime creation;

  factory CrmAttachment.fromJson(Map<String, dynamic> j) => CrmAttachment(
        name: j['name'] as String,
        fileName: (j['file_name'] ?? '') as String,
        fileUrl: (j['file_url'] ?? '') as String,
        absoluteUrl: (j['absolute_url'] ?? j['file_url'] ?? '') as String,
        fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
        isPrivate: (j['is_private'] as num?)?.toInt() == 1,
        owner: (j['owner'] ?? '') as String,
        creation: DateTime.parse(j['creation'] as String),
      );
}

@immutable
class CrmAssignee {
  const CrmAssignee({required this.user, required this.fullName});
  final String user;
  final String fullName;
  factory CrmAssignee.fromJson(Map<String, dynamic> j) => CrmAssignee(
        user: (j['user'] ?? '') as String,
        fullName: (j['full_name'] ?? j['user'] ?? '') as String,
      );
}

@immutable
class UserOption {
  const UserOption({required this.name, required this.fullName});
  final String name;
  final String fullName;
  factory UserOption.fromJson(Map<String, dynamic> j) => UserOption(
        name: (j['name'] ?? '') as String,
        fullName: (j['full_name'] ?? j['name'] ?? '') as String,
      );
}

enum CallDirection { incoming, outgoing }

CallDirection callDirFrom(String? s) =>
    (s ?? '').toLowerCase() == 'incoming' ? CallDirection.incoming : CallDirection.outgoing;

@immutable
class CrmCall {
  const CrmCall({
    required this.name,
    required this.fromNo,
    required this.to,
    required this.type,
    required this.status,
    required this.creation,
    this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.medium,
    this.recordingUrl,
    this.caller,
    this.receiver,
    this.summary,
  });

  final String name;
  final String fromNo;
  final String to;
  final CallDirection type;
  final String status;
  final DateTime creation;
  final DateTime? startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final String? medium;
  final String? recordingUrl;
  final String? caller;
  final String? receiver;

  /// Outcome summary captured via log_outcome (joined from the linked FCRM
  /// Note). Null when the call has no summary note.
  final String? summary;

  factory CrmCall.fromJson(Map<String, dynamic> j) => CrmCall(
        name: j['name'] as String,
        fromNo: (j['from'] ?? '') as String,
        to: (j['to'] ?? '') as String,
        type: callDirFrom(j['type'] as String?),
        status: (j['status'] ?? '') as String,
        creation: DateTime.parse(j['creation'] as String),
        startTime: j['start_time'] != null
            ? DateTime.tryParse(j['start_time'].toString())
            : null,
        endTime: j['end_time'] != null
            ? DateTime.tryParse(j['end_time'].toString())
            : null,
        durationSeconds: (j['duration'] as num?)?.toInt() ?? 0,
        medium: j['medium'] as String?,
        recordingUrl: j['recording_url'] as String?,
        caller: j['caller'] as String?,
        receiver: j['receiver'] as String?,
        summary: (j['summary'] as String?)?.trim().isEmpty ?? true
            ? null
            : (j['summary'] as String).trim(),
      );
}

@immutable
class CrmEmail {
  const CrmEmail({
    required this.name,
    required this.subject,
    required this.sender,
    required this.creation,
    required this.sentOrReceived,
    this.content,
    this.senderFullName,
    this.recipients,
    this.cc,
    this.bcc,
    this.status,
    this.deliveryStatus,
  });

  final String name;
  final String subject;
  final String? content; // HTML
  final String sender;
  final String? senderFullName;
  final String? recipients;
  final String? cc;
  final String? bcc;
  final String sentOrReceived; // "Sent" / "Received"
  final DateTime creation;
  final String? status;
  final String? deliveryStatus;

  bool get sent => sentOrReceived.toLowerCase() == 'sent';

  factory CrmEmail.fromJson(Map<String, dynamic> j) => CrmEmail(
        name: j['name'] as String,
        subject: (j['subject'] ?? '(no subject)') as String,
        content: j['content'] as String?,
        sender: (j['sender'] ?? '') as String,
        senderFullName: j['sender_full_name'] as String?,
        recipients: j['recipients'] as String?,
        cc: j['cc'] as String?,
        bcc: j['bcc'] as String?,
        sentOrReceived: (j['sent_or_received'] ?? 'Sent') as String,
        creation: DateTime.parse(j['creation'] as String),
        status: j['status'] as String?,
        deliveryStatus: j['delivery_status'] as String?,
      );
}

/// One entry on a CRM Lead / Deal timeline. Shape varies wildly by
/// `activityType`, so we keep the full `raw` payload for the widget to read.
@immutable
class TimelineEntry {
  const TimelineEntry({
    required this.name,
    required this.activityType,
    required this.creation,
    required this.owner,
    required this.raw,
  });

  final String name;
  final String activityType;
  final DateTime creation;
  final String owner;
  final Map<String, dynamic> raw;

  String? get contentRaw => raw['content'] as String?;
  String? get subjectRaw => raw['subject'] as String?;
  dynamic get dataRaw => raw['data'];

  factory TimelineEntry.fromJson(Map<String, dynamic> j) => TimelineEntry(
        name: (j['name'] ?? '').toString(),
        activityType: (j['activity_type'] ?? 'unknown') as String,
        creation: DateTime.parse(j['creation'] as String),
        owner: (j['owner'] ?? '') as String,
        raw: j,
      );
}

@immutable
class CrmEvent {
  const CrmEvent({
    required this.name,
    required this.subject,
    required this.startsOn,
    required this.status,
    this.eventCategory,
    this.endsOn,
    this.allDay = false,
    this.description,
    this.owner,
  });

  final String name;
  final String subject;
  final DateTime startsOn;
  final DateTime? endsOn;
  final bool allDay;
  final String? eventCategory;
  final String status;
  final String? description;
  final String? owner;

  factory CrmEvent.fromJson(Map<String, dynamic> j) => CrmEvent(
        name: j['name'] as String,
        subject: (j['subject'] ?? '') as String,
        startsOn: DateTime.parse(j['starts_on'] as String),
        endsOn: j['ends_on'] != null
            ? DateTime.tryParse(j['ends_on'].toString())
            : null,
        allDay: (j['all_day'] as num?)?.toInt() == 1,
        eventCategory: j['event_category'] as String?,
        status: (j['status'] ?? 'Open') as String,
        description: j['description'] as String?,
        owner: j['owner'] as String?,
      );
}
