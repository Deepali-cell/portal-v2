import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/leave_repository.dart';
import '../domain/models.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => LeaveRepository(ref.watch(dioProvider)),
);

final leaveControllerProvider =
    AsyncNotifierProvider<LeaveController, LeaveContext>(LeaveController.new);

class LeaveController extends AsyncNotifier<LeaveContext> {
  @override
  Future<LeaveContext> build() =>
      ref.read(leaveRepositoryProvider).getContext();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(leaveRepositoryProvider).getContext(),
    );
  }

  /// Submits a new request then refreshes. Throws [ApiException] on rejection.
  Future<void> apply(LeaveRequest request) async {
    await ref.read(leaveRepositoryProvider).apply(request);
    await reload();
  }

  /// Submits a Compensatory Leave Request (comp-off claim) then refreshes.
  /// Throws [ApiException] on rejection.
  Future<void> applyCompOff(CompOffRequest request) async {
    await ref.read(leaveRepositoryProvider).applyCompOff(request);
    await reload();
  }

  /// Approve or reject one request. Refreshes both the approvals list and the
  /// leave context, since the pending count on the leave screen changes too.
  Future<void> actOnApplication({
    required String name,
    required String action,
    String? reason,
  }) async {
    await ref
        .read(leaveRepositoryProvider)
        .actOnApplication(name: name, action: action, reason: reason);
    ref.invalidate(pendingLeaveApprovalsProvider);
    await reload();
  }

  /// Approve or reject one comp-off request, then refresh the comp-off
  /// approvals list and the leave context (its pending count changes too).
  Future<void> actOnCompOff({
    required String name,
    required String action,
    String? reason,
  }) async {
    await ref
        .read(leaveRepositoryProvider)
        .actOnCompOff(name: name, action: action, reason: reason);
    ref.invalidate(pendingCompOffApprovalsProvider);
    await reload();
  }

  /// Submits a Work From Home request, then refreshes the caller's own WFH
  /// list. Throws [ApiException] on rejection.
  Future<void> applyWfh(WfhRequest request) async {
    await ref.read(leaveRepositoryProvider).applyWfh(request);
    ref.invalidate(myWfhProvider);
  }

  /// Approve or reject one WFH request, then refresh the WFH approvals list.
  Future<void> actOnWfh({
    required String name,
    required String action,
    String? reason,
  }) async {
    await ref
        .read(leaveRepositoryProvider)
        .actOnWfh(name: name, action: action, reason: reason);
    ref.invalidate(pendingWfhApprovalsProvider);
  }
}

/// Date window for the HR "all leave applications" listing. Equality on the
/// record lets it key a family provider so changing the range refetches.
typedef LeaveApplicationsRange = ({DateTime from, DateTime to});

/// Every leave application overlapping a window (HR/admin see everyone's,
/// others their own). Drives the HR module's Leaves screen; separate from
/// [leaveControllerProvider] so the employee self-service screen is untouched.
final allLeaveApplicationsProvider = FutureProvider.autoDispose
    .family<List<LeaveApplication>, LeaveApplicationsRange>(
      (ref, r) => ref
          .read(leaveRepositoryProvider)
          .getAllApplications(from: r.from, to: r.to),
    );

/// Every comp-off request overlapping a window (HR/admin see everyone's, others
/// their own). Drives the Compensatory tab's management list.
final allCompOffProvider = FutureProvider.autoDispose
    .family<List<CompOffApplication>, LeaveApplicationsRange>(
      (ref, r) => ref
          .read(leaveRepositoryProvider)
          .getAllCompOff(from: r.from, to: r.to),
    );

/// On-demand detail for a single Leave Application.
final leaveApplicationDetailProvider =
    FutureProvider.family<LeaveApplicationDetail, String>(
      (ref, name) =>
          ref.read(leaveRepositoryProvider).getApplicationDetail(name),
    );

/// Requests waiting on the signed in user, as manager or as HR.
final pendingLeaveApprovalsProvider =
    FutureProvider<List<PendingLeaveApproval>>(
      (ref) => ref.read(leaveRepositoryProvider).getPendingApprovals(),
    );

/// Comp-off requests waiting on the signed in user, as manager or as HR.
final pendingCompOffApprovalsProvider =
    FutureProvider<List<PendingCompOffApproval>>(
      (ref) => ref.read(leaveRepositoryProvider).getCompOffPendingApprovals(),
    );

/// The signed-in user's own Work From Home requests (self-service history).
final myWfhProvider = FutureProvider<List<WfhSummary>>(
  (ref) => ref.read(leaveRepositoryProvider).getMyWfh(),
);

/// WFH requests waiting on the signed in user, as manager or as HR.
final pendingWfhApprovalsProvider = FutureProvider<List<PendingWfhApproval>>(
  (ref) => ref.read(leaveRepositoryProvider).getWfhPendingApprovals(),
);

/// HR-configurable leave notice-period rules (with the leave types for the
/// picker). HR/admin only; drives the Leave Policy configuration screen.
final leaveNoticeRulesProvider =
    FutureProvider.autoDispose<
      ({List<LeaveNoticeRule> rules, List<String> leaveTypes})
    >((ref) => ref.read(leaveRepositoryProvider).listNoticeRules());
