import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../auth/domain/profile.dart';

@immutable
class NavDest {
  const NavDest(
    this.id,
    this.label,
    this.icon,
    this.selectedIcon,
    this.route,
    this.cap, [
    this.module,
  ]);

  /// Stable screen id, `<licence module>.<screen>` (e.g. 'crm.recordings').
  /// The prefix is the licence module the screen belongs to ('core' = always
  /// on); the site admin switches screens off by this id (Admin > Screens).
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final String? cap;

  /// Groups this destination under a module tile (e.g. "HR", "Stock").
  /// `null` keeps it as a top-level item alongside the module tiles (Home).
  final String? module;
}

/// Icon/label shown for a module's own nav tile, keyed by [NavDest.module].
const Map<String, (IconData, IconData, String)> moduleMeta = {
  'HR': (Icons.groups_outlined, Icons.groups, 'HR'),
  'CRM': (Icons.handshake_outlined, Icons.handshake, 'CRM'),
  'Finance': (
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet,
    'Finance',
  ),
  'Stock': (Icons.inventory_2_outlined, Icons.inventory_2, 'Stock'),
  'Sales': (Icons.point_of_sale_outlined, Icons.point_of_sale, 'Sales'),
  'Purchase': (Icons.shopping_cart_outlined, Icons.shopping_cart, 'Purchase'),
  'Manufacturing': (
    Icons.precision_manufacturing_outlined,
    Icons.precision_manufacturing,
    'Manufacturing',
  ),
  'Manufacturing Masters': (
    Icons.inventory_2_outlined,
    Icons.inventory_2,
    'Manufacturing Masters',
  ),
  'Projects': (Icons.folder_open_outlined, Icons.folder, 'Projects'),
  'Admin': (
    Icons.admin_panel_settings_outlined,
    Icons.admin_panel_settings,
    'Admin',
  ),
};

/// One-line description shown under each module card on the Home screen.
const Map<String, String> moduleTagline = {
  'HR': 'Team attendance, approvals & directory',
  'CRM': 'Leads, deals & customers',
  'Finance': 'Business overview & reports',
  'Stock': 'Items, warehouses & entries',
  'Sales': 'Quotations to delivery',
  'Purchase': 'Requests to receipts',
  'Manufacturing': 'Dashboard, BOMs & work orders',
  'Manufacturing Masters': 'Items, warehouses & workstations',
  'Projects': 'Projects, tasks & timesheets',
  'Admin': 'Roles & permissions',
};

/// A module tile for the Home screen grid: which module, how it looks, and the
/// route to open when tapped (its first visible destination — the dashboard
/// where the module has one).
@immutable
class HomeModuleCard {
  const HomeModuleCard({
    required this.module,
    required this.icon,
    required this.label,
    required this.tagline,
    required this.route,
  });
  final String module;
  final IconData icon;
  final String label;
  final String tagline;
  final String route;
}

/// Builds the Home module grid for [profile]: one card per module that has at
/// least one visible destination, opening that module's first destination
/// (its dashboard where present).
List<HomeModuleCard> homeModuleCards(Profile? profile) {
  final dests = destinationsFor(profile);
  final cards = <HomeModuleCard>[];
  for (final m in modulesIn(dests)) {
    final meta = moduleMeta[m];
    if (meta == null) continue;
    final first = dests.firstWhere((d) => d.module == m);
    cards.add(
      HomeModuleCard(
        module: m,
        icon: meta.$2,
        label: meta.$3,
        tagline: moduleTagline[m] ?? '',
        route: first.route,
      ),
    );
  }
  return cards;
}

