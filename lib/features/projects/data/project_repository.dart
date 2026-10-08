import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';

/// One row of a Project's team ("Project User" child table).
class ProjectMember {
  const ProjectMember({required this.user, required this.fullName});
  final String user;
  final String fullName;

  factory ProjectMember.fromJson(Map<String, dynamic> j) => ProjectMember(
        user: (j['user'] ?? '') as String,
        fullName: (j['full_name'] ?? j['user'] ?? '') as String,
      );
}

/// Team-assignment endpoints for the Projects module. The Project doc itself
/// (fields, create, edit) goes through the generic `records/` repository -
/// this only covers the `users` child table, which Frappe's generic list
/// query can't select (see tcb_portal_erp/api/project.py).
class ProjectRepository {
  ProjectRepository(this._dio);
  final Dio _dio;

  Future<List<ProjectMember>> getTeam(String project) async {
    try {
      final resp = await _dio.get(
        ApiPaths.projectTeam,
        queryParameters: {'project': project},
      );
      final rows = (resp.data['message'] as List?) ?? const [];
      return rows
          .map((e) => ProjectMember.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> addMember(String project, String user) async {
    try {
      await _dio.post(ApiPaths.projectAddMember,
          data: {'project': project, 'user': user});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> removeMember(String project, String user) async {
    try {
      await _dio.post(ApiPaths.projectRemoveMember,
          data: {'project': project, 'user': user});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>(
    (ref) => ProjectRepository(ref.watch(dioProvider)));
