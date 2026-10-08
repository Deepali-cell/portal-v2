import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import '../application/timesheet_controller.dart';
import '../domain/models.dart';
import '../../../shared/widgets/date_range_bar.dart';
import '../../../shared/widgets/employee_only_notice.dart';
import 'running_timer.dart';
import 'timer_sheets.dart';

final _dFmt = DateFormat('d MMM');
final _rangeFmt = DateFormat('d MMM yyyy');
final _dtFmt = DateFormat('d MMM, h:mm a');

/// My Timesheet — the ERP Timesheet form flow on mobile.
///
/// The screen centres on the caller's one open draft Timesheet: a header with
/// the running totals (Total / Billable hours), an editable Time Logs grid
/// (add / edit / delete rows exactly like the desk's grid) and a Submit action
/// at the bottom. Submitted / past timesheets live in a "History" list below.
class TimesheetScreen extends ConsumerStatefulWidget {
  const TimesheetScreen({super.key});

  @override
  ConsumerState<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends ConsumerState<TimesheetScreen> {
  bool _submitting = false;

  /// The caller's open draft in the current window, if any. Rows and the timer
  /// all funnel into this single draft on the backend, so at most one is open.
  TimesheetSummary? _draftOf(TimesheetContext ctx) {
    for (final t in ctx.timesheets) {
      if (t.status.toLowerCase() == 'draft') return t;
    }
    return null;
  }

  // "Add timesheet" now starts a running timer row (From = now, no To). The
  // To time and description are captured when the timer is stopped, so adding
  // a row and starting a timer are the same action. [draftName] is unused —
  // the server reuses / creates the caller's open draft when the timer starts.
  Future<void> _addEntry(TimesheetContext ctx, String? draftName) =>
      _startTimer(ctx);

  Future<void> _editEntry(
      TimesheetContext ctx, String draftName, TimesheetLogRow row) async {
    await showTimeLogEditorSheet(
      context,
      ctx: ctx,
      timesheet: draftName,
      row: row,
    );
  }

  Future<void> _startTimer(TimesheetContext ctx) async {
    if (ctx.activeTimer != null) return;
    if (ctx.projects.isEmpty || ctx.activityTypes.isEmpty) {
      _snack('You need an open project and an activity type to start a timer.');
      return;
    }
    final ok = await showStartTimerSheet(context, ctx);
    if (ok == true && mounted) _snack('Timer started.');
  }

  Future<void> _stopTimer(ActiveTimer timer) async {
    final ok = await showStopTimerSheet(context, timer);
    if (ok == true && mounted) _snack('Timer stopped.');
  }

  Future<void> _submit(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit timesheet?'),
        content: Text(
            'This will submit $name. Once submitted you cannot edit its entries.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _submitting = true);
    try {
      await ref.read(timesheetControllerProvider.notifier).submitTimesheet(name);
      if (mounted) _snack('$name submitted.');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    final noEmployee = profile != null && !profile.hasEmployee;
    final async = ref.watch(timesheetControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('My Timesheet'),
        actions: [
          if (!noEmployee)
            IconButton(
              tooltip: 'Refresh',
              icon: Icon(Icons.refresh, color: AppColors.primary),
              onPressed: () =>
                  ref.read(timesheetControllerProvider.notifier).reload(),
            ),
        ],
      ),
      body: noEmployee
          ? const EmployeeOnlyNotice(feature: 'Timesheet')
          : async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Err(
                msg: e is ApiException
                    ? e.message
                    : 'Something unexpected happened. Please try again.',
                onRetry: () =>
                    ref.read(timesheetControllerProvider.notifier).reload(),
              ),
              data: (ctx) => _body(ctx),
            ),
    );
  }

  Widget _body(TimesheetContext ctx) {
    final draft = _draftOf(ctx);
    final history =
        ctx.timesheets.where((t) => t.name != draft?.name).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(timesheetControllerProvider.notifier).reload(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
            AppDimens.md, AppDimens.screenPadding, AppDimens.xl),
        children: [
          // The open draft — the ERP Timesheet form. When none is open yet we
          // still show the form shell so "Add entry" starts a fresh draft.
          if (draft == null)
            _EmptyDraftForm(
              onAdd: () => _addEntry(ctx, null),
              onTimer: () => _startTimer(ctx),
              timerRunning: ctx.activeTimer != null,
            )
          else
            _DraftForm(
              draftName: draft.name,
              ctx: ctx,
              submitting: _submitting,
              onAdd: (name) => _addEntry(ctx, name),
              onEdit: (name, row) => _editEntry(ctx, name, row),
              onTimer: () => _startTimer(ctx),
              onStop: _stopTimer,
              onSubmit: _submit,
            ),

          const SizedBox(height: AppDimens.xl),
          _HistorySection(history: history),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- Draft form

/// The editable open-draft Timesheet: hero totals + Time Logs grid + Submit.
/// Bound to the draft's detail so hours / billable / rows stay authoritative.
class _DraftForm extends ConsumerWidget {
  const _DraftForm({
    required this.draftName,
    required this.ctx,
    required this.submitting,
    required this.onAdd,
    required this.onEdit,
    required this.onTimer,
    required this.onStop,
    required this.onSubmit,
  });

  final String draftName;
  final TimesheetContext ctx;
  final bool submitting;
  final void Function(String draftName) onAdd;
  final void Function(String draftName, TimesheetLogRow row) onEdit;
  final VoidCallback onTimer;
  final void Function(ActiveTimer timer) onStop;
  final void Function(String name) onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(timesheetDetailProvider(draftName));
    return async.when(
      loading: () => const _FormSkeleton(),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Text(e is ApiException
              ? e.message
              : 'Could not open your draft timesheet.'),
        ),
      ),
      data: (d) {
        final billable = d.logs
            .where((l) => l.billable)
            .fold<double>(0, (s, l) => s + l.hours);
        // The running timer, resolved from data we already hold. Prefer the
        // context's active_timer; if that is momentarily null, rebuild it from
        // the draft's running row (from set, to null). stopTimer() only posts a
        // description — the server locates the running row itself — so this
        // object is used purely to populate the Stop sheet's display.
        ActiveTimer? resolveTimer() {
          if (ctx.activeTimer != null) return ctx.activeTimer;
          for (final l in d.logs) {
            if (l.isRunning) {
              return ActiveTimer(
                rowName: l.name ?? '',
                timesheet: draftName,
                activityType: l.activityType ?? '',
                project: l.project ?? '',
                task: l.task ?? '',
                fromTime: l.fromTime ?? DateTime.now(),
              );
            }
          }
          return null;
        }

        void stopRunning() {
          final t = resolveTimer();
          if (t != null) onStop(t);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(d: d, billableHours: billable),
            const SizedBox(height: AppDimens.md),
            _ActionsRow(
              onAdd: () => onAdd(draftName),
              onTimer: onTimer,
              timerRunning: d.hasActiveTimer,
            ),
            const SizedBox(height: AppDimens.md),
            _LogsGrid(
              logs: d.logs,
              canEdit: d.canEdit,
              timerRunning: d.hasActiveTimer,
              onAdd: () => onAdd(draftName),
              onEdit: (row) => onEdit(draftName, row),
              onStopRow: stopRunning,
            ),
            if (d.isDraft) ...[
              const SizedBox(height: AppDimens.md),
              _SubmitButton(
                submitting: submitting,
                blocked: d.hasActiveTimer || !d.canSubmit,
                hint: d.hasActiveTimer
                    ? 'Stop the running timer before submitting.'
                    : (!d.canSubmit
                        ? 'You do not have permission to submit this timesheet.'
                        : null),
                onSubmit: () => onSubmit(d.name),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.d, required this.billableHours});
  final TimesheetDetail d;
  final double billableHours;

  String _h(double v) =>
      '${v == v.truncate() ? v.toInt() : v.toStringAsFixed(2)} h';

  @override
  Widget build(BuildContext context) {
    final period = (d.startDate != null && d.endDate != null)
        ? '${_rangeFmt.format(d.startDate!)} – ${_rangeFmt.format(d.endDate!)}'
        : 'New timesheet';
    final total = d.totalHoursDisplay != null
        ? '${d.totalHoursDisplay} h'
        : _h(d.totalHours);
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(d.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.primaryFixedDim, fontSize: 12)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(d.status.isEmpty ? 'Draft' : d.status,
                    style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(period,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDimens.md),
          Row(children: [
            Expanded(child: _kv(context, 'Total hours', total)),
            Container(
                width: 1,
                height: 32,
                color: AppColors.primaryFixedDim.withValues(alpha: 0.25)),
            Expanded(child: _kv(context, 'Billable', _h(billableHours))),
            Container(
                width: 1,
                height: 32,
                color: AppColors.primaryFixedDim.withValues(alpha: 0.25)),
            Expanded(child: _kv(context, 'Entries', '${d.logs.length}')),
          ]),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style:
                  TextStyle(color: AppColors.primaryFixedDim, fontSize: 11)),
          const SizedBox(height: 2),
          Text(v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.onAdd,
    required this.onTimer,
    required this.timerRunning,
  });
  final VoidCallback onAdd;
  final VoidCallback onTimer;
  final bool timerRunning;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // While a timer is running its row stays open until it is stopped, so
        // no new entry can be added meanwhile — the add affordance is blocked
        // and a hint points the user at the Stop action.
        FilledButton.icon(
          onPressed: timerRunning ? null : onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add timesheet'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.secondaryContainer,
            foregroundColor: AppColors.onSecondaryContainer,
            disabledBackgroundColor: AppColors.surfaceContainer,
            disabledForegroundColor: AppColors.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
          ),
        ),
        if (timerRunning)
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.xs),
            child: Row(children: [
              Icon(Icons.info_outline,
                  size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Stop the running timer before adding a new entry.',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ]),
          ),
        // Starting a timer lives here; stopping is done from the running
        // entry's own "Stop timer" button inside the Time Logs card.
        if (!timerRunning) ...[
          const SizedBox(height: AppDimens.xs),
          TextButton.icon(
            onPressed: onTimer,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Start timer'),
          ),
        ],
      ],
    );
  }
}

class _LogsGrid extends StatelessWidget {
  const _LogsGrid({
    required this.logs,
    required this.canEdit,
    required this.timerRunning,
    required this.onAdd,
    required this.onEdit,
    required this.onStopRow,
  });
  final List<TimesheetLogRow> logs;
  final bool canEdit;
  final bool timerRunning;
  final VoidCallback onAdd;
  final ValueChanged<TimesheetLogRow> onEdit;
  final VoidCallback onStopRow;

  String _h(TimesheetLogRow l) =>
      '${l.hoursDisplay ?? l.hours.toStringAsFixed(2)} h';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(AppDimens.md, AppDimens.md,
                canEdit ? AppDimens.xs : AppDimens.md, AppDimens.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text('Time Logs',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
                Text('${logs.length}',
                    style: Theme.of(context).textTheme.labelMedium),
                if (canEdit)
                  IconButton(
                    tooltip: timerRunning
                        ? 'Stop the running timer first'
                        : 'Add row',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.add,
                        color: timerRunning
                            ? AppColors.onSurfaceVariant
                            : AppColors.primary),
                    onPressed: timerRunning ? null : onAdd,
                  ),
              ],
            ),
          ),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.md, 0, AppDimens.md, AppDimens.lg),
              child: Row(
                children: [
                  Icon(Icons.event_busy_outlined,
                      color: AppColors.onSurfaceVariant, size: 20),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: Text(
                        'No entries yet. Add your first time log to build this timesheet.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < logs.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1, indent: 64, color: AppColors.outlineVariant),
              _LogTile(
                log: logs[i],
                hours: _h(logs[i]),
                onTap: logs[i].isRunning
                    ? (canEdit ? onStopRow : null)
                    : (canEdit && logs[i].name != null
                        ? () => onEdit(logs[i])
                        : null),
              ),
            ],
        ],
      ),
    );
  }
}

