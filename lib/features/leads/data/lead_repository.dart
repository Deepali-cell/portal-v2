import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class LeadRepository {
  LeadRepository(this._dio);
  final Dio _dio;

  Future<LeadsContext> getContext() async {
    try {
      final resp = await _dio.get(ApiPaths.leadsContext);
      return LeadsContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<Lead> getDetail(String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.leadDetail,
        queryParameters: {'name': name},
      );
      return Lead.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> create(Map<String, dynamic> fields) async {
    try {
      await _dio.post(ApiPaths.leadCreate, data: fields);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> update(String name, Map<String, dynamic> fields) async {
    try {
      await _dio.post(ApiPaths.leadUpdate, data: {'name': name, ...fields});
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  /// Convert this lead to an ERPNext Opportunity (step 1 of
  /// Lead → Opportunity → Customer). Returns the new Opportunity's name.
  Future<String> convertToOpportunity(String name) async {
    try {
      final resp = await _dio.post(ApiPaths.leadConvert, data: {'name': name});
      final m = resp.data['message'] as Map?;
      return (m?['opportunity'] ?? m?['deal'] ?? '') as String;
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  /// Backwards-compat alias — older code paths still call convertToDeal.
  Future<String> convertToDeal(String name) => convertToOpportunity(name);

  ApiException _err(DioException e) => e.error is ApiException
      ? e.error as ApiException
      : ApiException.fromDio(e);
}
