import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/timesheet_repository.dart';
import '../domain/models.dart';

final timesheetRepositoryProvider = Provider<TimesheetRepository>(
    (ref) => TimesheetRepository(ref.watch(dioProvider)));

final timesheetControllerProvider =
    AsyncNotifierProvider<TimesheetController, TimesheetContext>(
        TimesheetController.new);

class TimesheetController extends AsyncNotifier<TimesheetContext> {
  DateTime? _from;
  DateTime? _to;

  DateTime get from {
    final f = _from;
    if (f != null) return f;
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  DateTime get to {
    final t = _to;
    if (t != null) return t;
    return DateTime.now();
  }

  @override
  Future<TimesheetContext> build() =>
      ref.read(timesheetRepositoryProvider).getContext(from: from, to: to);

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref
        .read(timesheetRepositoryProvider)
        .getContext(from: from, to: to));
  }

  Future<void> setRange(DateTime newFrom, DateTime newTo) async {
    _from = newFrom;
    _to = newTo;
    await reload();
  }

  Future<void> create(List<TimeLog> logs, {String? note}) async {
    await ref.read(timesheetRepositoryProvider).create(logs, note: note);
    await reload();
  }

  Future<ActiveTimer> startTimer({
    required String activityType,
    required String project,
    required String task,
  }) async {
    final timer = await ref.read(timesheetRepositoryProvider).startTimer(
          activityType: activityType,
          project: project,
          task: task,
        );
    ref.invalidate(activeTimerProvider);
    // Starting the timer opens a running row on the draft; the draft's detail
    // (which feeds the Time Logs grid) is cached, so drop it or the new row
    // never surfaces. The controller does not hold the draft name here, so the
    // whole detail family is invalidated.
    ref.invalidate(timesheetDetailProvider);
    await reload();
    return timer;
  }

  Future<void> stopTimer(String description) async {
    await ref.read(timesheetRepositoryProvider).stopTimer(description);
    ref.invalidate(activeTimerProvider);
    // Stopping writes the To time + hours onto the running row. Without
    // invalidating the cached draft detail the grid keeps showing the stale
    // running row, so the finished entry only appears after a later refresh.
    ref.invalidate(timesheetDetailProvider);
    await reload();
  }

  Future<void> submitTimesheet(String name) async {
    await ref.read(timesheetRepositoryProvider).submitTimesheet(name);
    ref.invalidate(timesheetDetailProvider);
    await reload();
  }

  /// Add one time log row to an existing draft timesheet.
  ///
  /// The detail view and the list both change (row count, timesheet total,
  /// period summary), so both are refreshed once the write lands.
  Future<void> addLog({
    String? timesheet,
    required String activityType,
    required DateTime fromTime,
    required DateTime toTime,
    required String project,
    required String task,
    required String description,
    required bool billable,
  }) async {
    await ref.read(timesheetRepositoryProvider).addLog(
          timesheet: timesheet,
          activityType: activityType,
          fromTime: fromTime,
          toTime: toTime,
          project: project,
          task: task,
          description: description,
          billable: billable,
        );
    // A null timesheet means the server created/reused the open draft; there is
    // no detail cache to invalidate for it — reload() surfaces the new draft.
    if (timesheet != null && timesheet.isNotEmpty) {
      ref.invalidate(timesheetDetailProvider(timesheet));
    }
    await reload();
  }

  Future<void> updateLog({
    required String timesheet,
    required String rowName,
    required String activityType,
    required DateTime fromTime,
    required DateTime toTime,
    required String project,
    required String task,
    required String description,
    required bool billable,
  }) async {
    await ref.read(timesheetRepositoryProvider).updateLog(
          timesheet: timesheet,
          rowName: rowName,
          activityType: activityType,
          fromTime: fromTime,
          toTime: toTime,
          project: project,
          task: task,
          description: description,
          billable: billable,
        );
    ref.invalidate(timesheetDetailProvider(timesheet));
    await reload();
  }

  Future<void> deleteLog({
    required String timesheet,
    required String rowName,
  }) async {
    await ref
        .read(timesheetRepositoryProvider)
        .deleteLog(timesheet: timesheet, rowName: rowName);
    ref.invalidate(timesheetDetailProvider(timesheet));
    await reload();
  }
}

/// Active timer for the current user. Refreshed by start/stop actions and on
/// timesheet screen entry. Returns null when nothing is running.
final activeTimerProvider = FutureProvider<ActiveTimer?>(
    (ref) => ref.read(timesheetRepositoryProvider).getActiveTimer());

/// Tasks for a project — fetched on-demand in the start sheet.
final projectTasksProvider =
    FutureProvider.family<List<TaskRef>, String>((ref, project) {
  if (project.isEmpty) return Future.value(const []);
  return ref.read(timesheetRepositoryProvider).getProjectTasks(project);
});

/// On-demand detail for a single Timesheet.
final timesheetDetailProvider =
    FutureProvider.family<TimesheetDetail, String>((ref, name) {
  return ref.read(timesheetRepositoryProvider).getDetail(name);
});

/// Filter key for the All Timesheets roster.
typedef AllTimesheetsKey = ({DateTime from, DateTime to, String? search});

/// All Timesheets roster, keyed by date window + search. Only usable by users
/// with Timesheet read permission (the screen is nav-gated on that capability).
final allTimesheetsProvider =
    FutureProvider.family<AllTimesheets, AllTimesheetsKey>((ref, key) {
  return ref.read(timesheetRepositoryProvider).listAll(
        from: key.from,
        to: key.to,
        search: key.search,
      );
});
