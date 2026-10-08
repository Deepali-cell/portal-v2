import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class TaskRepository {
  TaskRepository(this._dio);
  final Dio _dio;

  Future<TaskContext> getContext() async {
    try {
      final resp = await _dio.get(ApiPaths.taskContext);
      return TaskContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> create({
    required String subject,
    String? description,
    String? priority,
    DateTime? expEndDate,
    String? project,
  }) async {
    final data = <String, dynamic>{'subject': subject};
    if (description != null && description.isNotEmpty) {
      data['description'] = description;
    }
    if (priority != null) data['priority'] = priority;
    if (expEndDate != null) {
      data['exp_end_date'] = expEndDate.toIso8601String().split('.').first;
    }
    if (project != null) data['project'] = project;
    try {
      await _dio.post(ApiPaths.taskCreate, data: data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> setStatus(String name, String status) async {
    try {
      await _dio.post(ApiPaths.taskSetStatus,
          data: {'name': name, 'status': status});
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  /// All tasks under a Project (any status/assignee) - powers the Projects
  /// module's "Tasks" section on the project detail screen.
  Future<List<TaskItem>> listByProject(String project) async {
    try {
      final resp = await _dio.get(
        ApiPaths.taskListByProject,
        queryParameters: {'project': project},
      );
      final rows = (resp.data['message'] as List?) ?? [];
      return rows
          .map((e) => TaskItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> assign(String name, String user) async {
    try {
      await _dio.post(ApiPaths.taskAssign, data: {'name': name, 'user': user});
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> unassign(String name, String user) async {
    try {
      await _dio.post(ApiPaths.taskUnassign, data: {'name': name, 'user': user});
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<TaskDetail> getDetail(String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.taskDetail,
        queryParameters: {'name': name},
      );
      return TaskDetail.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> update({
    required String name,
    String? subject,
    String? description,
    String? priority,
    DateTime? expEndDate,
    bool clearExpEndDate = false,
    String? project,
    bool clearProject = false,
    String? status,
  }) async {
    final data = <String, dynamic>{'name': name};
    if (subject != null) data['subject'] = subject;
    if (description != null) data['description'] = description;
    if (priority != null) data['priority'] = priority;
    if (status != null) data['status'] = status;
    if (clearExpEndDate) {
      data['exp_end_date'] = '';
    } else if (expEndDate != null) {
      data['exp_end_date'] = expEndDate.toIso8601String().split('.').first;
    }
    if (clearProject) {
      data['project'] = '';
    } else if (project != null) {
      data['project'] = project;
    }
    try {
      await _dio.post(ApiPaths.taskUpdate, data: data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  ApiException _err(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
