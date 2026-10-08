import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/attendance/presentation/attendance_roster_screen.dart';
import '../../features/attendance/presentation/on_leave_screen.dart';
import '../../features/attendance/presentation/pending_attendance_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/lock_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/unlock_screen.dart';
import '../../features/dashboard/presentation/crm_dashboard_screen.dart';
import '../../features/dashboard/presentation/sales_dashboard_screen.dart';
import '../../features/dashboard/presentation/purchase_dashboard_screen.dart';
import '../../features/deals/presentation/deal_detail_screen.dart';
import '../../features/deals/presentation/deals_screen.dart';
import '../../features/directory/presentation/directory_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/expenses/presentation/expense_claims_screen.dart';
import '../../features/invoices/presentation/invoice_detail_screen.dart';
import '../../features/invoices/presentation/invoices_screen.dart';
import '../../features/home/presentation/app_shell.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/nav_destinations.dart';
import '../../features/leads/presentation/lead_detail_screen.dart';
import '../../features/leads/presentation/leads_screen.dart';
import '../../features/leave/presentation/leave_detail_screen.dart';
import '../../features/leave/presentation/leave_approvals_screen.dart';
import '../../features/leave/presentation/leave_screen.dart';
import '../../features/leave/presentation/leave_management_screen.dart';
import '../../features/leave/presentation/leave_policy_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/missed_activities/presentation/missed_activities_screen.dart';
import '../../features/performance/presentation/performance_screen.dart';
import '../../features/manufacturing/presentation/manufacturing_dashboard_screen.dart';
import '../../features/dashboard/presentation/finance_dashboard_screen.dart';
import '../../features/dashboard/presentation/projects_dashboard_screen.dart';
import '../../features/dashboard/presentation/hr_dashboard_screen.dart';
import '../../features/team_chat/presentation/team_chat_screen.dart';
import '../../features/team_chat/presentation/chat_thread_screen.dart';
import '../../features/team_chat/domain/models.dart' show ChatChannel;
import '../../features/team_status/presentation/team_status_screen.dart';
import '../../features/call_detection/presentation/call_detection_screen.dart';
import '../../features/call_detection/presentation/recordings_screen.dart';
import '../../features/leads_kanban/presentation/kanban_screen.dart';
import '../../features/location_tracking/presentation/person_location_screen.dart';
import '../../features/location_tracking/presentation/team_live_list_screen.dart';
import '../../features/location_tracking/presentation/team_live_map_screen.dart';
import '../../features/sales_workspace/presentation/sales_workspace_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/reports/presentation/reports_hub_screen.dart';
import '../../features/reports/presentation/report_view_screen.dart';
import '../../features/records/domain/descriptor.dart';
import '../../features/records/presentation/record_list_screen.dart';
import '../../features/records/presentation/record_detail_screen.dart';
import '../../features/stock/presentation/items_screen.dart';
import '../../features/stock/presentation/item_detail_screen.dart';
import '../../features/stock/presentation/item_create_screen.dart';
import '../../features/stock/presentation/item_edit_screen.dart';
import '../../features/stock/domain/models.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/payslips/presentation/all_payslips_screen.dart';
import '../../features/payslips/presentation/payslip_detail_screen.dart';
import '../../features/payslips/presentation/payslips_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/email_settings/presentation/email_settings_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/timesheet/presentation/all_timesheets_screen.dart';
import '../../features/timesheet/presentation/timesheet_detail_screen.dart';
import '../../features/timesheet/presentation/timesheet_screen.dart';
import '../config/app_config.dart';
import 'dashboard_refresh.dart';

class Routes {
  Routes._();
  static const splash = '/splash';
  static const login = '/login';
  static const unlock = '/unlock';

