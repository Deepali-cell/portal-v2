import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';

/// Manufacturing-cycle conversion actions, backed by
/// tcb_portal_erp.api.manufacturing. Everyday CRUD for BOM / Work Order /
/// Job Card / Stock Entry goes through the generic RecordsRepository - this
/// repository only covers the step-to-step conversions that engine doesn't do.
class ManufacturingRepository {
  ManufacturingRepository(this._dio);
  final Dio _dio;

  Future<String> createWorkOrderFromBom(String bom, {double qty = 1}) async {
    final data = await _post(
        ApiPaths.mfgCreateWorkOrderFromBom, {'bom': bom, 'qty': qty});
    return (data['name'] ?? '').toString();
  }

  /// `purpose` is "Material Transfer for Manufacture" or "Manufacture".
  Future<String> createStockEntryFromWorkOrder(
    String workOrder, {
    required String purpose,
  }) async {
    final data = await _post(ApiPaths.mfgCreateStockEntryFromWorkOrder,
        {'work_order': workOrder, 'purpose': purpose});
    return (data['name'] ?? '').toString();
  }

  /// Raw-material availability for a submitted Work Order. Returns
  /// `all_available` plus a per-item list (required/available/shortage), so the
  /// UI can warn before a Material Transfer and offer a Material Request.
  Future<Map<String, dynamic>> workOrderStockStatus(String workOrder) async {
    return _post(ApiPaths.mfgWorkOrderStockStatus, {'work_order': workOrder});
  }

  /// Create a draft Material Request (Material Transfer) for the Work Order's
  /// raw-material shortfall.
  Future<String> createMaterialRequestFromWorkOrder(String workOrder) async {
    final data = await _post(
        ApiPaths.mfgCreateMaterialRequestFromWorkOrder,
        {'work_order': workOrder});
    return (data['name'] ?? '').toString();
  }

  /// Submit a Work Order. ERPNext auto-creates its Job Cards on submit, so this
  /// is the "release to production" step. Returns the resulting Job Cards.
  Future<List<Map<String, dynamic>>> submitWorkOrder(String workOrder) async {
    final data =
        await _post(ApiPaths.mfgSubmitWorkOrder, {'work_order': workOrder});
    return ((data['job_cards'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  /// Job Cards for the shop floor. `mine: true` returns only cards assigned to
  /// the current user; pass a `workOrder` to scope to one Work Order.
  Future<List<Map<String, dynamic>>> listJobCards(
      {bool mine = true, String? workOrder}) async {
    try {
      final resp = await _dio.get(ApiPaths.jobCardList, queryParameters: {
        'mine': mine ? 1 : 0,
        if (workOrder != null) 'work_order': workOrder,
      });
      return ((resp.data['message'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> jobCardDetail(String name) async {
    try {
      final resp =
          await _dio.get(ApiPaths.jobCardDetail, queryParameters: {'name': name});
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> startJobCard(String name) =>
      _post(ApiPaths.jobCardStart, {'name': name});

  Future<Map<String, dynamic>> completeJobCard(String name, {double? qty}) =>
      _post(ApiPaths.jobCardComplete, {'name': name, if (qty != null) 'qty': qty});

  /// Read-only counters + recent Work Orders for the Manufacturing dashboard.
  Future<Map<String, dynamic>> dashboard() async {
    try {
      final resp = await _dio.get(ApiPaths.manufacturingDashboard);
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post(path, data: data);
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final manufacturingRepositoryProvider = Provider<ManufacturingRepository>(
    (ref) => ManufacturingRepository(ref.watch(dioProvider)));
