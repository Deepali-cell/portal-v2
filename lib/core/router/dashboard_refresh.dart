import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/attendance/application/attendance_controller.dart';
import '../../features/dashboard/data/dashboard_repository.dart'
    show salesDashboardProvider;
import '../../features/leaderboard/application/leaderboard_controller.dart'
    show leaderboardProvider;
import '../../features/leave/application/leave_controller.dart';
import '../../features/location_tracking/data/location_tracking_repository.dart'
    show teamLiveProvider;
import '../../features/notifications/application/notifications_controller.dart'
    show notificationsListProvider, unreadCountProvider;
import '../../features/payslips/application/payslip_controller.dart'
    show payslipListProvider;
import '../../features/pipeline/application/pipeline_controller.dart'
    show pipelineSnapshotProvider;
import '../../features/role_dashboards/data/role_dashboards_repository.dart'
    show hrSummaryProvider, projectsSummaryProvider, accountsSummaryProvider;
import '../../features/team_status/application/team_status_controller.dart'
    show teamStatusProvider;
import '../../features/todays_plan/application/todays_plan_controller.dart'
    show todaysPlanControllerProvider;
import 'app_router.dart';

/// Keeps the aggregate dashboards live without a manual refresh.
///
/// The dashboards (Home, Sales workspace, Pipeline, Leaderboard, Team status,
/// Notifications) show numbers rolled up on the server, so a change made on
/// another screen does not reach them on its own. This is wired to a GoRouter
/// location listener: the moment the user lands on one of these routes - by
/// switching tabs OR by returning from a drilled-in detail - its data is
/// re-fetched. Every other screen already refreshes itself after the user's
/// own action, so only these roll-up screens need this.
///
/// Invalidating a provider nobody is watching is a no-op, so this is cheap and
/// safe; the pull-to-refresh and the refresh buttons still work as before.
void refreshDashboardFor(Ref ref, String path) {
  switch (path) {
    case Routes.home:
      ref.invalidate(salesDashboardProvider);
      ref.invalidate(hrSummaryProvider);
      ref.invalidate(projectsSummaryProvider);
      ref.invalidate(accountsSummaryProvider);
      ref.invalidate(teamLiveProvider);
      ref.invalidate(todaysPlanControllerProvider);
      ref.invalidate(attendanceControllerProvider);
      ref.invalidate(leaveControllerProvider);
      ref.invalidate(payslipListProvider);
      ref.invalidate(unreadCountProvider);
      break;
    case Routes.salesWorkspace:
      ref.invalidate(salesDashboardProvider);
      break;
    case Routes.pipeline:
      ref.invalidate(pipelineSnapshotProvider);
      break;
    case Routes.leaderboard:
      ref.invalidate(leaderboardProvider);
      break;
    case Routes.teamStatus:
      ref.invalidate(teamStatusProvider);
      break;
    case Routes.notifications:
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadCountProvider);
      break;
  }
}
