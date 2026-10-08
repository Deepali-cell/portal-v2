import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../domain/module_flow.dart';

/// Fetches the Sales module flow (Customer → Quotation → Sales Order →
/// Delivery Note → Invoice) with live per-stage counts and values.
class SalesCycleRepository {
  SalesCycleRepository(this._dio);
  final Dio _dio;

  Future<ModuleFlow> fetch() async {
    try {
      final resp = await _dio.get(ApiPaths.salesCycle);
      return ModuleFlow.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
}

final salesCycleRepositoryProvider = Provider<SalesCycleRepository>(
  (ref) => SalesCycleRepository(ref.watch(dioProvider)),
);

final salesCycleProvider = FutureProvider.autoDispose<ModuleFlow>(
  (ref) => ref.read(salesCycleRepositoryProvider).fetch(),
);
