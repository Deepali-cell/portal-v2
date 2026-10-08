import 'package:flutter/foundation.dart';

/// Period preset shared by all three role dashboards. Matches the backend
/// `_date_range.resolve_range` contract.
enum RolePeriod { today, week, month }

extension RolePeriodX on RolePeriod {
  String get apiName => switch (this) {
        RolePeriod.today => 'today',
        RolePeriod.week => 'week',
        RolePeriod.month => 'month',
      };
  String get label => switch (this) {
        RolePeriod.today => 'Today',
        RolePeriod.week => 'This week',
        RolePeriod.month => 'This month',
      };
}

// ---------------------------------------------------------------------- HR

@immutable
class HrBirthday {
  const HrBirthday({
    required this.employeeName,
    required this.designation,
    required this.date,
    required this.daysAway,
  });
  final String employeeName;
  final String designation;
  final String date;
  final int daysAway;

  factory HrBirthday.fromJson(Map<String, dynamic> j) => HrBirthday(
        employeeName: (j['employee_name'] ?? '').toString(),
        designation: (j['designation'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        daysAway: (j['days_away'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class HrSummary {
  const HrSummary({
    required this.pendingLeaveApps,
    required this.absentToday,
    required this.birthdays,
    required this.upcomingExits,
    required this.expenseClaims,
    required this.activeHeadcount,
    required this.onLeave,
    required this.pendingAttendance,
  });
  final int pendingLeaveApps;
  final int absentToday;
  final List<HrBirthday> birthdays;
  final int upcomingExits;
  final int expenseClaims;
  final int activeHeadcount;
  final int onLeave;
  final int pendingAttendance;

  factory HrSummary.fromJson(Map<String, dynamic> j) => HrSummary(
        pendingLeaveApps: (j['pending_leave_apps'] as num?)?.toInt() ?? 0,
        absentToday: (j['absent_today'] as num?)?.toInt() ?? 0,
        birthdays: ((j['birthdays_this_week'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => HrBirthday.fromJson(e.cast<String, dynamic>()))
            .toList(),
        upcomingExits: (j['upcoming_exits'] as num?)?.toInt() ?? 0,
        expenseClaims: (j['expense_claims'] as num?)?.toInt() ?? 0,
        activeHeadcount: (j['active_headcount'] as num?)?.toInt() ?? 0,
        onLeave: (j['on_leave'] as num?)?.toInt() ?? 0,
        pendingAttendance: (j['pending_attendance'] as num?)?.toInt() ?? 0,
      );
}

// ---------------------------------------------------------------------- Projects

@immutable
class ProjectsDeadline {
  const ProjectsDeadline({
    required this.project,
    required this.subject,
    required this.expEndDate,
    required this.daysLeft,
    required this.status,
  });
  final String project;
  final String subject;
  final String expEndDate;
  final int daysLeft;
  final String status;

  factory ProjectsDeadline.fromJson(Map<String, dynamic> j) => ProjectsDeadline(
        project: (j['project'] ?? '').toString(),
        subject: (j['subject'] ?? '').toString(),
        expEndDate: (j['exp_end_date'] ?? '').toString(),
        daysLeft: (j['days_left'] as num?)?.toInt() ?? 0,
        status: (j['status'] ?? '').toString(),
      );
}

@immutable
class ProjectsSummary {
  const ProjectsSummary({
    required this.myActiveProjects,
    required this.tasksDueInPeriod,
    required this.tasksOverdue,
    required this.unbilledTimesheetHours,
    required this.draftTimesheetCount,
    required this.nextDeadlines,
    required this.scope,
  });
  final int myActiveProjects;
  final int tasksDueInPeriod;
  final int tasksOverdue;
  final double unbilledTimesheetHours;
  final int draftTimesheetCount;
  final List<ProjectsDeadline> nextDeadlines;
  final String scope;

  factory ProjectsSummary.fromJson(Map<String, dynamic> j) => ProjectsSummary(
        myActiveProjects: (j['my_active_projects'] as num?)?.toInt() ?? 0,
        tasksDueInPeriod: (j['tasks_due_in_period'] as num?)?.toInt() ?? 0,
        tasksOverdue: (j['tasks_overdue'] as num?)?.toInt() ?? 0,
        unbilledTimesheetHours:
            (j['unbilled_timesheet_hours'] as num?)?.toDouble() ?? 0.0,
        draftTimesheetCount:
            (j['draft_timesheet_count'] as num?)?.toInt() ?? 0,
        nextDeadlines: ((j['next_deadlines'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ProjectsDeadline.fromJson(e.cast<String, dynamic>()))
            .toList(),
        scope: (j['scope'] ?? 'mine').toString(),
      );
}

// ---------------------------------------------------------------------- Accounts

@immutable
class AccountsOverdue {
  const AccountsOverdue({
    required this.kind,
    required this.name,
    required this.party,
    required this.outstanding,
    required this.dueDate,
    required this.daysOverdue,
  });
  final String kind; // "Sales Invoice" | "Purchase Invoice"
  final String name;
  final String party;
  final double outstanding;
  final String? dueDate;
  final int daysOverdue;

  bool get isSales => kind == 'Sales Invoice';

  factory AccountsOverdue.fromJson(Map<String, dynamic> j) => AccountsOverdue(
        kind: (j['kind'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        party: (j['party'] ?? '').toString(),
        outstanding: (j['outstanding'] as num?)?.toDouble() ?? 0.0,
        dueDate: j['due_date'] as String?,
        daysOverdue: (j['days_overdue'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class AccountsSummary {
  const AccountsSummary({
    required this.currency,
    required this.receivableOutstanding,
    required this.payableOutstanding,
    required this.overdueInvoices,
    required this.receiptsInPeriod,
    required this.paymentsInPeriod,
    this.incomeInPeriod = 0.0,
    this.expenseInPeriod = 0.0,
    this.netProfit = 0.0,
    this.netCash = 0.0,
    required this.topOverdue,
  });
  final String currency;
  final double receivableOutstanding;
  final double payableOutstanding;
  final int overdueInvoices;
  final double receiptsInPeriod;
  final double paymentsInPeriod;
  final double incomeInPeriod;
  final double expenseInPeriod;
  final double netProfit;
  final double netCash;
  final List<AccountsOverdue> topOverdue;

  factory AccountsSummary.fromJson(Map<String, dynamic> j) => AccountsSummary(
        currency: (j['currency'] ?? 'INR').toString(),
        receivableOutstanding:
            (j['receivable_outstanding'] as num?)?.toDouble() ?? 0.0,
        payableOutstanding:
            (j['payable_outstanding'] as num?)?.toDouble() ?? 0.0,
        overdueInvoices: (j['overdue_invoices'] as num?)?.toInt() ?? 0,
        receiptsInPeriod: (j['receipts_in_period'] as num?)?.toDouble() ?? 0.0,
        paymentsInPeriod: (j['payments_in_period'] as num?)?.toDouble() ?? 0.0,
        incomeInPeriod: (j['income_in_period'] as num?)?.toDouble() ?? 0.0,
        expenseInPeriod: (j['expense_in_period'] as num?)?.toDouble() ?? 0.0,
        netProfit: (j['net_profit'] as num?)?.toDouble() ?? 0.0,
        netCash: (j['net_cash'] as num?)?.toDouble() ?? 0.0,
        topOverdue: ((j['top_overdue'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AccountsOverdue.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}
