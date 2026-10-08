import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../domain/models.dart';

/// Purchase-cycle conversion actions + quotation comparison, backed by
/// tcb_portal_erp.api.purchase. Everyday CRUD for Supplier/RFQ/Supplier
/// Quotation/Purchase Order/Purchase Receipt goes through the generic
/// RecordsRepository instead - this repository only covers the
/// step-to-step conversions that engine doesn't do.
class PurchaseRepository {
  PurchaseRepository(this._dio);
  final Dio _dio;

  Future<String> createRfqFromMaterialRequest(
    String materialRequest,
    List<String> suppliers, {
    String? messageForSupplier,
  }) async {
    final data = await _post(ApiPaths.purchaseCreateRfqFromMr, {
      'material_request': materialRequest,
      'suppliers': jsonEncode(suppliers),
      if (messageForSupplier != null) 'message_for_supplier': messageForSupplier,
    });
    return (data['name'] ?? '').toString();
  }

  Future<List<Map<String, dynamic>>> rfqsForMaterialRequest(
      String materialRequest) async {
    try {
      final resp = await _dio.get(
        ApiPaths.purchaseRfqsForMr,
        queryParameters: {'material_request': materialRequest},
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> rfqSuppliers(
      String requestForQuotation) async {
    return _getList(ApiPaths.purchaseRfqSuppliers,
        {'request_for_quotation': requestForQuotation});
  }

  Future<List<Map<String, dynamic>>> receiptItems(String purchaseReceipt) async {
    return _getList(
        ApiPaths.purchaseReceiptItems, {'purchase_receipt': purchaseReceipt});
  }

  Future<String> createSupplierQuotationFromRfq(
    String requestForQuotation,
    String supplier,
  ) async {
    final data = await _post(ApiPaths.purchaseCreateSqFromRfq, {
      'request_for_quotation': requestForQuotation,
      'supplier': supplier,
    });
    return (data['name'] ?? '').toString();
  }

  Future<QuotationComparison> compareQuotations(
      String requestForQuotation) async {
    final data = await _get(ApiPaths.purchaseCompareQuotations,
        {'request_for_quotation': requestForQuotation});
    return QuotationComparison.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> posForSupplierQuotation(
      String supplierQuotation) async {
    return _getList(ApiPaths.purchasePosForSq,
        {'supplier_quotation': supplierQuotation});
  }

  Future<String> createPoFromSupplierQuotation(String supplierQuotation) async {
    final data = await _post(ApiPaths.purchaseCreatePoFromSq,
        {'supplier_quotation': supplierQuotation});
    return (data['name'] ?? '').toString();
  }

  Future<String> createReceiptFromPo(String purchaseOrder) async {
    final data = await _post(
        ApiPaths.purchaseCreateReceiptFromPo, {'purchase_order': purchaseOrder});
    return (data['name'] ?? '').toString();
  }

  Future<String> createInvoiceFromPo(String purchaseOrder) async {
    final data = await _post(ApiPaths.purchaseCreateInvoiceFromPo,
        {'purchase_order': purchaseOrder});
    return (data['name'] ?? '').toString();
  }

  Future<String> createInvoiceFromReceipt(String purchaseReceipt) async {
    final data = await _post(ApiPaths.purchaseCreateInvoiceFromReceipt,
        {'purchase_receipt': purchaseReceipt});
    return (data['name'] ?? '').toString();
  }

  Future<String> createPurchaseReturn(
    String purchaseReceipt,
    List<Map<String, dynamic>> items, {
    bool returnAgainstRejected = false,
  }) async {
    final data = await _post(ApiPaths.purchaseCreateReturn, {
      'purchase_receipt': purchaseReceipt,
      'items': jsonEncode(items),
      'return_against_rejected': returnAgainstRejected ? 1 : 0,
    });
    return (data['name'] ?? '').toString();
  }

  Future<List<Map<String, dynamic>>> _getList(
      String path, Map<String, dynamic> query) async {
    try {
      final resp = await _dio.get(path, queryParameters: query);
      final list = (resp.data['message'] as List?) ?? const [];
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> _get(
      String path, Map<String, dynamic> query) async {
    try {
      final resp = await _dio.get(path, queryParameters: query);
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

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
    (ref) => PurchaseRepository(ref.watch(dioProvider)));