  // All top-level destinations - drawer + side-rail navigation; no nested "More".
  static const home = '/home';
  static const time = '/time';
  static const leave = '/leave';
  static const payroll = '/payroll';
  static const tasks = '/tasks';
  static const timesheet = '/timesheet';
  static const allTimesheets = '/hr/all-timesheets';
  static const expenses = '/expenses';
  static const expenseClaims = '/hr/expense-claims';
  static const crmDashboard = '/crm/dashboard';
  static const leads = '/leads';
  static const deals = '/deals';
  static const salesDashboard = '/sales/dashboard';
  static const financeDashboard = '/finance/dashboard';
  static const directory = '/directory';
  static const invoices = '/invoices';
  static const stock = '/stock';
  static const admin = '/admin';
  // Manufacturing
  static const mfgDashboard = '/mfg/dashboard';
  static const mfgBom = '/mfg/bom';
  static const mfgWorkOrder = '/mfg/work-order';
  static const mfgJobCard = '/mfg/job-card';
  static const mfgProductionPlan = '/mfg/production-plan';
  static const mfgWorkstation = '/mfg/workstation';
  // Stock (transactional + masters)
  static const stockWarehouse = '/stock/warehouse';
  static const stockMaterialRequest = '/stock/material-request';
  static const stockEntry = '/stock/entry';
  // Purchase
  static const purchaseDashboard = '/purchase/dashboard';
  static const purchaseSupplier = '/purchase/supplier';
  static const purchaseRfq = '/purchase/rfq';
  static const purchaseSupplierQuotation = '/purchase/supplier-quotation';
  static const purchaseOrder = '/purchase/order';
  static const purchaseReceipt = '/purchase/receipt';
  static const purchaseInvoices = '/purchase/invoices';
  static const purchasePayments = '/purchase/payments';
  static const salesCustomer = '/sales/customer';
  // Sales-scoped billing (sales invoices + customer receipts)
  static const salesInvoices = '/sales/invoices';
  static const salesPayments = '/sales/payments';
  // Reports hubs (curated ERPNext reports, per-report role gated)
  static const accountsReports = '/accounts/reports';
  static const salesReports = '/sales/reports';
  static const purchaseReports = '/purchase/reports';
  static const stockReports = '/stock/reports';
  static const reportView = '/report-view';
  static const salesQuotation = '/sales/quotation';
  static const salesOrder = '/sales/order';
  static const salesDelivery = '/sales/delivery';
  // HR
  static const hrDashboard = '/hr/dashboard';
  static const hrEmployees = '/hr/employees';
  static const allAttendance = '/hr/all-attendance';
  static const onLeave = '/hr/on-leave';
  static const allPayslips = '/finance/all-payslips';
  static const hrAttendance = '/hr/attendance-management';
  // HR: employees whose attendance still needs a manual decision (no check-out
  // or no check-in and not on leave).
  static const pendingAttendance = '/hr/pending-attendance';
  // HR masters managed from the portal (generic record screens).
  static const hrShiftTypes = '/hr/shift-types';
  static const hrShiftAssignments = '/hr/shift-assignments';
  static const hrHolidayLists = '/hr/holiday-lists';
  static const hrLeavePolicies = '/hr/leave-policies';
  static const hrLeavePolicyAssignments = '/hr/leave-policy-assignments';
  static const hrLeaveAllocations = '/hr/leave-allocations';
  static const hrHolidayAssignments = '/hr/holiday-assignments';
  // HR Leaves management (Applications + Leave Requests + Comp-Off + WFH).
  // Replaces the old standalone Approval Requests screen.
  static const leaveManagement = '/hr/leaves';
  // HR-configurable leave notice-period rules (opened from the Leaves screen).
  static const leaveNoticeRules = '/hr/leave-policy';
  // Projects
  static const projectsDashboard = '/projects/dashboard';
  static const projectsProject = '/projects/project';
  // Shared generic record detail
  static const recordDetail = '/record-detail';

  // Sub-routes pushed inside a branch
  static const payslipDetail = '/payslip-detail';
  static const leadDetail = '/lead-detail';
  static const dealDetail = '/deal-detail';
  static const timesheetDetail = '/timesheet-detail';
  static const invoiceDetail = '/invoice-detail';
  static const stockItemDetail = '/stock-item-detail';
  static const stockItemCreate = '/stock-item-create';
  static const stockItemEdit = '/stock-item-edit';
  static const leaveDetail = '/leave-detail';
  static const leaveApprovals = '/leave-approvals';
  static const profile = '/profile';
  static const emailSettings = '/email-settings';
  static const notifications = '/notifications';
  static const missedActivities = '/missed-activities';
  static const leaderboard = '/leaderboard';
  static const pipeline = '/pipeline';
  static const teamChat = '/team-chat';
  static const chatThread = '/team-chat/thread';
  static const teamStatus = '/team-status';
  static const callDetection = '/call-detection';
  static const recordings = '/recordings';
  static const leadKanban = '/lead-kanban';
  static const salesWorkspace = '/sales-workspace';
  // Live location tracking (Phase LOC.1)
  static const locationTeam = '/location/team'; // list view (landing)
  static const locationTeamMap = '/location/team/map'; // map of all pins
  static const locationPerson = '/location/person/:employee';

