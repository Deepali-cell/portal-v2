import 'package:flutter/foundation.dart';

@immutable
class LeaveBalance {
  const LeaveBalance({
    required this.leaveType,
    required this.total,
    required this.taken,
    required this.pending,
    required this.remaining,
    this.isLwp = false,
  });

  final String leaveType;
  final double total;
  final double taken;
  final double pending;
  final double remaining;

  /// Leave without pay draws down no allocation, so it carries no balance and
  /// the picker shows no days remaining against it.
  final bool isLwp;

  factory LeaveBalance.fromJson(Map<String, dynamic> j) => LeaveBalance(
    leaveType: j['leave_type'] as String,
    total: (j['total'] as num?)?.toDouble() ?? 0,
    taken: (j['taken'] as num?)?.toDouble() ?? 0,
    pending: (j['pending'] as num?)?.toDouble() ?? 0,
    remaining: (j['remaining'] as num?)?.toDouble() ?? 0,
    isLwp: ((j['is_lwp'] as num?)?.toInt() ?? 0) == 1,
  );
}

/// One leave request waiting on the signed in user, at either approval hop.
@immutable
class PendingLeaveApproval {
  const PendingLeaveApproval({
    required this.name,
    required this.employeeName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.totalLeaveDays,
    required this.stageLabel,
    required this.asHr,
    this.description,
    this.halfDay = false,
  });

  final String name;
  final String employeeName;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final double totalLeaveDays;
  final String stageLabel;

  /// True when this row is waiting on the user as HR rather than as the
  /// employee's own manager. Somebody who is both needs to know which hat the
  /// row is asking them to wear.
  final bool asHr;
  final String? description;
  final bool halfDay;

  factory PendingLeaveApproval.fromJson(Map<String, dynamic> j) =>
      PendingLeaveApproval(
        name: j['name'] as String,
        employeeName: (j['employee_name'] ?? j['employee'] ?? '') as String,
        leaveType: (j['leave_type'] ?? '') as String,
        fromDate: DateTime.parse(j['from_date'] as String),
        toDate: DateTime.parse(j['to_date'] as String),
        totalLeaveDays: (j['total_leave_days'] as num?)?.toDouble() ?? 0,
        stageLabel: (j['stage_label'] ?? '') as String,
        asHr: (j['as_hr'] ?? false) as bool,
        description: j['description'] as String?,
        halfDay: (j['half_day'] as num?)?.toInt() == 1,
      );
}

/// One of the signed-in user's own comp-off requests, with its approval stage.
@immutable
class CompOffSummary {
  const CompOffSummary({
    required this.name,
    required this.leaveType,
    required this.workFromDate,
    required this.workEndDate,
    required this.stageLabel,
    this.stage = 'Open',
    this.halfDay = false,
    this.reason,
    this.postingDate,
  });

  final String name;
  final String leaveType;
  final DateTime workFromDate;
  final DateTime workEndDate;
  final String stage;
  final String stageLabel;
  final bool halfDay;
  final String? reason;
  final DateTime? postingDate;

  LeaveStatus get status => _workflowStatus(stage);

  factory CompOffSummary.fromJson(Map<String, dynamic> j) => CompOffSummary(
    name: j['name'] as String,
    leaveType: (j['leave_type'] ?? '') as String,
    workFromDate: DateTime.parse(j['work_from_date'] as String),
    workEndDate: DateTime.parse(
      (j['work_end_date'] ?? j['work_from_date']) as String,
    ),
    stage: (j['stage'] ?? 'Open') as String,
    stageLabel: (j['stage_label'] ?? '') as String,
    halfDay: (j['half_day'] as num?)?.toInt() == 1,
    reason: j['reason'] as String?,
    postingDate: DateTime.tryParse((j['posting_date'] ?? '') as String),
  );
}

