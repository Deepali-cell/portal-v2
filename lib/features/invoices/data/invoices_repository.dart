import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class InvoicesRepository {
  InvoicesRepository(this._dio);
  final Dio _dio;

  Future<InvoicesContext> getContext() async {
    try {
      final resp = await _dio.get(ApiPaths.invoicesContext);
      return InvoicesContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<List<PartyRef>> searchCustomers(String query) async {
    try {
      final resp = await _dio.get(
        ApiPaths.customerSearch,
        queryParameters: {'query': query, 'limit': 20},
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) => PartyRef.fromCustomerJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<List<PartyRef>> searchSuppliers(String query) async {
    try {
      final resp = await _dio.get(
        ApiPaths.supplierSearch,
        queryParameters: {'query': query, 'limit': 20},
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) => PartyRef.fromSupplierJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  /// kind = 'sales' or 'purchase' — filters Item by is_sales_item / is_purchase_item.
  Future<List<ItemRef>> searchItems(String query, {required String kind}) async {
    try {
      final resp = await _dio.get(
        ApiPaths.itemSearch,
        queryParameters: {'query': query, 'kind': kind, 'limit': 20},
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) => ItemRef.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<String> createSalesInvoice({
    required String customer,
    required List<InvoiceDraftItem> items,
    required bool submit,
    DateTime? dueDate,
    DateTime? postingDate,
    String? remarks,
  }) async {
    try {
      final resp = await _dio.post(ApiPaths.salesInvoiceCreate, data: {
        'customer': customer,
        'items': jsonEncode(items.map((i) => i.toJson()).toList()),
        'submit': submit ? 1 : 0,
        if (dueDate != null) 'due_date': _d(dueDate),
        if (postingDate != null) 'posting_date': _d(postingDate),
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      });
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return msg['name'] as String;
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<String> createPurchaseInvoice({
    required String supplier,
    required List<InvoiceDraftItem> items,
    required bool submit,
    DateTime? dueDate,
    DateTime? postingDate,
    String? remarks,
    String? billNo,
    DateTime? billDate,
    String? supplierInvoicePath,
  }) async {
    String? fileB64;
    String? fileName;
    if (supplierInvoicePath != null && supplierInvoicePath.isNotEmpty) {
      final bytes = await File(supplierInvoicePath).readAsBytes();
      fileB64 = base64Encode(bytes);
      fileName = supplierInvoicePath.split('/').last;
    }
    final payload = <String, dynamic>{
      'supplier': supplier,
      'items': jsonEncode(items.map((i) => i.toJson()).toList()),
      'submit': submit ? 1 : 0,
    };
    if (dueDate != null) payload['due_date'] = _d(dueDate);
    if (postingDate != null) payload['posting_date'] = _d(postingDate);
    if (remarks != null && remarks.isNotEmpty) payload['remarks'] = remarks;
    if (billNo != null && billNo.isNotEmpty) payload['bill_no'] = billNo;
    if (billDate != null) payload['bill_date'] = _d(billDate);
    if (fileB64 != null) payload['supplier_invoice_file'] = fileB64;
    if (fileName != null) payload['supplier_invoice_filename'] = fileName;

    try {
      final resp = await _dio.post(ApiPaths.purchaseInvoiceCreate, data: payload);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return msg['name'] as String;
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<InvoiceDetail> getDetail(String name, InvoiceKind kind) async {
    try {
      final resp = await _dio.get(
        ApiPaths.invoiceDetail,
        queryParameters: {
          'name': name,
          'kind': kind == InvoiceKind.sales ? 'sales' : 'purchase',
        },
      );
      return InvoiceDetail.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> submit(String name, InvoiceKind kind) async {
    try {
      await _dio.post(ApiPaths.invoiceSubmit, data: {
        'name': name,
        'kind': kind == InvoiceKind.sales ? 'sales' : 'purchase',
      });
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<List<ModeOfPayment>> listModesOfPayment() async {
    try {
      final resp = await _dio.get(ApiPaths.modesOfPayment);
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) =>
              ModeOfPayment.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<String> recordPayment({
    required InvoiceKind invoiceKind,
    required String invoiceName,
    required double paidAmount,
    String? modeOfPayment,
    DateTime? postingDate,
    String? referenceNo,
    DateTime? referenceDate,
  }) async {
    final payload = <String, dynamic>{
      'invoice_kind':
          invoiceKind == InvoiceKind.sales ? 'sales' : 'purchase',
      'invoice_name': invoiceName,
      'paid_amount': paidAmount,
      'submit': 1,
    };
    if (modeOfPayment != null) payload['mode_of_payment'] = modeOfPayment;
    if (postingDate != null) payload['posting_date'] = _d(postingDate);
    if (referenceNo != null && referenceNo.isNotEmpty) {
      payload['reference_no'] = referenceNo;
    }
    if (referenceDate != null) payload['reference_date'] = _d(referenceDate);

    try {
      final resp = await _dio.post(ApiPaths.recordPayment, data: payload);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return msg['payment_entry'] as String;
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<PaymentsContext> listPayments({DateTime? from, DateTime? to}) async {
    try {
      final resp = await _dio.get(ApiPaths.paymentsList, queryParameters: {
        if (from != null) 'from_date': _d(from),
        if (to != null) 'to_date': _d(to),
      });
      return PaymentsContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  ApiException _err(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
