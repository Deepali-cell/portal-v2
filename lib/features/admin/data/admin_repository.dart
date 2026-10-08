import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class AdminRepository {
  AdminRepository(this._dio);
  final Dio _dio;

  Future<AdminMeta> getMeta() async {
    try {
      final resp = await _dio.get(ApiPaths.adminMeta);
      return AdminMeta.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Returns {doctype: PermFlags} for the given role at permlevel 0.
  Future<Map<String, PermFlags>> getMatrix(String role) async {
    try {
      final resp = await _dio.get(
        ApiPaths.adminRoleMatrix,
        queryParameters: {'role': role},
      );
      final map = (resp.data['message'] as Map).cast<String, dynamic>();
      return map.map(
        (dt, v) => MapEntry(
          dt,
          PermFlags.fromJson((v as Map).cast<String, dynamic>()),
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PermFlags> setPerm({
    required String role,
    required String doctype,
    required String ptype,
    required bool value,
  }) async {
    try {
      final resp = await _dio.post(
        ApiPaths.adminSetPerm,
        data: {
          'role': role,
          'doctype': doctype,
          'ptype': ptype,
          'value': value ? 1 : 0,
        },
      );
      return PermFlags.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // --- Reports: per-role access to the curated reports ---------------------

  /// Read-only health check of this site's set-up. System Manager only.
  Future<SetupCheck> getSetupCheck() async {
    try {
      final resp = await _dio.get(ApiPaths.adminSetupCheck);
      return SetupCheck.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Licence modules + switched-off screens. System Manager only.
  Future<ScreenConfig> getScreenConfig() async {
    try {
      final resp = await _dio.get(ApiPaths.adminScreenConfig);
      return ScreenConfig.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Replace the site's switched-off screen list.
  Future<void> setDisabledScreens(Set<String> screens) async {
    try {
      await _dio.post(
        ApiPaths.adminSetDisabledScreens,
        data: {'screens': jsonEncode(screens.toList())},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Current integration settings; secrets only as `<name>_set` flags.
  Future<Map<String, dynamic>> getIntegrations() async {
    try {
      final resp = await _dio.get(ApiPaths.adminIntegrations);
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Save one integration ('whatsapp' | 'ai') and test it. Empty secrets are
  /// left unchanged on the server.
  Future<IntegrationResult> saveIntegration(
    String name,
    Map<String, dynamic> values,
  ) => _result(ApiPaths.adminSaveIntegration, {
    'integration': name,
    'values': jsonEncode(values),
  });

  Future<IntegrationResult> testIntegration(String name) =>
      _result(ApiPaths.adminTestIntegration, {'integration': name});

  /// Upload the Firebase service-account JSON text, then test it.
  Future<IntegrationResult> uploadPushServiceAccount(String json) =>
      _result(ApiPaths.adminUploadPushAccount, {'content': json});

  Future<void> clearIntegration(String name) async {
    try {
      await _dio.post(
        ApiPaths.adminClearIntegration,
        data: {'integration': name},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<IntegrationResult> _result(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await _dio.post(path, data: data);
      final m = (resp.data['message'] as Map).cast<String, dynamic>();
      return IntegrationResult(
        ok: m['ok'] == true,
        message: (m['message'] ?? '').toString(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ReportAdminMeta> getReportMeta() async {
    try {
      final resp = await _dio.get(ApiPaths.adminReportMeta);
      return ReportAdminMeta.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ReportRolesState> getReportRoles(String reportKey) async {
    try {
      final resp = await _dio.get(
        ApiPaths.adminReportRoles,
        queryParameters: {'report_key': reportKey},
      );
      return ReportRolesState.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ReportRolesState> setReportRole({
    required String reportKey,
    required String role,
    required bool value,
  }) async {
    try {
      final resp = await _dio.post(
        ApiPaths.adminSetReportRole,
        data: {'report_key': reportKey, 'role': role, 'value': value ? 1 : 0},
      );
      return ReportRolesState.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