class _LogTile extends StatefulWidget {
  const _LogTile({required this.log, required this.hours, this.onTap});
  final TimesheetLogRow log;
  final String hours;
  final VoidCallback? onTap;

  @override
  State<_LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<_LogTile> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.log.isRunning) _startTicking();
  }

  @override
  void didUpdateWidget(_LogTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A row can flip between running and stopped as the draft refreshes.
    if (widget.log.isRunning && _tick == null) {
      _startTicking();
    } else if (!widget.log.isRunning && _tick != null) {
      _tick?.cancel();
      _tick = null;
    }
  }

  void _startTicking() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final onTap = widget.onTap;
    // A running row has no To time yet, so its stored hours are 0. Show the
    // live elapsed time instead so the row reads like a real running timer.
    final trailingHours = log.isRunning && log.fromTime != null
        ? formatElapsed(DateTime.now().difference(log.fromTime!.toLocal()))
        : widget.hours;
    final title = log.activityType ?? 'Time log';
    final meta = [
      if (log.project != null && log.project!.isNotEmpty) log.project,
      if (log.task != null && log.task!.isNotEmpty) log.task,
    ].whereType<String>().join(' · ');
    final body = Padding(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.access_time_outlined,
                    color: AppColors.onSurfaceVariant, size: 20),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: AppColors.onSurface,
                                      fontWeight: FontWeight.w600)),
                        ),
                        if (log.billable) ...[
                          const SizedBox(width: 6),
                          _Chip(
                              text: 'Billable',
                              color: AppColors.primary),
                        ],
                      ],
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    if (log.fromTime != null) ...[
                      const SizedBox(height: 2),
                      Text(
                          '${_dtFmt.format(log.fromTime!.toLocal())}'
                          '${log.toTime != null ? " → ${_dtFmt.format(log.toTime!.toLocal())}" : ""}',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                    if (log.description != null &&
                        log.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(log.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              if (!log.isRunning && log.toTime != null) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 4),
              ],
              Text(trailingHours,
                  style: TextStyle(
                      color:
                          log.isRunning ? AppColors.error : AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontFeatures: log.isRunning
                          ? const [FontFeature.tabularFigures()]
                          : null)),
            ],
          ),
          // Running entry: an explicit Stop button, right on the entry.
          if (log.isRunning && onTap != null) ...[
            const SizedBox(height: AppDimens.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Stop timer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    // A running row's tap is handled by its explicit Stop button, so only wrap
    // completed rows (which open the editor) in an InkWell.
    if (onTap == null || log.isRunning) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.submitting,
    required this.blocked,
    required this.hint,
    required this.onSubmit,
  });
  final bool submitting;
  final bool blocked;
  final String? hint;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.sm),
            child: Row(children: [
              Icon(Icons.info_outline,
                  size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(hint!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ]),
          ),
        FilledButton.icon(
          onPressed: (submitting || blocked) ? null : onSubmit,
          icon: submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline),
          label: const Text('Submit timesheet'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.secondaryContainer,
            foregroundColor: AppColors.onSecondaryContainer,
            disabledBackgroundColor: AppColors.surfaceContainer,
            disabledForegroundColor: AppColors.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
          ),
        ),
      ],
    );
  }
}