/// Single source of truth for the app's primary destinations. Drives the
/// scrollable bottom nav (mobile) and the persistent side rail (tablet+).
const List<NavDest> _allDestinations = [
  NavDest(
    'core.home',
    'Home',
    Icons.dashboard_outlined,
    Icons.dashboard,
    Routes.home,
    null,
  ),
  // Personal self-service — these sit WITH Home (module == null), not inside
  // any module. Every employee reaches their own attendance, leave, expenses,
  // timesheet and payslips straight from Home.
  NavDest(
    'hr.my_attendance',
    'My Attendance',
    Icons.event_available_outlined,
    Icons.event_available,
    Routes.time,
    'attendance',
  ),
  NavDest(
    'hr.my_leave',
    'Leave',
    Icons.event_outlined,
    Icons.event,
    Routes.leave,
    'leave',
  ),
  NavDest(
    'hr.my_expenses',
    'My Expenses',
    Icons.receipt_long_outlined,
    Icons.receipt_long,
    Routes.expenses,
    'expense',
  ),
  NavDest(
    'projects.my_timesheet',
    'My Timesheet',
    Icons.access_time_outlined,
    Icons.access_time,
    Routes.timesheet,
    'timesheet',
  ),
  NavDest(
    'hr.my_payroll',
    'My Payroll',
    Icons.payments_outlined,
    Icons.payments,
    Routes.payroll,
    'payslip',
  ),
  // HR module — team / management views only (personal screens moved to Home).
  // Dashboard first so the module tile opens the overview.
  NavDest(
    'hr.dashboard',
    'Dashboard',
    Icons.space_dashboard_outlined,
    Icons.space_dashboard,
    Routes.hrDashboard,
    'hr_employee',
    'HR',
  ),
  NavDest(
    'hr.all_attendance',
    'All Attendance',
    Icons.groups_2_outlined,
    Icons.groups_2,
    Routes.allAttendance,
    'attendance_view_all',
    'HR',
  ),
  NavDest(
    'hr.pending_attendance',
    'Pending Attendance',
    Icons.pending_actions_outlined,
    Icons.pending_actions,
    Routes.pendingAttendance,
    'attendance_manage',
    'HR',
  ),
  NavDest(
    'hr.leaves',
    'Leaves',
    Icons.event_note_outlined,
    Icons.event_note,
    Routes.leaveManagement,
    'approvals',
    'HR',
  ),
  NavDest(
    'hr.expense_claims',
    'Expense Claims',
    Icons.request_quote_outlined,
    Icons.request_quote,
    Routes.expenseClaims,
    'approvals',
    'HR',
  ),
  NavDest(
    'hr.directory',
    'Directory',
    Icons.contacts_outlined,
    Icons.contacts,
    Routes.directory,
    'hr_employee',
    'HR',
  ),
  NavDest(
    'hr.shift_types',
    'Shift Types',
    Icons.schedule_outlined,
    Icons.schedule,
    Routes.hrShiftTypes,
    'hr_shift_type',
    'HR',
  ),
  NavDest(
    'hr.shift_assignments',
    'Shift Assignments',
    Icons.assignment_ind_outlined,
    Icons.assignment_ind,
    Routes.hrShiftAssignments,
    'hr_shift_assignment',
    'HR',
  ),
  NavDest(
    'hr.holiday_lists',
    'Holiday Lists',
    Icons.event_available_outlined,
    Icons.event_available,
    Routes.hrHolidayLists,
    'hr_holiday_list',
    'HR',
  ),
  NavDest(
    'hr.holiday_assignments',
    'Holiday Assignments',
    Icons.event_repeat_outlined,
    Icons.event_repeat,
    Routes.hrHolidayAssignments,
    'hr_holiday_assignment',
    'HR',
  ),
  NavDest(
    'hr.leave_policies',
    'Leave Policies',
    Icons.policy_outlined,
    Icons.policy,
    Routes.hrLeavePolicies,
    'hr_leave_policy',
    'HR',
  ),
  NavDest(
    'hr.policy_assignments',
    'Policy Assignments',
    Icons.assignment_turned_in_outlined,
    Icons.assignment_turned_in,
    Routes.hrLeavePolicyAssignments,
    'hr_leave_policy_assignment',
    'HR',
  ),
  NavDest(
    'hr.leave_allocation',
    'Leave Allocation',
    Icons.event_available_outlined,
    Icons.event_available,
    Routes.hrLeaveAllocations,
    'hr_leave_allocation',
    'HR',
  ),
  NavDest(
    'hr.all_payslips',
    'All Payslips',
    Icons.payments_outlined,
    Icons.payments,
    Routes.allPayslips,
    'payslip_view_all',
    'HR',
  ),
  NavDest(
    'crm.dashboard',
    'Dashboard',
    Icons.space_dashboard_outlined,
    Icons.space_dashboard,
    Routes.crmDashboard,
    'leads',
    'CRM',
  ),
  NavDest(
    'crm.leads',
    'Leads',
    Icons.person_search_outlined,
    Icons.person_search,
    Routes.leads,
    'leads',
    'CRM',
  ),
  NavDest(
    'crm.opportunities',
    'Opportunities',
    Icons.handshake_outlined,
    Icons.handshake,
    Routes.deals,
    'deals',
    'CRM',
  ),
  NavDest(
    'crm.customers',
    'Customers',
    Icons.storefront_outlined,
    Icons.storefront,
    Routes.salesCustomer,
    'sales_customer',
    'CRM',
  ),
  NavDest(
    'crm.performance',
    'Performance',
    Icons.insights_outlined,
    Icons.insights,
    Routes.pipeline,
    'sees_sales',
    'CRM',
  ),
  NavDest(
    'crm.team_chat',
    'Team Chat',
    Icons.forum_outlined,
    Icons.forum,
    Routes.teamChat,
    'sees_sales',
    'CRM',
  ),
  NavDest(
    'crm.team',
    'Team',
    Icons.groups_2_outlined,
    Icons.groups_2,
    Routes.teamStatus,
    'manager_view',
    'CRM',
  ),
  NavDest(
    'crm.calls',
    'Calls',
    Icons.call_outlined,
    Icons.call,
    Routes.callDetection,
    'sees_sales',
    'CRM',
  ),
  NavDest(
    'crm.recordings',
    'Recordings',
    Icons.graphic_eq_outlined,
    Icons.graphic_eq,
    Routes.recordings,
    'sees_sales',
    'CRM',
  ),
  // Finance is a business-overview dashboard + reports. The transactional
  // Invoices screen is gone; Payroll / Payslips moved to HR (salary is HR).
  NavDest(
    'finance.dashboard',
    'Dashboard',
    Icons.space_dashboard_outlined,
    Icons.space_dashboard,
    Routes.financeDashboard,
    'accounts_reports',
    'Finance',
  ),
  NavDest(
    'finance.reports',
    'Reports',
    Icons.assessment_outlined,
    Icons.assessment,
    Routes.accountsReports,
    'accounts_reports',
    'Finance',
  ),
  NavDest(
    'sales.dashboard',
    'Dashboard',
    Icons.space_dashboard_outlined,
    Icons.space_dashboard,
    Routes.salesDashboard,
    'sales_quotation',
    'Sales',
  ),
  NavDest(
    'sales.quotations',
    'Quotations',
    Icons.description_outlined,
    Icons.description,
    Routes.salesQuotation,
    'sales_quotation',
    'Sales',
  ),
  NavDest(
    'sales.sales_orders',
    'Sales Orders',
    Icons.point_of_sale_outlined,
    Icons.point_of_sale,
    Routes.salesOrder,
    'sales_order',
    'Sales',
  ),
  NavDest(
    'sales.delivery_notes',
    'Delivery Notes',
    Icons.local_shipping_outlined,
    Icons.local_shipping,
    Routes.salesDelivery,
    'sales_delivery',
    'Sales',
  ),
  NavDest(
    'sales.invoices',
    'Invoices',
    Icons.receipt_outlined,
    Icons.receipt,
    Routes.salesInvoices,
    'sales_invoice',
    'Sales',
  ),
  NavDest(
    'sales.payments',
    'Payments',
    Icons.payments_outlined,
    Icons.payments,
    Routes.salesPayments,
    'sales_invoice',
    'Sales',
  ),
  NavDest(
    'sales.reports',
    'Reports',
    Icons.assessment_outlined,
    Icons.assessment,
    Routes.salesReports,
    'sales_reports',
    'Sales',
  ),
  NavDest(
    'purchase.dashboard',
    'Dashboard',
    Icons.space_dashboard_outlined,
    Icons.space_dashboard,
    Routes.purchaseDashboard,
    'purchase_order',
    'Purchase',
  ),
  NavDest(
    'purchase.material_req',
    'Material Req',
    Icons.playlist_add_outlined,
    Icons.playlist_add,
    Routes.stockMaterialRequest,
    'purchase_material_request',
    'Purchase',
  ),
  NavDest(
    'purchase.rfq',
    'RFQ',
    Icons.request_quote_outlined,
    Icons.request_quote,
    Routes.purchaseRfq,
    'purchase_rfq',
    'Purchase',
  ),
  NavDest(
    'purchase.supplier_quotations',
    'Supplier Quotations',
    Icons.description_outlined,
    Icons.description,
    Routes.purchaseSupplierQuotation,
    'purchase_supplier_quotation',
    'Purchase',
  ),
  NavDest(
    'purchase.purchase_orders',
    'Purchase Orders',
    Icons.shopping_cart_outlined,
    Icons.shopping_cart,
    Routes.purchaseOrder,
    'purchase_order',
    'Purchase',
  ),
  NavDest(
    'purchase.goods_receipt',
    'Goods Receipt',
    Icons.local_shipping_outlined,
    Icons.local_shipping,
    Routes.purchaseReceipt,
    'purchase_receipt',
    'Purchase',
  ),
  NavDest(
    'purchase.invoices',
    'Invoices',
    Icons.receipt_outlined,
    Icons.receipt,
    Routes.purchaseInvoices,
    'purchase_invoice',
    'Purchase',
  ),
  NavDest(
    'purchase.payments',
    'Payments',
    Icons.payments_outlined,
    Icons.payments,
    Routes.purchasePayments,
    'purchase_invoice',
    'Purchase',
  ),
  NavDest(
    'purchase.suppliers',
    'Suppliers',
    Icons.storefront_outlined,
    Icons.storefront,
    Routes.purchaseSupplier,
    'purchase_supplier',
    'Purchase',
  ),
  NavDest(
    'purchase.reports',
    'Reports',
    Icons.assessment_outlined,
    Icons.assessment,
    Routes.purchaseReports,
    'purchase_reports',
    'Purchase',
  ),
  // Manufacturing: the production flow + dashboard. Dashboard first so the
  // module tile opens the flow overview.
  NavDest(
    'manufacturing.dashboard',
    'Dashboard',
    Icons.space_dashboard_outlined,
    Icons.space_dashboard,
    Routes.mfgDashboard,
    'mfg_work_order',
    'Manufacturing',
  ),
  NavDest(
    'manufacturing.bom',
    'BOM',
    Icons.account_tree_outlined,
    Icons.account_tree,
    Routes.mfgBom,
    'mfg_bom',
    'Manufacturing',
  ),
  NavDest(
    'manufacturing.work_orders',
    'Work Orders',
    Icons.precision_manufacturing_outlined,
    Icons.precision_manufacturing,
    Routes.mfgWorkOrder,
    'mfg_work_order',
    'Manufacturing',
  ),
  NavDest(
    'manufacturing.job_cards',
    'Job Cards',
    Icons.assignment_outlined,
    Icons.assignment,
    Routes.mfgJobCard,
    'mfg_job_card',
    'Manufacturing',
  ),
  NavDest(
    'manufacturing.prod_plan',
    'Prod. Plan',
    Icons.event_note_outlined,
    Icons.event_note,
    Routes.mfgProductionPlan,
    'mfg_production_plan',
    'Manufacturing',
  ),
  NavDest(
    'manufacturing.stock_entry',
    'Stock Entry',
    Icons.swap_horiz_outlined,
    Icons.swap_horiz,
    Routes.stockEntry,
    'stock_entry',
    'Manufacturing',
  ),
  NavDest(
    'manufacturing.reports',
    'Reports',
    Icons.assessment_outlined,
    Icons.assessment,
    Routes.stockReports,
    'stock_reports',
    'Manufacturing',
  ),
  // Manufacturing Masters: Items, Warehouses, Workstations.
  NavDest(
    'manufacturing.items',
    'Items',
    Icons.inventory_2_outlined,
    Icons.inventory_2,
    Routes.stock,
    'stock_item',
    'Manufacturing Masters',
  ),
  NavDest(
    'manufacturing.warehouses',
    'Warehouses',
    Icons.warehouse_outlined,
    Icons.warehouse,
    Routes.stockWarehouse,
    'stock_warehouse',
    'Manufacturing Masters',
  ),
  NavDest(
    'manufacturing.workstations',
    'Workstations',
    Icons.hardware_outlined,
    Icons.hardware,
    Routes.mfgWorkstation,
    'mfg_workstation',
    'Manufacturing Masters',
  ),
  // Projects: dashboard first so the module tile opens the overview.
  NavDest(
    'projects.dashboard',
    'Dashboard',
    Icons.space_dashboard_outlined,
    Icons.space_dashboard,
    Routes.projectsDashboard,
    'projects_project',
    'Projects',
  ),
  NavDest(
    'projects.projects',
    'Projects',
    Icons.folder_open_outlined,
    Icons.folder,
    Routes.projectsProject,
    'projects_project',
    'Projects',
  ),
  NavDest(
    'projects.tasks',
    'Tasks',
    Icons.task_alt_outlined,
    Icons.task_alt,
    Routes.tasks,
    'task',
    'Projects',
  ),
  NavDest(
    'projects.all_timesheets',
    'All Timesheets',
    Icons.groups_2_outlined,
    Icons.groups_2,
    Routes.allTimesheets,
    'timesheet_view_all',
    'Projects',
  ),
  NavDest(
    'core.admin',
    'Admin',
    Icons.admin_panel_settings_outlined,
    Icons.admin_panel_settings,
    Routes.admin,
    'admin',
    'Admin',
  ),
];