/// One comp-off request in the management list (HR/admin see everyone's, others
/// their own). Carries the raw [stage] so the screen can colour a status chip
/// and the [stageLabel] so it can spell out where the request is sitting.
@immutable
class CompOffApplication {
  const CompOffApplication({
    required this.name,
    required this.employeeName,
    required this.leaveType,
    required this.workFromDate,
    required this.workEndDate,
    required this.stage,
    required this.stageLabel,
    this.halfDay = false,
    this.reason,
  });

  final String name;
  final String employeeName;
  final String leaveType;
  final DateTime workFromDate;
  final DateTime workEndDate;
  final String stage;
  final String stageLabel;
  final bool halfDay;
  final String? reason;

  /// Maps the workflow stage onto the shared leave-status buckets so the UI can
  /// reuse the same chip colours. "Open"/"Pending HR Approval" are both pending.
  LeaveStatus get status => switch (stage) {
    'Approved' => LeaveStatus.approved,
    'Rejected' => LeaveStatus.rejected,
    _ => LeaveStatus.open,
  };

  factory CompOffApplication.fromJson(Map<String, dynamic> j) =>
      CompOffApplication(
        name: j['name'] as String,
        employeeName: (j['employee_name'] ?? j['employee'] ?? '') as String,
        leaveType: (j['leave_type'] ?? '') as String,
        workFromDate: DateTime.parse(j['work_from_date'] as String),
        workEndDate: DateTime.parse(
          (j['work_end_date'] ?? j['work_from_date']) as String,
        ),
        stage: (j['stage'] ?? 'Open') as String,
        stageLabel: (j['stage_label'] ?? '') as String,
        halfDay: (j['half_day'] as num?)?.toInt() == 1,
        reason: j['reason'] as String?,
      );
}

/// One comp-off request waiting on the signed in user, at either approval hop.
@immutable
class PendingCompOffApproval {
  const PendingCompOffApproval({
    required this.name,
    required this.employeeName,
    required this.leaveType,
    required this.workFromDate,
    required this.workEndDate,
    required this.stageLabel,
    required this.asHr,
    this.halfDay = false,
    this.reason,
  });

  final String name;
  final String employeeName;
  final String leaveType;
  final DateTime workFromDate;
  final DateTime workEndDate;
  final String stageLabel;
  final bool asHr;
  final bool halfDay;
  final String? reason;

  factory PendingCompOffApproval.fromJson(Map<String, dynamic> j) =>
      PendingCompOffApproval(
        name: j['name'] as String,
        employeeName: (j['employee_name'] ?? j['employee'] ?? '') as String,
        leaveType: (j['leave_type'] ?? '') as String,
        workFromDate: DateTime.parse(j['work_from_date'] as String),
        workEndDate: DateTime.parse(
          (j['work_end_date'] ?? j['work_from_date']) as String,
        ),
        stageLabel: (j['stage_label'] ?? '') as String,
        asHr: (j['as_hr'] ?? false) as bool,
        halfDay: (j['half_day'] as num?)?.toInt() == 1,
        reason: j['reason'] as String?,
      );
}

enum LeaveStatus { open, approved, rejected, cancelled }

/// Comp-off and WFH carry a workflow stage instead of a status; "Open" and
/// "Pending HR Approval" both read as pending.
LeaveStatus _workflowStatus(String stage) => switch (stage) {
  'Approved' => LeaveStatus.approved,
  'Rejected' => LeaveStatus.rejected,
  'Cancelled' => LeaveStatus.cancelled,
  _ => LeaveStatus.open,
};

LeaveStatus leaveStatusFrom(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'approved':
      return LeaveStatus.approved;
    case 'rejected':
      return LeaveStatus.rejected;
    case 'cancelled':
      return LeaveStatus.cancelled;
    default:
      return LeaveStatus.open;
  }
}

@immutable
class LeaveApplication {
  const LeaveApplication({
    required this.name,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.totalLeaveDays,
    required this.status,
    this.employeeName,
    this.description,
    this.halfDay = false,
    this.stageLabel,
  });

  final String name;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final double totalLeaveDays;
  final LeaveStatus status;

