import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../domain/module_flow.dart';

/// Fetches the Purchase module flow (Material Request → RFQ → Supplier
/// Quotation → Purchase Order → Goods Receipt) with live per-stage counts and
/// values. Mirrors [SalesCycleRepository] for the Purchase module dashboard.
class PurchaseCycleRepository {
  PurchaseCycleRepository(this._dio);
  final Dio _dio;

  Future<ModuleFlow> fetch() async {
    try {
      final resp = await _dio.get(ApiPaths.purchaseCycle);
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

final purchaseCycleRepositoryProvider = Provider<PurchaseCycleRepository>(
  (ref) => PurchaseCycleRepository(ref.watch(dioProvider)),
);

final purchaseCycleProvider = FutureProvider.autoDispose<ModuleFlow>(
  (ref) => ref.read(purchaseCycleRepositoryProvider).fetch(),
);
