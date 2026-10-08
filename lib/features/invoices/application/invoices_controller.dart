import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/invoices_repository.dart';
import '../domain/models.dart';

final invoicesRepositoryProvider = Provider<InvoicesRepository>(
    (ref) => InvoicesRepository(ref.watch(dioProvider)));

final invoicesControllerProvider =
    AsyncNotifierProvider<InvoicesController, InvoicesContext>(
        InvoicesController.new);

class InvoicesController extends AsyncNotifier<InvoicesContext> {
  @override
  Future<InvoicesContext> build() =>
      ref.read(invoicesRepositoryProvider).getContext();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(invoicesRepositoryProvider).getContext());
  }

  Future<String> createSales({
    required String customer,
    required List<InvoiceDraftItem> items,
    required bool submit,
    DateTime? dueDate,
    DateTime? postingDate,
    String? remarks,
  }) async {
    final name = await ref
        .read(invoicesRepositoryProvider)
        .createSalesInvoice(
          customer: customer,
          items: items,
          submit: submit,
          dueDate: dueDate,
          postingDate: postingDate,
          remarks: remarks,
        );
    await reload();
    return name;
  }

  Future<String> createPurchase({
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
    final name = await ref
        .read(invoicesRepositoryProvider)
        .createPurchaseInvoice(
          supplier: supplier,
          items: items,
          submit: submit,
          dueDate: dueDate,
          postingDate: postingDate,
          remarks: remarks,
          billNo: billNo,
          billDate: billDate,
          supplierInvoicePath: supplierInvoicePath,
        );
    await reload();
    return name;
  }

  Future<void> submitInvoice(String name, InvoiceKind kind) async {
    await ref.read(invoicesRepositoryProvider).submit(name, kind);
    await reload();
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
    final name = await ref
        .read(invoicesRepositoryProvider)
        .recordPayment(
          invoiceKind: invoiceKind,
          invoiceName: invoiceName,
          paidAmount: paidAmount,
          modeOfPayment: modeOfPayment,
          postingDate: postingDate,
          referenceNo: referenceNo,
          referenceDate: referenceDate,
        );
    await reload();
    return name;
  }
}

/// On-demand invoice detail. Family key encodes both name and kind.
final invoiceDetailProvider =
    FutureProvider.family<InvoiceDetail, ({String name, InvoiceKind kind})>(
        (ref, key) => ref
            .read(invoicesRepositoryProvider)
            .getDetail(key.name, key.kind));

/// Enabled Modes of Payment for the Record-Payment sheet.
final modesOfPaymentProvider = FutureProvider<List<ModeOfPayment>>(
    (ref) => ref.read(invoicesRepositoryProvider).listModesOfPayment());

/// Payments tab list. AsyncNotifier so it carries the date filter.
final paymentsControllerProvider =
    AsyncNotifierProvider<PaymentsController, PaymentsContext>(
        PaymentsController.new);

class PaymentsController extends AsyncNotifier<PaymentsContext> {
  DateTime? _from;
  DateTime? _to;

  DateTime get from {
    final f = _from;
    if (f != null) return f;
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  DateTime get to => _to ?? DateTime.now();

  @override
  Future<PaymentsContext> build() =>
      ref.read(invoicesRepositoryProvider).listPayments(from: from, to: to);

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(invoicesRepositoryProvider).listPayments(from: from, to: to),
    );
  }

  Future<void> setRange(DateTime newFrom, DateTime newTo) async {
    _from = newFrom;
    _to = newTo;
    await reload();
  }
}