  // Legacy aliases (kept so old strings still resolve)
  static const attendance = time;
  static const payslips = payroll;
  static const more = home;
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final unlocked = ref.read(sessionUnlockedProvider);
      final loc = state.matchedLocation;

      switch (auth.status) {
        case AuthStatus.unknown:
          return loc == Routes.splash ? null : Routes.splash;
        case AuthStatus.unauthenticated:
          return loc == Routes.login ? null : Routes.login;
        case AuthStatus.authenticated:
          final mustUnlock = AppConfig.biometricLockEnabled && !unlocked;
          if (mustUnlock) return loc == Routes.unlock ? null : Routes.unlock;
          const transient = {Routes.splash, Routes.login, Routes.unlock};
          if (transient.contains(loc)) return Routes.home;
          // Module / screen layers: a screen the company has switched off
          // (or not licensed) never opens, even from a deep link or push.
          if (isRouteBlocked(auth.profile, loc)) return Routes.home;
          return null;
      }
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.unlock, builder: (_, _) => const UnlockScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.time,
                builder: (_, _) => const AttendanceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.allAttendance,
                builder: (_, _) => const AttendanceRosterScreen(
                  title: 'All Attendance',
                  canManage: false,
                ),
              ),
              GoRoute(
                path: Routes.onLeave,
                builder: (_, _) => const OnLeaveScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.hrAttendance,
                builder: (_, _) => const AttendanceRosterScreen(
                  title: 'Attendance Management',
                  canManage: true,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.pendingAttendance,
                builder: (_, _) => const PendingAttendanceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.leave,
                builder: (_, _) => const LeaveScreen(),
              ),
              GoRoute(
                path: Routes.leaveDetail,
                builder: (_, state) =>
                    LeaveDetailScreen(name: state.extra! as String),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.leaveManagement,
                // `?tab=` deep-links to a section: 0 Applications, 1 Requests,
                // 2 Comp-Off, 3 WFH. `?status=` pre-sets the Applications filter
                // (e.g. pending) for the dashboard "Pending Leaves" card.
                builder: (_, state) => LeaveManagementScreen(
                  initialTab:
                      int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
                  initialStatus: state.uri.queryParameters['status'],
                ),
              ),
              GoRoute(
                path: Routes.leaveNoticeRules,
                builder: (_, _) => const LeavePolicyScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.payroll,
                builder: (_, _) => const PayslipsScreen(),
              ),
              GoRoute(
                path: Routes.payslipDetail,
                builder: (_, state) =>
                    PayslipDetailScreen(name: state.extra! as String),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.allPayslips,
                builder: (_, _) => const AllPayslipsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tasks,
                builder: (_, _) => const TasksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.timesheet,
                builder: (_, _) => const TimesheetScreen(),
              ),
              GoRoute(
                path: Routes.timesheetDetail,
                builder: (_, state) =>
                    TimesheetDetailScreen(name: state.extra! as String),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.allTimesheets,
                builder: (_, _) => const AllTimesheetsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.expenses,
                builder: (_, _) => const ExpensesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.expenseClaims,
                // `?tab=` deep-links to a section: 0 Claims, 1 Requests.
                // `?filter=` pre-selects the Claims status chip, e.g. 'pending'.
                builder: (_, state) => ExpenseClaimsScreen(
                  initialTab:
                      int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
                  initialFilter: state.uri.queryParameters['filter'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.crmDashboard,
                builder: (_, _) => const CrmDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.salesDashboard,
                builder: (_, _) => const SalesDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.leads,
                builder: (_, _) => const LeadsScreen(),
              ),
              GoRoute(
                path: Routes.leadDetail,
                builder: (_, state) =>
                    LeadDetailScreen(name: state.extra! as String),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.deals,
                builder: (_, _) => const DealsScreen(),
              ),
              GoRoute(
                path: Routes.dealDetail,
                builder: (_, state) =>
                    DealDetailScreen(name: state.extra! as String),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.directory,
                builder: (_, _) => const DirectoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.invoices,
                builder: (_, _) => const InvoicesScreen(),
              ),
            ],
          ),
          // Sales-scoped billing: sales invoices and customer receipts are
          // separate screens (own routes / bottom-nav tabs), not tabs in one.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.salesInvoices,
                builder: (_, _) => const InvoicesScreen(
                  scope: InvoiceScope.sales,
                  pane: InvoicePane.invoices,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.salesPayments,
                builder: (_, _) => const InvoicesScreen(
                  scope: InvoiceScope.sales,
                  pane: InvoicePane.payments,
                ),
              ),
            ],
          ),
          // Purchase-scoped billing: purchase invoices and supplier payments,
          // likewise as two separate screens.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.purchaseInvoices,
                builder: (_, _) => const InvoicesScreen(
                  scope: InvoiceScope.purchase,
                  pane: InvoicePane.invoices,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.purchasePayments,
                builder: (_, _) => const InvoicesScreen(
                  scope: InvoiceScope.purchase,
                  pane: InvoicePane.payments,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.purchaseDashboard,
                builder: (_, _) => const PurchaseDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.financeDashboard,
                builder: (_, _) => const FinanceDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.projectsDashboard,
                builder: (_, _) => const ProjectsDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.hrDashboard,
                builder: (_, _) => const HrDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.stock,
                builder: (_, _) => const ItemsScreen(),
              ),
              GoRoute(
                path: Routes.stockItemDetail,
                builder: (_, state) =>
                    ItemDetailScreen(name: state.extra! as String),
              ),
              GoRoute(
                path: Routes.stockItemCreate,
                builder: (_, _) => const ItemCreateScreen(),
              ),
              GoRoute(
                path: Routes.stockItemEdit,
                builder: (_, state) =>
                    ItemEditScreen(item: state.extra! as ItemDetail),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.admin,
                builder: (_, _) => const AdminScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.mfgDashboard,
                builder: (_, _) => const ManufacturingDashboardScreen(),
              ),
            ],
          ),
          _recordBranch(Routes.mfgBom, 'mfg_bom'),
          _recordBranch(Routes.mfgWorkOrder, 'mfg_work_order'),
          _recordBranch(Routes.mfgJobCard, 'mfg_job_card'),
          _recordBranch(Routes.mfgProductionPlan, 'mfg_production_plan'),
          _recordBranch(Routes.mfgWorkstation, 'mfg_workstation'),
          _recordBranch(Routes.hrEmployees, 'hr_employee'),
          _recordBranch(Routes.hrShiftTypes, 'hr_shift_type'),
          _recordBranch(Routes.hrShiftAssignments, 'hr_shift_assignment'),
          _recordBranch(Routes.hrHolidayLists, 'hr_holiday_list'),
          _recordBranch(Routes.hrLeavePolicies, 'hr_leave_policy'),
          _recordBranch(
            Routes.hrLeavePolicyAssignments,
            'hr_leave_policy_assignment',
          ),
          _recordBranch(Routes.hrLeaveAllocations, 'hr_leave_allocation'),
          _recordBranch(Routes.hrHolidayAssignments, 'hr_holiday_assignment'),
          _recordBranch(Routes.projectsProject, 'projects_project'),
          _recordBranch(Routes.stockWarehouse, 'stock_warehouse'),
          _recordBranch(Routes.stockMaterialRequest, 'stock_material_request'),
          _recordBranch(Routes.stockEntry, 'stock_entry'),
          _recordBranch(Routes.purchaseSupplier, 'purchase_supplier'),
          _recordBranch(Routes.purchaseRfq, 'purchase_rfq'),
          _recordBranch(
            Routes.purchaseSupplierQuotation,
            'purchase_supplier_quotation',
          ),
          _recordBranch(Routes.purchaseOrder, 'purchase_order'),
          _recordBranch(Routes.purchaseReceipt, 'purchase_receipt'),
          _recordBranch(Routes.salesCustomer, 'sales_customer'),
          _recordBranch(Routes.salesQuotation, 'sales_quotation'),
          _recordBranch(Routes.salesOrder, 'sales_order'),
          _recordBranch(Routes.salesDelivery, 'sales_delivery'),
          _reportsBranch(
            Routes.accountsReports,
            'Accounts',
            'Accounts Reports',
          ),
          _reportsBranch(Routes.salesReports, 'Sales', 'Sales Reports'),
          _reportsBranch(
            Routes.purchaseReports,
            'Purchase',
            'Purchase Reports',
          ),
          _reportsBranch(Routes.stockReports, 'Stock', 'Stock Reports'),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.recordings,
                builder: (_, _) => const RecordingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.recordDetail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            RecordDetailScreen(args: state.extra! as RecordArgs),
      ),
      GoRoute(
        path: Routes.reportView,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            ReportViewScreen(args: state.extra! as ReportViewArgs),
      ),
      GoRoute(
        path: Routes.invoiceDetail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final args = state.extra! as InvoiceDetailArgs;
          return InvoiceDetailScreen(name: args.name, kind: args.kind);
        },
      ),
      GoRoute(
        path: Routes.profile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: Routes.emailSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const EmailSettingsScreen(),
      ),
      GoRoute(
        path: Routes.leaveApprovals,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const LeaveApprovalsScreen(),
      ),
      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: Routes.missedActivities,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const MissedActivitiesScreen(),
      ),
      GoRoute(
        path: Routes.leaderboard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: Routes.pipeline,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PerformanceScreen(),
      ),
      GoRoute(
        path: Routes.teamChat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const TeamChatScreen(),
      ),
      GoRoute(
        path: Routes.chatThread,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            ChatThreadScreen(channel: state.extra! as ChatChannel),
      ),
      GoRoute(
        path: Routes.teamStatus,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const TeamStatusScreen(),
      ),
      GoRoute(
        path: Routes.callDetection,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const CallDetectionScreen(),
      ),
      GoRoute(
        path: Routes.leadKanban,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const LeadKanbanScreen(),
      ),
      GoRoute(
        path: Routes.salesWorkspace,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SalesWorkspaceScreen(),
      ),
      GoRoute(
        path: Routes.locationTeam,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const TeamLiveListScreen(),
      ),
      GoRoute(
        path: Routes.locationTeamMap,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const TeamLiveMapScreen(),
      ),
      GoRoute(
        path: Routes.locationPerson,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => PersonLocationScreen(
          employee: Uri.decodeComponent(state.pathParameters['employee'] ?? ''),
        ),
      ),
    ],
  );

  // Keep the roll-up dashboards fresh: whenever the visible top-level route
  // changes to a dashboard, re-fetch its data so the user never has to pull to
  // refresh. Guarded by `lastPath` so a rebuild that keeps the same route does
  // not re-fetch.
  String? lastPath;
  void onRouteChanged() {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (path == lastPath) return;
    lastPath = path;
    refreshDashboardFor(ref, path);
  }

  router.routerDelegate.addListener(onRouteChanged);
  ref.onDispose(() => router.routerDelegate.removeListener(onRouteChanged));
  return router;
});

/// A shell branch that hosts a generic [RecordListScreen] for the descriptor
/// registered under [key]. Keeps the router terse as modules grow.
StatefulShellBranch _recordBranch(String path, String key) {
  final descriptor = recordRegistry[key]!;
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (_, _) => RecordListScreen(descriptor: descriptor),
      ),
    ],
  );
}

/// A shell branch that hosts the [ReportsHubScreen] for one backend module
/// (Accounts/Sales/Purchase/Stock). The hub lists only the reports the user is
/// permitted to run.
StatefulShellBranch _reportsBranch(String path, String module, String title) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (_, _) => ReportsHubScreen(module: module, title: title),
      ),
    ],
  );
}

/// Bridges Riverpod state changes to GoRouter's redirect re-evaluation.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(sessionUnlockedProvider, (_, _) => notifyListeners());
  }
}