/// A screen that has no nav tab of its own but is opened from inside a module
/// (a dashboard chip, an app-bar button). It still gets its own on/off switch
/// in Admin > Screens, and switching it off hides its entry points too.
@immutable
class SubScreen {
  const SubScreen(
    this.id,
    this.label,
    this.icon,
    this.routes, {
    this.routePrefixes = const [],
  });

  /// Same `<licence module>.<screen>` form as [NavDest.id].
  final String id;
  final String label;
  final IconData icon;

  /// Exact routes this screen owns.
  final List<String> routes;

  /// Routes with a path parameter, matched as `<prefix>/...`.
  final List<String> routePrefixes;

  bool owns(String loc) =>
      routes.contains(loc) || routePrefixes.any((p) => loc.startsWith('$p/'));
}

const List<SubScreen> _subScreens = [
  SubScreen(
    'hr.leave_rules',
    'Leave Notice Rules',
    Icons.rule_folder_outlined,
    [Routes.leaveNoticeRules],
  ),
  SubScreen('crm.kanban', 'Kanban Board', Icons.view_kanban_outlined, [
    Routes.leadKanban,
  ]),
  SubScreen('crm.leaderboard', 'Leaderboard', Icons.emoji_events_outlined, [
    Routes.leaderboard,
  ]),
  SubScreen(
    'crm.field_team',
    'Field Team Map',
    Icons.map_outlined,
    [Routes.locationTeam, Routes.locationTeamMap],
    routePrefixes: ['/location/person'],
  ),
  SubScreen(
    'crm.missed_activities',
    'Missed Activities',
    Icons.history_toggle_off_outlined,
    [Routes.missedActivities],
  ),
];

