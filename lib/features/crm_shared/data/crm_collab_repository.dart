import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/crm_ref.dart';
import '../domain/models.dart';

class CrmCollabRepository {
  CrmCollabRepository(this._dio);
  final Dio _dio;

  // ---- Notes ----
  Future<List<CrmNote>> listNotes(CrmRef ref) async =>
      _getList(ApiPaths.notesList, ref, CrmNote.fromJson);

  Future<void> createNote(CrmRef ref, {required String title, String? content}) =>
      _post(ApiPaths.noteCreate, {
        ...ref.bodyFields,
        'title': title,
        if (content != null && content.isNotEmpty) 'content': content,
      });

  Future<void> updateNote(String name, {String? title, String? content}) {
    final data = <String, dynamic>{'name': name};
    if (title != null) data['title'] = title;
    if (content != null) data['content'] = content;
    return _post(ApiPaths.noteUpdate, data);
  }

  Future<void> deleteNote(String name) =>
      _post(ApiPaths.noteDelete, {'name': name});

  // ---- WhatsApp conversation ----
  /// True when the server sends through the WhatsApp Business Cloud API;
  /// false means click-to-chat (open wa.me and just log the text).
  Future<bool> whatsAppCloudEnabled() async {
    try {
      final resp = await _dio.get(ApiPaths.whatsappMode);
      return (resp.data['message'] as Map?)?['mode'] == 'cloud';
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<List<WhatsAppMessage>> listWhatsApp(CrmRef ref) async =>
      _getList(ApiPaths.whatsappList, ref, WhatsAppMessage.fromJson);

  /// Send from the company WhatsApp number (cloud mode only).
  Future<void> sendWhatsApp(CrmRef ref, {required String message}) =>
      _post(ApiPaths.whatsappSend, {...ref.bodyFields, 'message': message});

  Future<void> logWhatsApp(CrmRef ref,
          {required String message, String? toNumber}) =>
      _post(ApiPaths.whatsappLog, {
        ...ref.bodyFields,
        'message': message,
        if (toNumber != null && toNumber.isNotEmpty) 'to_number': toNumber,
      });

  Future<void> deleteWhatsApp(String name) =>
      _post(ApiPaths.whatsappDelete, {'name': name});

  // ---- CRM Tasks (per lead/deal) ----
  Future<List<CrmTaskItem>> listTasks(CrmRef ref) async =>
      _getList(ApiPaths.crmTasksList, ref, CrmTaskItem.fromJson);

  Future<void> createTask(
    CrmRef ref, {
    required String title,
    String? description,
    String status = 'Todo',
    String priority = 'Medium',
    DateTime? dueDate,
    String? assignedTo,
  }) =>
      _post(ApiPaths.crmTaskCreate, {
        ...ref.bodyFields,
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'status': status,
        'priority': priority,
        if (dueDate != null)
          'due_date': dueDate.toIso8601String().split('.').first,
        if (assignedTo != null && assignedTo.isNotEmpty)
          'assigned_to': assignedTo,
      });

  Future<void> updateTask(
    String name, {
    String? title,
    String? description,
    String? status,
    String? priority,
    DateTime? dueDate,
    String? assignedTo,
  }) {
    final data = <String, dynamic>{'name': name};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (status != null) data['status'] = status;
    if (priority != null) data['priority'] = priority;
    if (dueDate != null) {
      data['due_date'] = dueDate.toIso8601String().split('.').first;
    }
    if (assignedTo != null) data['assigned_to'] = assignedTo;
    return _post(ApiPaths.crmTaskUpdate, data);
  }

  Future<void> deleteTask(String name) =>
      _post(ApiPaths.crmTaskDelete, {'name': name});

  // ---- Comments ----
  Future<List<CrmComment>> listComments(CrmRef ref) async =>
      _getList(ApiPaths.commentsList, ref, CrmComment.fromJson);

  Future<void> createComment(CrmRef ref, String content) =>
      _post(ApiPaths.commentCreate, {...ref.bodyFields, 'content': content});

  Future<void> deleteComment(String name) =>
      _post(ApiPaths.commentDelete, {'name': name});

  // ---- Attachments ----
  Future<List<CrmAttachment>> listAttachments(CrmRef ref) async =>
      _getList(ApiPaths.attachmentsList, ref, CrmAttachment.fromJson);

  Future<void> uploadAttachment(CrmRef ref, String filePath,
      {bool isPrivate = true}) async {
    try {
      final form = FormData.fromMap({
        'doctype': ref.doctype,
        'docname': ref.name,
        'is_private': isPrivate ? 1 : 0,
        'file': await MultipartFile.fromFile(filePath,
            filename: filePath.split('/').last),
      });
      await _dio.post(ApiPaths.uploadFile, data: form);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> deleteAttachment(String name) =>
      _post(ApiPaths.attachmentDelete, {'name': name});

  // ---- Assignees ----
  Future<List<CrmAssignee>> listAssignees(CrmRef ref) async =>
      _getList(ApiPaths.assigneesList, ref, CrmAssignee.fromJson);

  Future<void> addAssignee(CrmRef ref, String user, {String? description}) =>
      _post(ApiPaths.assigneeAdd, {
        ...ref.bodyFields,
        'user': user,
        if (description != null && description.isNotEmpty)
          'description': description,
      });

  Future<void> removeAssignee(CrmRef ref, String user) =>
      _post(ApiPaths.assigneeRemove, {...ref.bodyFields, 'user': user});

  Future<List<UserOption>> searchUsers(String query) async {
    try {
      final resp = await _dio
          .get(ApiPaths.userSearch, queryParameters: {'query': query, 'limit': 20});
      return ((resp.data['message'] as List?) ?? [])
          .map((e) => UserOption.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  // ---- Calls (CRM Call Log) ----
  Future<List<CrmCall>> listCalls(CrmRef ref) async =>
      _getList(ApiPaths.crmCallsList, ref, CrmCall.fromJson);

  Future<void> createCall(
    CrmRef ref, {
    required String fromNo,
    required String to,
    required String type,
    String status = 'Completed',
    DateTime? startTime,
    int? durationSeconds,
    String? medium,
    String? recordingUrl,
  }) {
    final data = <String, dynamic>{
      ...ref.bodyFields,
      'from_no': fromNo,
      'to': to,
      'type': type,
      'status': status,
    };
    if (startTime != null) {
      data['start_time'] = startTime.toIso8601String().split('.').first;
    }
    if (durationSeconds != null) data['duration'] = durationSeconds;
    if (medium != null && medium.isNotEmpty) data['medium'] = medium;
    if (recordingUrl != null && recordingUrl.isNotEmpty) {
      data['recording_url'] = recordingUrl;
    }
    return _post(ApiPaths.crmCallCreate, data);
  }

  Future<void> deleteCall(String name) =>
      _post(ApiPaths.crmCallDelete, {'name': name});

  // ---- Emails (Communication) ----
  Future<List<CrmEmail>> listEmails(CrmRef ref) async =>
      _getList(ApiPaths.emailsList, ref, CrmEmail.fromJson);

  Future<void> sendEmail(
    CrmRef ref, {
    required String subject,
    required String content,
    required String recipients,
    String? cc,
    String? bcc,
    bool meCopy = false,
  }) {
    final data = <String, dynamic>{
      ...ref.bodyFields,
      'subject': subject,
      'content': content,
      'recipients': recipients,
      'send_me_a_copy': meCopy ? 1 : 0,
    };
    if (cc != null && cc.isNotEmpty) data['cc'] = cc;
    if (bcc != null && bcc.isNotEmpty) data['bcc'] = bcc;
    return _post(ApiPaths.emailSend, data);
  }

  // ---- Events ----
  Future<List<CrmEvent>> listEvents(CrmRef ref) async =>
      _getList(ApiPaths.eventsList, ref, CrmEvent.fromJson);

  Future<void> createEvent(
    CrmRef ref, {
    required String subject,
    required DateTime startsOn,
    DateTime? endsOn,
    String eventCategory = 'Meeting',
    String? description,
    bool allDay = false,
  }) {
    final data = <String, dynamic>{
      ...ref.bodyFields,
      'subject': subject,
      'starts_on': startsOn.toIso8601String().split('.').first,
      'event_category': eventCategory,
      'all_day': allDay ? 1 : 0,
    };
    if (endsOn != null) {
      data['ends_on'] = endsOn.toIso8601String().split('.').first;
    }
    if (description != null && description.isNotEmpty) {
      data['description'] = description;
    }
    return _post(ApiPaths.eventCreate, data);
  }

  Future<void> updateEvent(
    String name, {
    String? subject,
    DateTime? startsOn,
    DateTime? endsOn,
    String? eventCategory,
    String? description,
    String? status,
    bool? allDay,
  }) {
    final data = <String, dynamic>{'name': name};
    if (subject != null) data['subject'] = subject;
    if (startsOn != null) {
      data['starts_on'] = startsOn.toIso8601String().split('.').first;
    }
    if (endsOn != null) {
      data['ends_on'] = endsOn.toIso8601String().split('.').first;
    }
    if (eventCategory != null) data['event_category'] = eventCategory;
    if (description != null) data['description'] = description;
    if (status != null) data['status'] = status;
    if (allDay != null) data['all_day'] = allDay ? 1 : 0;
    return _post(ApiPaths.eventUpdate, data);
  }

  Future<void> deleteEvent(String name) =>
      _post(ApiPaths.eventDelete, {'name': name});

  // ---- Activity timeline (aggregated) ----
  Future<List<TimelineEntry>> listTimeline(CrmRef ref) async {
    try {
      final resp =
          await _dio.get(ApiPaths.timelineGet, queryParameters: ref.queryParams);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return ((msg['activities'] as List?) ?? [])
          .map((e) => TimelineEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  // ---- helpers ----
  Future<List<T>> _getList<T>(
      String path, CrmRef ref, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final resp = await _dio.get(path, queryParameters: ref.queryParams);
      return ((resp.data['message'] as List?) ?? [])
          .map((e) => fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> _post(String path, Map<String, dynamic> data) async {
    try {
      await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  ApiException _err(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
