import 'package:flutter/foundation.dart';

enum InvoiceKind { sales, purchase }

@immutable
class Invoice {
  const Invoice({
    required this.name,
    required this.kind,
    required this.party,
    required this.partyDisplay,
    required this.postingDate,
    required this.grandTotal,
    required this.outstanding,
    required this.currency,
    required this.status,
    required this.docstatus,
    this.dueDate,
  });

  final String name;
  final InvoiceKind kind;
  final String party;
  final String partyDisplay;
  final DateTime postingDate;
  final DateTime? dueDate;
  final double grandTotal;
  final double outstanding;
  final String currency;
  final String status;
  final int docstatus;

  bool get isDraft => docstatus == 0;
  bool get isSubmitted => docstatus == 1;
  bool get isPaid => status.toLowerCase().contains('paid');
  bool get isOverdue => status.toLowerCase().contains('overdue');
  bool get isUnpaid => status.toLowerCase() == 'unpaid';

  factory Invoice.fromJson(Map<String, dynamic> j, InvoiceKind kind) {
    final partyKey = kind == InvoiceKind.sales ? 'customer' : 'supplier';
    final partyName = kind == InvoiceKind.sales ? 'customer_name' : 'supplier_name';
    return Invoice(
      name: j['name'] as String,
      kind: kind,
      party: (j[partyKey] ?? '') as String,
      partyDisplay: (j[partyName] ?? j[partyKey] ?? '') as String,
      postingDate: DateTime.parse(j['posting_date'] as String),
      dueDate: j['due_date'] != null
          ? DateTime.tryParse(j['due_date'].toString())
          : null,
      grandTotal: (j['grand_total'] as num?)?.toDouble() ?? 0,
      outstanding: (j['outstanding_amount'] as num?)?.toDouble() ?? 0,
      currency: (j['currency'] ?? 'INR') as String,
      status: (j['status'] ?? '') as String,
      docstatus: (j['docstatus'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class InvoiceLine {
  const InvoiceLine({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.rate,
    required this.amount,
    this.uom,
    this.description,
  });
  final String itemCode;
  final String itemName;
  final double qty;
  final double rate;
  final double amount;
  final String? uom;
  final String? description;

  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
        itemCode: (j['item_code'] ?? '') as String,
        itemName:
            (j['item_name'] ?? j['item_code'] ?? '') as String,
        qty: (j['qty'] as num?)?.toDouble() ?? 0,
        rate: (j['rate'] as num?)?.toDouble() ?? 0,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        uom: j['uom'] as String?,
        description: j['description'] as String?,
      );
}

@immutable
class InvoiceTax {
  const InvoiceTax({
    required this.description,
    required this.taxAmount,
    this.rate,
  });
  final String description;
  final double? rate;
  final double taxAmount;

  factory InvoiceTax.fromJson(Map<String, dynamic> j) => InvoiceTax(
        description: (j['description'] ?? '') as String,
        rate: (j['rate'] as num?)?.toDouble(),
        taxAmount: (j['tax_amount'] as num?)?.toDouble() ?? 0,
      );
}

@immutable
class LinkedPayment {
  const LinkedPayment({
    required this.name,
    required this.paymentType,
    required this.paidAmount,
    required this.allocatedAmount,
    required this.docstatus,
    this.postingDate,
    this.modeOfPayment,
    this.referenceNo,
    this.referenceDate,
  });
  final String name;
  final String paymentType;
  final double paidAmount;
  final double allocatedAmount;
  final int docstatus;
  final DateTime? postingDate;
  final String? modeOfPayment;
  final String? referenceNo;
  final DateTime? referenceDate;

  factory LinkedPayment.fromJson(Map<String, dynamic> j) => LinkedPayment(
        name: j['name'] as String,
        paymentType: (j['payment_type'] ?? '') as String,
        paidAmount: (j['paid_amount'] as num?)?.toDouble() ?? 0,
        allocatedAmount:
            (j['allocated_amount'] as num?)?.toDouble() ?? 0,
        docstatus: (j['docstatus'] as num?)?.toInt() ?? 0,
        postingDate: j['posting_date'] != null
            ? DateTime.tryParse(j['posting_date'].toString())
            : null,
        modeOfPayment: j['mode_of_payment'] as String?,
        referenceNo: j['reference_no'] as String?,
        referenceDate: j['reference_date'] != null
            ? DateTime.tryParse(j['reference_date'].toString())
            : null,
      );
}

@immutable
class InvoiceDetail {
  const InvoiceDetail({
    required this.name,
    required this.kind,
    required this.docstatus,
    required this.status,
    required this.party,
    required this.partyName,
    required this.currency,
    required this.netTotal,
    required this.totalTaxes,
    required this.grandTotal,
    required this.outstanding,
    required this.canSubmit,
    required this.canRecordPayment,
    required this.items,
    required this.taxes,
    required this.payments,
    this.postingDate,
    this.dueDate,
    this.remarks,
  });

  final String name;
  final InvoiceKind kind;
  final int docstatus;
  final String status;
  final String party;
  final String partyName;
  final String currency;
  final double netTotal;
  final double totalTaxes;
  final double grandTotal;
  final double outstanding;
  final bool canSubmit;
  final bool canRecordPayment;
  final List<InvoiceLine> items;
  final List<InvoiceTax> taxes;
  final List<LinkedPayment> payments;
  final DateTime? postingDate;
  final DateTime? dueDate;
  final String? remarks;

  bool get isDraft => docstatus == 0;

  factory InvoiceDetail.fromJson(Map<String, dynamic> j) {
    final k = (j['kind'] ?? 'sales').toString();
    return InvoiceDetail(
      name: j['name'] as String,
      kind: k == 'purchase' ? InvoiceKind.purchase : InvoiceKind.sales,
      docstatus: (j['docstatus'] as num?)?.toInt() ?? 0,
      status: (j['status'] ?? '') as String,
      party: (j['party'] ?? '') as String,
      partyName: (j['party_name'] ?? j['party'] ?? '') as String,
      currency: (j['currency'] ?? 'INR') as String,
      netTotal: (j['net_total'] as num?)?.toDouble() ?? 0,
      totalTaxes:
          (j['total_taxes_and_charges'] as num?)?.toDouble() ?? 0,
      grandTotal: (j['grand_total'] as num?)?.toDouble() ?? 0,
      outstanding: (j['outstanding_amount'] as num?)?.toDouble() ?? 0,
      canSubmit: (j['can_submit'] ?? false) as bool,
      canRecordPayment: (j['can_record_payment'] ?? false) as bool,
      postingDate: j['posting_date'] != null
          ? DateTime.tryParse(j['posting_date'].toString())
          : null,
      dueDate: j['due_date'] != null
          ? DateTime.tryParse(j['due_date'].toString())
          : null,
      remarks: j['remarks'] as String?,
      items: ((j['items'] as List?) ?? [])
          .map((e) => InvoiceLine.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      taxes: ((j['taxes'] as List?) ?? [])
          .map((e) => InvoiceTax.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      payments: ((j['payments'] as List?) ?? [])
          .map((e) =>
              LinkedPayment.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

@immutable
class ModeOfPayment {
  const ModeOfPayment({required this.name, this.type});
  final String name;
  final String? type;
  factory ModeOfPayment.fromJson(Map<String, dynamic> j) =>
      ModeOfPayment(name: j['name'] as String, type: j['type'] as String?);
}

@immutable
class Payment {
  const Payment({
    required this.name,
    required this.paymentType,
    required this.party,
    required this.partyName,
    required this.paidAmount,
    required this.docstatus,
    required this.status,
    this.postingDate,
    this.modeOfPayment,
    this.referenceNo,
  });
  final String name;
  final String paymentType; // "Receive" / "Pay"
  final String party;
  final String partyName;
  final double paidAmount;
  final int docstatus;
  final String status;
  final DateTime? postingDate;
  final String? modeOfPayment;
  final String? referenceNo;

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        name: j['name'] as String,
        paymentType: (j['payment_type'] ?? '') as String,
        party: (j['party'] ?? '') as String,
        partyName: (j['party_name'] ?? j['party'] ?? '') as String,
        paidAmount: (j['paid_amount'] as num?)?.toDouble() ?? 0,
        docstatus: (j['docstatus'] as num?)?.toInt() ?? 0,
        status: (j['status'] ?? '') as String,
        postingDate: j['posting_date'] != null
            ? DateTime.tryParse(j['posting_date'].toString())
            : null,
        modeOfPayment: j['mode_of_payment'] as String?,
        referenceNo: j['reference_no'] as String?,
      );
}

@immutable
class PaymentsContext {
  const PaymentsContext({
    required this.payments,
    required this.fromDate,
    required this.toDate,
    required this.canRead,
  });
  final List<Payment> payments;
  final DateTime fromDate;
  final DateTime toDate;
  final bool canRead;

  factory PaymentsContext.fromJson(Map<String, dynamic> j) {
    final now = DateTime.now();
    return PaymentsContext(
      canRead: (j['can_read'] ?? false) as bool,
      payments: ((j['payments'] as List?) ?? [])
          .map((e) => Payment.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      fromDate: j['from_date'] != null
          ? DateTime.tryParse(j['from_date'].toString()) ??
              DateTime(now.year, now.month, 1)
          : DateTime(now.year, now.month, 1),
      toDate: j['to_date'] != null
          ? DateTime.tryParse(j['to_date'].toString()) ?? now
          : now,
    );
  }
}

@immutable
class PartyRef {
  const PartyRef({required this.name, required this.label, this.currency});
  final String name;
  final String label;
  final String? currency;
  factory PartyRef.fromCustomerJson(Map<String, dynamic> j) => PartyRef(
        name: j['name'] as String,
        label: (j['customer_name'] ?? j['name']) as String,
        currency: j['default_currency'] as String?,
      );
  factory PartyRef.fromSupplierJson(Map<String, dynamic> j) => PartyRef(
        name: j['name'] as String,
        label: (j['supplier_name'] ?? j['name']) as String,
        currency: j['default_currency'] as String?,
      );
}

@immutable
class ItemRef {
  const ItemRef({
    required this.code,
    required this.label,
    this.uom,
    this.standardRate = 0,
  });
  final String code;
  final String label;
  final String? uom;
  final double standardRate;
  factory ItemRef.fromJson(Map<String, dynamic> j) => ItemRef(
        code: (j['item_code'] ?? j['name']) as String,
        label: (j['item_name'] ?? j['item_code'] ?? j['name']) as String,
        uom: j['stock_uom'] as String?,
        standardRate: (j['standard_rate'] as num?)?.toDouble() ?? 0,
      );
}

/// One line in a new invoice draft.
class InvoiceDraftItem {
  InvoiceDraftItem({this.itemCode, this.itemName, this.qty = 1, this.rate = 0});
  String? itemCode;
  String? itemName;
  double qty;
  double rate;
  double get amount => qty * rate;
  Map<String, dynamic> toJson() => {
        'item_code': itemCode,
        'qty': qty,
        'rate': rate,
      };
}

@immutable
class InvoicesContext {
  const InvoicesContext({
    required this.sales,
    required this.purchase,
    required this.canReadSales,
    required this.canReadPurchase,
    required this.canCreateSales,
    required this.canCreatePurchase,
    required this.canReadPayments,
  });

  final List<Invoice> sales;
  final List<Invoice> purchase;
  final bool canReadSales;
  final bool canReadPurchase;
  final bool canCreateSales;
  final bool canCreatePurchase;
  final bool canReadPayments;

  factory InvoicesContext.fromJson(Map<String, dynamic> j) => InvoicesContext(
        sales: ((j['sales'] as List?) ?? [])
            .map((e) => Invoice.fromJson(
                (e as Map).cast<String, dynamic>(), InvoiceKind.sales))
            .toList(),
        purchase: ((j['purchase'] as List?) ?? [])
            .map((e) => Invoice.fromJson(
                (e as Map).cast<String, dynamic>(), InvoiceKind.purchase))
            .toList(),
        canReadSales: (j['can_read_sales'] ?? false) as bool,
        canReadPurchase: (j['can_read_purchase'] ?? false) as bool,
        canCreateSales: (j['can_create_sales'] ?? false) as bool,
        canCreatePurchase: (j['can_create_purchase'] ?? false) as bool,
        canReadPayments: (j['can_read_payments'] ?? false) as bool,
      );
}
