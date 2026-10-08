import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class DealRepository {
  DealRepository(this._dio);
  final Dio _dio;

  Future<DealsContext> getContext() async {
    try {
      final resp = await _dio.get(ApiPaths.dealsContext);
      return DealsContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<Deal> getDetail(String name) async {
    try {
      final resp =
          await _dio.get(ApiPaths.dealDetail, queryParameters: {'name': name});
      return Deal.fromJson((resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> update(String name, Map<String, dynamic> fields) async {
    try {
      await _dio.post(ApiPaths.dealUpdate, data: {'name': name, ...fields});
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  /// Convert this Opportunity to an ERPNext Customer (step 2 of
  /// Lead → Opportunity → Customer). Returns the new Customer's name.
  Future<String> convertToCustomer(String name) async {
    try {
      final resp = await _dio.post(ApiPaths.dealConvert, data: {'name': name});
      final m = resp.data['message'] as Map?;
      return (m?['customer'] ?? '') as String;
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  ApiException _err(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