/// Every destination, regardless of licence / settings / role — the catalogue
/// the admin's Screens page lists.
List<NavDest> get allDestinations => _allDestinations;

/// In-module screens without a nav tab, also listed in Admin > Screens.
List<SubScreen> get allSubScreens => _subScreens;

/// Module + screen layers for [id]; true when no profile is loaded yet. Use it
/// to hide buttons that open a [SubScreen].
bool screenOn(Profile? profile, String id) =>
    profile?.screenEnabled(id) ?? true;

/// Destinations [profile] may see: the screen's module is licensed, the admin
/// has not switched it off, and the user's role allows it.
List<NavDest> destinationsFor(Profile? profile) {
  if (profile == null) return _allDestinations;
  return _allDestinations
      .where(
        (d) =>
            profile.screenEnabled(d.id) &&
            (d.cap == null || profile.can(d.cap!)),
      )
      .toList();
}

/// Routes switched off for [profile] by the module or screen layer (not by
/// role). The router sends these back to Home so a deep link or a stale push
/// cannot open a screen the company has disabled. A route that some enabled
/// destination also uses stays open.
Set<String> blockedRoutesFor(Profile? profile) {
  if (profile == null) return const {};
  final open = <String>{};
  final off = <String>{};
  for (final d in _allDestinations) {
    (profile.screenEnabled(d.id) ? open : off).add(d.route);
  }
  return off.difference(open);
}

