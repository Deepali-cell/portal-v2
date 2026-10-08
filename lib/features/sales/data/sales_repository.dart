import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';

/// Sales-cycle conversion actions, backed by tcb_portal_erp.api.sales.
/// Everyday CRUD for Customer/Quotation/Sales Order/Delivery Note goes
/// through the generic RecordsRepository instead - this repository only
/// covers the step-to-step conversions that engine doesn't do.
class SalesRepository {
  SalesRepository(this._dio);
  final Dio _dio;

  Future<String> createSoFromQuotation(String quotation) async {
    final data = await _post(
        ApiPaths.salesCreateSoFromQuotation, {'quotation': quotation});
    return (data['name'] ?? '').toString();
  }

  Future<String> createDeliveryNoteFromSo(String salesOrder) async {
    final data = await _post(ApiPaths.salesCreateDeliveryNoteFromSo,
        {'sales_order': salesOrder});
    return (data['name'] ?? '').toString();
  }

  Future<String> createInvoiceFromSo(String salesOrder) async {
    final data = await _post(
        ApiPaths.salesCreateInvoiceFromSo, {'sales_order': salesOrder});
    return (data['name'] ?? '').toString();
  }

  Future<String> createInvoiceFromDeliveryNote(String deliveryNote) async {
    final data = await _post(ApiPaths.salesCreateInvoiceFromDeliveryNote,
        {'delivery_note': deliveryNote});
    return (data['name'] ?? '').toString();
  }

  Future<String> createSalesReturn(
    String deliveryNote, {
    List<Map<String, dynamic>>? items,
  }) async {
    final data = await _post(ApiPaths.salesCreateReturn, {
      'delivery_note': deliveryNote,
      if (items != null) 'items': jsonEncode(items),
    });
    return (data['name'] ?? '').toString();
  }

  Future<String> createPaymentEntryFromSo(String salesOrder) async {
    final data = await _post(ApiPaths.salesCreatePaymentEntryFromSo,
        {'sales_order': salesOrder});
    return (data['name'] ?? '').toString();
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

final salesRepositoryProvider =
    Provider<SalesRepository>((ref) => SalesRepository(ref.watch(dioProvider)));