/// No open draft yet — the form shell that starts one on the first entry.
class _EmptyDraftForm extends StatelessWidget {
  const _EmptyDraftForm({
    required this.onAdd,
    required this.onTimer,
    required this.timerRunning,
  });
  final VoidCallback onAdd;
  final VoidCallback onTimer;
  final bool timerRunning;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimens.lg),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No open timesheet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Add your first time log to start a new timesheet.',
                  style: TextStyle(
                      color: AppColors.primaryFixedDim, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.md),
        _ActionsRow(
          onAdd: onAdd,
          onTimer: onTimer,
          timerRunning: timerRunning,
        ),
      ],
    );
  }
}

class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();
  @override
  Widget build(BuildContext context) {
    Widget bar(double h) => Container(
          margin: const EdgeInsets.only(bottom: AppDimens.md),
          height: h,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          ),
        );
    return Column(children: [bar(120), bar(52), bar(160)]);
  }
}

// --------------------------------------------------------------- History

class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.history});
  final List<TimesheetSummary> history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.read(timesheetControllerProvider).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('History',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('Your submitted and past timesheets',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppDimens.sm),
        if (ctx != null)
          DateRangeBar(
            from: ctx.fromDate,
            to: ctx.toDate,
            onChanged: (f, t) =>
                ref.read(timesheetControllerProvider.notifier).setRange(f, t),
          ),
        const SizedBox(height: AppDimens.md),
        if (history.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: Row(children: [
                Icon(Icons.inbox_outlined, color: AppColors.outline),
                const SizedBox(width: AppDimens.md),
                Expanded(
                    child: Text('No other timesheets in this range.',
                        style: Theme.of(context).textTheme.bodyMedium)),
              ]),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < history.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        indent: 16,
                        color: AppColors.outlineVariant),
                  _HistoryRow(ts: history[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.ts});
  final TimesheetSummary ts;
  @override
  Widget build(BuildContext context) {
    final period = (ts.startDate != null)
        ? '${_dFmt.format(ts.startDate!)}'
            '${ts.endDate != null && ts.endDate != ts.startDate ? ' – ${_dFmt.format(ts.endDate!)}' : ''}'
        : ts.name;
    final hours =
        '${ts.totalHoursDisplay ?? (ts.totalHours == ts.totalHours.truncate() ? ts.totalHours.toInt().toString() : ts.totalHours.toStringAsFixed(1))} h';
    return ListTile(
      onTap: () => context.push(Routes.timesheetDetail, extra: ts.name),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.receipt_long_outlined,
            color: AppColors.onSurfaceVariant, size: 20),
      ),
      title: Text(period,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${ts.name} · ${ts.status}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hours,
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
    );
  }
}

class _Err extends StatelessWidget {
  const _Err({required this.msg, required this.onRetry});
  final String msg;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: AppDimens.md),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}