  /// Whose application this is. Present on the HR management listing (all
  /// employees' applications); null on the employee's own self-service list.
  final String? employeeName;
  final String? description;
  final bool halfDay;

  /// Where the request has actually reached. `status` stays Open across both
  /// waiting hops, so this is what tells the applicant whether their manager
  /// has cleared it and it is now with HR.
  final String? stageLabel;

  factory LeaveApplication.fromJson(Map<String, dynamic> j) => LeaveApplication(
    name: j['name'] as String,
    leaveType: (j['leave_type'] ?? '') as String,
    fromDate: DateTime.parse(j['from_date'] as String),
    toDate: DateTime.parse(j['to_date'] as String),
    totalLeaveDays: (j['total_leave_days'] as num?)?.toDouble() ?? 0,
    status: leaveStatusFrom(j['status'] as String?),
    employeeName: j['employee_name'] as String?,
    description: j['description'] as String?,
    halfDay: (j['half_day'] as num?)?.toInt() == 1,
    stageLabel: j['stage_label'] as String?,
  );
}

/// A file attached to a leave application (e.g. a medical certificate for sick
/// leave). [absoluteUrl] is host-prefixed so it opens in an external viewer.
@immutable
class LeaveAttachment {
  const LeaveAttachment({
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

  factory LeaveAttachment.fromJson(Map<String, dynamic> j) => LeaveAttachment(
    name: (j['name'] ?? '') as String,
    fileName: (j['file_name'] ?? j['file_url'] ?? '') as String,
    absoluteUrl: (j['absolute_url'] ?? j['file_url'] ?? '') as String,
    fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
    isPrivate: (j['is_private'] as num?)?.toInt() == 1,
  );
}

@immutable
class LeaveApplicationDetail {
  const LeaveApplicationDetail({
    required this.name,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.totalLeaveDays,
    required this.status,
    required this.docstatus,
    required this.halfDay,
    this.employeeName,
    this.stageLabel,
    this.description,
    this.halfDayDate,
    this.leaveApprover,
    this.leaveApproverName,
    this.postingDate,
    this.attachments = const [],
  });
  final String name;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final double totalLeaveDays;
  final LeaveStatus status;
  final int docstatus;
  final bool halfDay;

  /// Whose application this is — shown in the detail header when an approver or
  /// HR opens a request that belongs to another employee.
  final String? employeeName;

  /// Human-readable approval stage (e.g. "Approved by manager, waiting for HR").
  final String? stageLabel;
  final DateTime? halfDayDate;
  final String? description;
  final String? leaveApprover;
  final String? leaveApproverName;
  final DateTime? postingDate;

  /// Proof files (e.g. a medical certificate). Empty when none are attached.
  final List<LeaveAttachment> attachments;

  factory LeaveApplicationDetail.fromJson(Map<String, dynamic> j) =>
      LeaveApplicationDetail(
        name: j['name'] as String,
        leaveType: (j['leave_type'] ?? '') as String,
        fromDate: DateTime.parse(j['from_date'] as String),
        toDate: DateTime.parse(j['to_date'] as String),
        totalLeaveDays: (j['total_leave_days'] as num?)?.toDouble() ?? 0,
        status: leaveStatusFrom(j['status'] as String?),
        docstatus: (j['docstatus'] as num?)?.toInt() ?? 0,
        halfDay: (j['half_day'] as num?)?.toInt() == 1,
        employeeName: j['employee_name'] as String?,
        stageLabel: j['stage_label'] as String?,
        halfDayDate: j['half_day_date'] != null
            ? DateTime.tryParse(j['half_day_date'].toString())
            : null,
        description: j['description'] as String?,
        leaveApprover: j['leave_approver'] as String?,
        leaveApproverName: j['leave_approver_name'] as String?,
        postingDate: j['posting_date'] != null
            ? DateTime.tryParse(j['posting_date'].toString())
            : null,
        attachments: ((j['attachments'] as List?) ?? [])
            .map(
              (e) =>
                  LeaveAttachment.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList(),
      );
}

@immutable
class LeaveContext {
  const LeaveContext({
    required this.employee,
    required this.balances,
    required this.applications,
    required this.leaveTypes,
    required this.compensatoryLeaveTypes,
    this.compOffRequests = const [],
    this.leaveApprover,
    this.leaveApproverName,
    this.holidays = const {},
    this.pendingApprovalCount = 0,
    this.compOffPendingCount = 0,
    this.isHr = false,
  });

  final String employee;
  final String? leaveApprover;
  final String? leaveApproverName;
  final List<LeaveBalance> balances;
  final List<LeaveApplication> applications;

  /// The signed-in user's own comp-off requests, most recent first.
  final List<CompOffSummary> compOffRequests;
  final List<String> leaveTypes;

  /// Holiday and weekly off dates for this employee, as yyyy-MM-dd strings.
  /// The date picker greys these out so a leave day is never spent on a day
  /// the office was closed anyway.
  final Set<String> holidays;

  /// How many requests are waiting on this user across both hops. Non zero
  /// means the Approvals entry is worth showing.
  final int pendingApprovalCount;

  /// How many comp-off requests are waiting on this user across both hops.
  final int compOffPendingCount;
  final bool isHr;

  bool isHoliday(DateTime d) => holidays.contains(
    '${d.year.toString().padLeft(4, '0')}'
    '-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}',
  );

  /// Balance for one leave type, or null when the type carries none.
  LeaveBalance? balanceFor(String leaveType) {
    for (final b in balances) {
      if (b.leaveType == leaveType) return b;
    }
    return null;
  }

  /// Subset of leave types where `is_compensatory=1`. Empty when comp-off
  /// isn't configured on the site; the mobile hides the Apply CTA in that case.
  final List<String> compensatoryLeaveTypes;

  bool get supportsCompOff => compensatoryLeaveTypes.isNotEmpty;

  factory LeaveContext.fromJson(Map<String, dynamic> j) => LeaveContext(
    employee: j['employee'] as String,
    leaveApprover: j['leave_approver'] as String?,
    leaveApproverName: j['leave_approver_name'] as String?,
    holidays: ((j['holidays'] as List?) ?? []).map((e) => e.toString()).toSet(),
    pendingApprovalCount: (j['pending_approval_count'] as num?)?.toInt() ?? 0,
    compOffPendingCount: (j['comp_off_pending_count'] as num?)?.toInt() ?? 0,
    isHr: (j['is_hr'] ?? false) as bool,
    balances: ((j['balances'] as List?) ?? [])
        .map((e) => LeaveBalance.fromJson(e as Map<String, dynamic>))
        .toList(),
    applications: ((j['applications'] as List?) ?? [])
        .map((e) => LeaveApplication.fromJson(e as Map<String, dynamic>))
        .toList(),
    compOffRequests: ((j['comp_off_requests'] as List?) ?? [])
        .map((e) => CompOffSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    leaveTypes: ((j['leave_types'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    compensatoryLeaveTypes: ((j['compensatory_leave_types'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
  );
}

/// Form payload for an Apply-for-Comp-Off request.
@immutable
class CompOffRequest {
  const CompOffRequest({
    required this.workFromDate,
    required this.reason,
    this.workEndDate,
    this.leaveType,
  });
  final DateTime workFromDate;
  final DateTime? workEndDate;
  final String reason;
  final String? leaveType;
}

/// One HR-configurable leave notice-period rule: a leave of up to
/// [maxLeaveDays] must be applied at least [minNoticeDays] before it starts.
/// [leaveType] null = applies to every type; [company] null = every company.
@immutable
class LeaveNoticeRule {
  const LeaveNoticeRule({
    required this.name,
    required this.ruleName,
    required this.maxLeaveDays,
    required this.minNoticeDays,
    this.isActive = true,
    this.leaveType,
    this.company,
    this.description,
  });

  final String name;
  final String ruleName;
  final double maxLeaveDays;
  final int minNoticeDays;
  final bool isActive;
  final String? leaveType;
  final String? company;
  final String? description;

  factory LeaveNoticeRule.fromJson(Map<String, dynamic> j) => LeaveNoticeRule(
    name: (j['name'] ?? '') as String,
    ruleName: (j['rule_name'] ?? '') as String,
    maxLeaveDays: (j['max_leave_days'] as num?)?.toDouble() ?? 0,
    minNoticeDays: (j['min_notice_days'] as num?)?.toInt() ?? 0,
    isActive: (j['is_active'] as num?)?.toInt() != 0,
    leaveType: (j['leave_type'] as String?)?.isEmpty ?? true
        ? null
        : j['leave_type'] as String?,
    company: (j['company'] as String?)?.isEmpty ?? true
        ? null
        : j['company'] as String?,
    description: j['description'] as String?,
  );
}

/// One of the signed-in user's own Work From Home requests, with its stage.
@immutable
class WfhSummary {
  const WfhSummary({
    required this.name,
    required this.fromDate,
    required this.toDate,
    required this.stageLabel,
    this.stage = 'Open',
    this.halfDay = false,
    this.halfDayDate,
    this.explanation,
    this.postingDate,
  });

  final String name;
  final DateTime fromDate;
  final DateTime toDate;
  final String stage;
  final String stageLabel;
  final bool halfDay;
  final DateTime? halfDayDate;
  final String? explanation;
  final DateTime? postingDate;

  LeaveStatus get status => _workflowStatus(stage);

  factory WfhSummary.fromJson(Map<String, dynamic> j) => WfhSummary(
    name: j['name'] as String,
    fromDate: DateTime.parse(j['from_date'] as String),
    toDate: DateTime.parse((j['to_date'] ?? j['from_date']) as String),
    stage: (j['stage'] ?? 'Open') as String,
    stageLabel: (j['stage_label'] ?? '') as String,
    halfDay: (j['half_day'] as num?)?.toInt() == 1,
    halfDayDate: DateTime.tryParse((j['half_day_date'] ?? '') as String),
    explanation: j['explanation'] as String?,
    postingDate: DateTime.tryParse((j['posting_date'] ?? '') as String),
  );
}

/// One WFH request waiting on the signed in user, at either approval hop.
@immutable
class PendingWfhApproval {
  const PendingWfhApproval({
    required this.name,
    required this.employeeName,
    required this.fromDate,
    required this.toDate,
    required this.stageLabel,
    required this.asHr,
    this.halfDay = false,
    this.explanation,
  });

  final String name;
  final String employeeName;
  final DateTime fromDate;
  final DateTime toDate;
  final String stageLabel;
  final bool asHr;
  final bool halfDay;
  final String? explanation;

  factory PendingWfhApproval.fromJson(Map<String, dynamic> j) =>
      PendingWfhApproval(
        name: j['name'] as String,
        employeeName: (j['employee_name'] ?? j['employee'] ?? '') as String,
        fromDate: DateTime.parse(j['from_date'] as String),
        toDate: DateTime.parse((j['to_date'] ?? j['from_date']) as String),
        stageLabel: (j['stage_label'] ?? '') as String,
        asHr: (j['as_hr'] ?? false) as bool,
        halfDay: (j['half_day'] as num?)?.toInt() == 1,
        explanation: j['explanation'] as String?,
      );
}

/// Form payload for a new Work From Home request.
@immutable
class WfhRequest {
  const WfhRequest({
    required this.fromDate,
    this.toDate,
    this.halfDay = false,
    this.halfDayDate,
    this.explanation,
  });

  final DateTime fromDate;
  final DateTime? toDate;
  final bool halfDay;
  final DateTime? halfDayDate;
  final String? explanation;
}

/// Form payload for a new leave request.
@immutable
class LeaveRequest {
  const LeaveRequest({
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    this.halfDay = false,
    this.halfDayDate,
    this.description,
  });

  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final bool halfDay;
  final DateTime? halfDayDate;
  final String? description;
}
