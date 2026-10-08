import 'package:flutter/foundation.dart';

@immutable
class Payslip {
  const Payslip({
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.gross,
    required this.net,
    required this.deduction,
    required this.currency,
    this.status,
  });

  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final double gross;
  final double net;
  final double deduction;
  final String currency;
  final String? status;

  factory Payslip.fromJson(Map<String, dynamic> j) => Payslip(
        name: j['name'] as String,
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: DateTime.parse(j['end_date'] as String),
        gross: (j['gross_pay'] as num?)?.toDouble() ?? 0,
        net: (j['net_pay'] as num?)?.toDouble() ?? 0,
        deduction: (j['total_deduction'] as num?)?.toDouble() ?? 0,
        currency: (j['currency'] ?? 'INR') as String,
        status: j['status'] as String?,
      );
}

@immutable
class PayslipContext {
  const PayslipContext({
    required this.slips,
    required this.fromDate,
    required this.toDate,
  });

  final List<Payslip> slips;
  final DateTime fromDate;
  final DateTime toDate;

  factory PayslipContext.fromJson(Map<String, dynamic> j) {
    final now = DateTime.now();
    return PayslipContext(
      slips: ((j['slips'] as List?) ?? [])
          .map((e) => Payslip.fromJson(e as Map<String, dynamic>))
          .toList(),
      fromDate: j['from_date'] != null
          ? DateTime.tryParse(j['from_date'].toString()) ??
              DateTime(now.year, 1, 1)
          : DateTime(now.year, 1, 1),
      toDate: j['to_date'] != null
          ? DateTime.tryParse(j['to_date'].toString()) ?? now
          : now,
    );
  }
}

/// One row on the Finance > All Payslips screen: a salary slip for any
/// employee, carrying who it belongs to and whether it is still a draft.
@immutable
class AllPayslip {
  const AllPayslip({
    required this.name,
    required this.employee,
    required this.employeeName,
    required this.startDate,
    required this.endDate,
    required this.gross,
    required this.net,
    required this.deduction,
    required this.currency,
    required this.docstatus,
    this.status,
  });

  final String name;
  final String employee;
  final String employeeName;
  final DateTime startDate;
  final DateTime endDate;
  final double gross;
  final double net;
  final double deduction;
  final String currency;

  /// 0 = Draft (pending), 1 = Submitted (final).
  final int docstatus;
  final String? status;

  bool get isDraft => docstatus == 0;

  factory AllPayslip.fromJson(Map<String, dynamic> j) => AllPayslip(
        name: j['name'] as String,
        employee: (j['employee'] ?? '') as String,
        employeeName: (j['employee_name'] ?? j['employee'] ?? '') as String,
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: DateTime.parse(j['end_date'] as String),
        gross: (j['gross_pay'] as num?)?.toDouble() ?? 0,
        net: (j['net_pay'] as num?)?.toDouble() ?? 0,
        deduction: (j['total_deduction'] as num?)?.toDouble() ?? 0,
        currency: (j['currency'] ?? 'INR') as String,
        docstatus: (j['docstatus'] as num?)?.toInt() ?? 0,
        status: j['status'] as String?,
      );
}

@immutable
class AllPayslipsContext {
  const AllPayslipsContext({
    required this.year,
    required this.month,
    required this.status,
    required this.count,
    required this.totalNet,
    required this.slips,
  });

  final int year;

  /// null = whole year.
  final int? month;

  /// "all" | "draft" | "submitted".
  final String status;
  final int count;
  final double totalNet;
  final List<AllPayslip> slips;

  String get currency => slips.isNotEmpty ? slips.first.currency : 'INR';

  factory AllPayslipsContext.fromJson(Map<String, dynamic> j) =>
      AllPayslipsContext(
        year: (j['year'] as num?)?.toInt() ?? DateTime.now().year,
        month: (j['month'] as num?)?.toInt(),
        status: (j['status'] ?? 'all') as String,
        count: (j['count'] as num?)?.toInt() ?? 0,
        totalNet: (j['total_net'] as num?)?.toDouble() ?? 0,
        slips: ((j['slips'] as List?) ?? [])
            .map((e) => AllPayslip.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

@immutable
class PayslipLine {
  const PayslipLine({required this.component, required this.amount});
  final String component;
  final double amount;

  factory PayslipLine.fromJson(Map<String, dynamic> j) => PayslipLine(
        component: (j['component'] ?? '') as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );
}

@immutable
class PayslipDetail {
  const PayslipDetail({
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.gross,
    required this.deduction,
    required this.net,
    required this.currency,
    required this.earnings,
    required this.deductions,
  });

  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final double gross;
  final double deduction;
  final double net;
  final String currency;
  final List<PayslipLine> earnings;
  final List<PayslipLine> deductions;

  factory PayslipDetail.fromJson(Map<String, dynamic> j) => PayslipDetail(
        name: j['name'] as String,
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: DateTime.parse(j['end_date'] as String),
        gross: (j['gross_pay'] as num?)?.toDouble() ?? 0,
        deduction: (j['total_deduction'] as num?)?.toDouble() ?? 0,
        net: (j['net_pay'] as num?)?.toDouble() ?? 0,
        currency: (j['currency'] ?? 'INR') as String,
        earnings: ((j['earnings'] as List?) ?? [])
            .map((e) => PayslipLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        deductions: ((j['deductions'] as List?) ?? [])
            .map((e) => PayslipLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