/// True when [loc] belongs to a screen switched off (or unlicensed) for
/// [profile]: a nav destination, one of its child routes, or a [SubScreen].
bool isRouteBlocked(Profile? profile, String loc) {
  if (profile == null) return false;
  if (blockedRoutesFor(profile).any((r) => isInBranch(r, loc))) return true;
  return _subScreens.any((s) => !profile.screenEnabled(s.id) && s.owns(loc));
}

/// Distinct module keys present in [dests], in first-seen order.
List<String> modulesIn(List<NavDest> dests) {
  final seen = <String>{};
  final order = <String>[];
  for (final d in dests) {
    final m = d.module;
    if (m != null && seen.add(m)) order.add(m);
  }
  return order;
}

/// The module the current route belongs to, or null if it's a top-level
/// (module == null) destination such as Home.
String? activeModuleFor(List<NavDest> dests, String currentRoute) {
  for (final d in dests) {
    if (isInBranch(d.route, currentRoute)) return d.module;
  }
  return null;
}

/// Treat sub-routes as belonging to their parent for highlight purposes.
bool isInBranch(String dest, String current) {
  if (current == dest) return true;
  const childMap = {
    Routes.payroll: [Routes.payslipDetail],
    Routes.leads: [Routes.leadDetail],
    Routes.deals: [Routes.dealDetail],
    Routes.timesheet: [Routes.timesheetDetail],
    Routes.invoices: [Routes.invoiceDetail],
    Routes.leave: [Routes.leaveDetail],
    Routes.stock: [Routes.stockItemDetail],
    // The CRM "Funnel" tab owns the Kanban board; "Team" owns leaderboard +
    // field-team, all pushed above the shell but still highlight their tab.
    Routes.pipeline: [Routes.leadKanban],
    Routes.teamStatus: [
      Routes.leaderboard,
      Routes.locationTeam,
      Routes.locationTeamMap,
    ],
  };
  return childMap[dest]?.contains(current) ?? false;
}
