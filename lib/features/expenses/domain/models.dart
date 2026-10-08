import 'package:flutter/foundation.dart';

enum ClaimStatus {
  draft,
  submitted,
  approved,
  rejected,
  paid,
  unpaid,
  cancelled,
}

ClaimStatus claimStatusFrom(String? approval, String? status) {
  final a = (approval ?? '').toLowerCase();
  if (a == 'approved') return ClaimStatus.approved;
  if (a == 'rejected') return ClaimStatus.rejected;
  switch ((status ?? '').toLowerCase()) {
    case 'paid':
      return ClaimStatus.paid;
    case 'unpaid':
      return ClaimStatus.unpaid;
    case 'submitted':
      return ClaimStatus.submitted;
    case 'cancelled':
      return ClaimStatus.cancelled;
    default:
      return ClaimStatus.draft;
  }
}

@immutable
class ExpenseClaim {
  const ExpenseClaim({
    required this.name,
    required this.postingDate,
    required this.totalClaimed,
    required this.totalSanctioned,
    required this.status,
    this.stageLabel,
    this.employeeName,
  });

  final String name;
  final DateTime postingDate;
  final double totalClaimed;
  final double totalSanctioned;
  final ClaimStatus status;

  /// Only populated in the HR/admin "all claims" view, where each row belongs
  /// to a different employee. Null on the employee's own list.
  final String? employeeName;

  /// Where the claim has actually reached in the two-hop approval. `status`
  /// stays Draft across both waiting hops, so this tells the employee whether
  /// their approver has cleared it and it is now with HR.
  final String? stageLabel;

  factory ExpenseClaim.fromJson(Map<String, dynamic> j) => ExpenseClaim(
    name: j['name'] as String,
    postingDate: DateTime.parse(j['posting_date'] as String),
    totalClaimed: (j['total_claimed_amount'] as num?)?.toDouble() ?? 0,
    totalSanctioned: (j['total_sanctioned_amount'] as num?)?.toDouble() ?? 0,
    status: claimStatusFrom(
      j['approval_status'] as String?,
      j['status'] as String?,
    ),
    stageLabel: j['stage_label'] as String?,
    employeeName: j['employee_name'] as String?,
  );
}

/// One receipt/proof file attached to an expense claim.
@immutable
class ExpenseAttachment {
  const ExpenseAttachment({
    required this.name,
    required this.fileName,
    required this.absoluteUrl,
    this.fileSize = 0,
    this.isPrivate = false,
  });

  final String name;
  final String fileName;
  final String absoluteUrl;
  final int fileSize;
  final bool isPrivate;

  factory ExpenseAttachment.fromJson(Map<String, dynamic> j) =>
      ExpenseAttachment(
        name: (j['name'] ?? '') as String,
        fileName: (j['file_name'] ?? j['file_url'] ?? '') as String,
        absoluteUrl: (j['absolute_url'] ?? j['file_url'] ?? '') as String,
        fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
        isPrivate: (j['is_private'] as num?)?.toInt() == 1,
      );
}

/// One expense claim waiting on the signed in user, at either approval hop.
@immutable
class PendingExpenseApproval {
  const PendingExpenseApproval({
    required this.name,
    required this.employeeName,
    required this.postingDate,
    required this.totalClaimed,
    required this.currency,
    required this.stageLabel,
    required this.asHr,
    this.remark,
  });

  final String name;
  final String employeeName;
  final DateTime postingDate;
  final double totalClaimed;
  final String currency;
  final String stageLabel;
  final bool asHr;
  final String? remark;

  factory PendingExpenseApproval.fromJson(Map<String, dynamic> j) =>
      PendingExpenseApproval(
        name: j['name'] as String,
        employeeName: (j['employee_name'] ?? j['employee'] ?? '') as String,
        postingDate: DateTime.parse(j['posting_date'] as String),
        totalClaimed: (j['total_claimed_amount'] as num?)?.toDouble() ?? 0,
        currency: (j['currency'] ?? 'INR') as String,
        stageLabel: (j['stage_label'] ?? '') as String,
        asHr: (j['as_hr'] ?? false) as bool,
        remark: j['remark'] as String?,
      );
}

/// One line of an expense claim, shown when an approver opens the detail.
@immutable
class ExpenseLine {
  const ExpenseLine({
    required this.expenseType,
    required this.amount,
    this.sanctionedAmount = 0,
    this.expenseDate,
    this.description,
  });

  final String expenseType;
  final double amount;
  final double sanctionedAmount;
  final DateTime? expenseDate;
  final String? description;

  factory ExpenseLine.fromJson(Map<String, dynamic> j) => ExpenseLine(
    expenseType: (j['expense_type'] ?? '') as String,
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    sanctionedAmount: (j['sanctioned_amount'] as num?)?.toDouble() ?? 0,
    expenseDate: j['expense_date'] != null
        ? DateTime.tryParse(j['expense_date'].toString())
        : null,
    description: j['description'] as String?,
  );
}

/// Full detail of one expense claim, with its line items.
@immutable
class ExpenseClaimDetail {
  const ExpenseClaimDetail({
    required this.name,
    required this.employeeName,
    required this.postingDate,
    required this.currency,
    required this.totalClaimed,
    required this.totalSanctioned,
    required this.status,
    required this.stageLabel,
    required this.lines,
    required this.attachments,
    this.docstatus = 0,
    this.expenseApprover,
    this.remark,
  });

  final String name;
  final String employeeName;
  final DateTime? postingDate;
  final String currency;
  final double totalClaimed;
  final double totalSanctioned;
  final ClaimStatus status;
  final String stageLabel;
  final List<ExpenseLine> lines;
  final List<ExpenseAttachment> attachments;
  final int docstatus;
  final String? expenseApprover;
  final String? remark;

  factory ExpenseClaimDetail.fromJson(
    Map<String, dynamic> j,
  ) => ExpenseClaimDetail(
    name: j['name'] as String,
    employeeName: (j['employee_name'] ?? j['employee'] ?? '') as String,
    postingDate: j['posting_date'] != null
        ? DateTime.tryParse(j['posting_date'].toString())
        : null,
    currency: (j['currency'] ?? 'INR') as String,
    totalClaimed: (j['total_claimed_amount'] as num?)?.toDouble() ?? 0,
    totalSanctioned: (j['total_sanctioned_amount'] as num?)?.toDouble() ?? 0,
    status: claimStatusFrom(
      j['approval_status'] as String?,
      j['status'] as String?,
    ),
    stageLabel: (j['stage_label'] ?? '') as String,
    lines: ((j['expenses'] as List?) ?? [])
        .map((e) => ExpenseLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    attachments: ((j['attachments'] as List?) ?? [])
        .map(
          (e) => ExpenseAttachment.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
    docstatus: (j['docstatus'] as num?)?.toInt() ?? 0,
    expenseApprover: j['expense_approver'] as String?,
    remark: j['remark'] as String?,
  );
}

@immutable
class ExpenseContext {
  const ExpenseContext({
    required this.employee,
    required this.currency,
    required this.expenseTypes,
    required this.claims,
    required this.fromDate,
    required this.toDate,
    this.pendingApprovalCount = 0,
    this.isHr = false,
  });

  final String employee;
  final String currency;
  final List<String> expenseTypes;
  final List<ExpenseClaim> claims;
  final DateTime fromDate;
  final DateTime toDate;

  /// How many claims are waiting on this user across both hops. Non zero means
  /// the Approval Requests entry is worth showing on the expenses screen.
  final int pendingApprovalCount;
  final bool isHr;

  factory ExpenseContext.fromJson(Map<String, dynamic> j) {
    final now = DateTime.now();
    return ExpenseContext(
      employee: j['employee'] as String,
      currency: (j['currency'] ?? 'INR') as String,
      pendingApprovalCount: (j['pending_approval_count'] as num?)?.toInt() ?? 0,
      isHr: (j['is_hr'] ?? false) as bool,
      expenseTypes: ((j['expense_types'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      claims: ((j['claims'] as List?) ?? [])
          .map((e) => ExpenseClaim.fromJson(e as Map<String, dynamic>))
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

/// One line in a new expense claim.
@immutable
class ExpenseItem {
  const ExpenseItem({
    required this.expenseType,
    required this.amount,
    this.description,
  });

  final String expenseType;
  final double amount;
  final String? description;

  Map<String, dynamic> toJson() => {
    'expense_type': expenseType,
    'amount': amount,
    if (description != null && description!.isNotEmpty)
      'description': description,
  };
}
