import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import 'dart:async';

import '../application/timesheet_controller.dart';
import '../domain/models.dart';
import 'running_timer.dart' show formatElapsed;
import 'timer_sheets.dart';

final _dateFmt = DateFormat('d MMM yyyy');
final _dtFmt = DateFormat('d MMM, h:mm a');

class TimesheetDetailScreen extends ConsumerStatefulWidget {
  const TimesheetDetailScreen({super.key, required this.name});
  final String name;

  @override
  ConsumerState<TimesheetDetailScreen> createState() =>
      _TimesheetDetailScreenState();
}

class _TimesheetDetailScreenState extends ConsumerState<TimesheetDetailScreen> {
  bool _submitting = false;

  /// Open the add / edit sheet for a time log row.
  ///
  /// Activity types and projects come from the timesheet context the list
  /// screen already loads, so the sheet has the same pickers the Start Timer
  /// sheet uses. If that context has not arrived yet the tap is ignored rather
  /// than opening a sheet with empty dropdowns.
  Future<void> _openEditor({TimesheetLogRow? row}) async {
    final ctx = ref.read(timesheetControllerProvider).asData?.value;
    if (ctx == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Still loading. Try again in a moment.')));
      return;
    }
    await showTimeLogEditorSheet(
      context,
      ctx: ctx,
      timesheet: widget.name,
      row: row,
    );
  }

  Future<void> _submit(TimesheetDetail d) async {
    if (d.hasActiveTimer) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Stop the running timer before submitting.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit timesheet?'),
        content: Text(
            'This will submit ${d.name}. Once submitted you cannot edit its entries.'),
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
      await ref
          .read(timesheetControllerProvider.notifier)
          .submitTimesheet(widget.name);
      ref.invalidate(timesheetDetailProvider(widget.name));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${d.name} submitted.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Stop the running timer straight from this detail screen. Previously the
  /// running row was un-tappable and the timer could only be stopped from the
  /// list screen's timer strip, which left the Submit button permanently
  /// blocked when the user was on the detail screen.
  Future<void> _stopRunningTimer() async {
    final timer = ref.read(activeTimerProvider).value;
    if (timer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No running timer found. Pull to refresh.')));
      return;
    }
    final stopped = await showStopTimerSheet(context, timer);
    if (stopped == true && mounted) {
      ref.invalidate(timesheetDetailProvider(widget.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(timesheetDetailProvider(widget.name));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Timesheet'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.invalidate(timesheetDetailProvider(widget.name)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(timesheetDetailProvider(widget.name));
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: Text(
                e is ApiException ? e.message : 'Could not open the timesheet.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        data: (d) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
              AppDimens.lg, AppDimens.screenPadding, AppDimens.xl),
          children: [
            _Hero(d: d),
            const SizedBox(height: AppDimens.lg),
            _LogsSection(
              logs: d.logs,
              canEdit: d.canEdit,
              onAdd: () => _openEditor(),
              onEdit: (row) => _openEditor(row: row),
              onStop: _stopRunningTimer,
            ),
            if (d.note != null && d.note!.isNotEmpty) ...[
              const SizedBox(height: AppDimens.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Note',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppDimens.sm),
                      Text(d.note!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        ),
      ),
      bottomNavigationBar: async.when(
        loading: () => null,
        error: (_, _) => null,
        data: (d) {
          if (!d.isDraft) return null;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
                  AppDimens.sm, AppDimens.screenPadding, AppDimens.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (d.hasActiveTimer)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.sm),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            size: 14, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                              'Stop the running timer before submitting.',
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                        ),
                      ]),
                    )
                  else if (!d.canSubmit)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.sm),
                      child: Text(
                          'You do not have permission to submit this timesheet.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Submit'),
                      onPressed: (_submitting ||
                              d.hasActiveTimer ||
                              !d.canSubmit)
                          ? null
                          : () => _submit(d),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondaryContainer,
                        foregroundColor: AppColors.onSecondaryContainer,
                        disabledBackgroundColor: AppColors.surfaceContainer,
                        disabledForegroundColor:
                            AppColors.onSurfaceVariant,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusLg),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.d});
  final TimesheetDetail d;

  /// Total as the server formatted it, matching the ERPNext desk. Falls back
  /// to the raw number only if an older server build did not send the string.
  String _formatHours(TimesheetDetail d) =>
      '${d.totalHoursDisplay ?? d.totalHours.toStringAsFixed(2)} h';

  String _docstatusLabel(int s) =>
      switch (s) { 1 => 'Submitted', 2 => 'Cancelled', _ => 'Draft' };

  @override
  Widget build(BuildContext context) {
    final period = (d.startDate != null && d.endDate != null)
        ? '${_dateFmt.format(d.startDate!)} – ${_dateFmt.format(d.endDate!)}'
        : d.name;
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.name,
              style: TextStyle(
                  color: AppColors.primaryFixedDim, fontSize: 12)),
          const SizedBox(height: 4),
          Text(period,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDimens.md),
          Row(children: [
            Expanded(child: _kv(context, 'Total', _formatHours(d))),
            Container(
                width: 1,
                height: 32,
                color: AppColors.primaryFixedDim.withValues(alpha: 0.25)),
            Expanded(
                child:
                    _kv(context, 'Status', d.status.isEmpty ? '-' : d.status)),
            Container(
                width: 1,
                height: 32,
                color: AppColors.primaryFixedDim.withValues(alpha: 0.25)),
            Expanded(
                child: _kv(context, 'State', _docstatusLabel(d.docstatus))),
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
              style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LogsSection extends StatelessWidget {
  const _LogsSection({
    required this.logs,
    required this.canEdit,
    required this.onAdd,
    required this.onEdit,
    required this.onStop,
  });
  final List<TimesheetLogRow> logs;
  final bool canEdit;
  final VoidCallback onAdd;
  final ValueChanged<TimesheetLogRow> onEdit;
  final VoidCallback onStop;

  /// Hours as the server formatted them, which is how the ERPNext desk shows
  /// the same value. Falls back to the raw number only if an older server
  /// build did not send the display string.
  String _h(TimesheetLogRow log) =>
      '${log.hoursDisplay ?? log.hours.toStringAsFixed(2)} h';

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Row(
            children: [
              Icon(Icons.event_busy_outlined,
                  color: AppColors.onSurfaceVariant),
              const SizedBox(width: AppDimens.md),
              Expanded(
                  child: Text('No time logs on this timesheet.',
                      style: Theme.of(context).textTheme.bodyMedium)),
              if (canEdit)
                IconButton(
                  tooltip: 'Add entry',
                  icon: Icon(Icons.add, color: AppColors.primary),
                  onPressed: onAdd,
                ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(AppDimens.md, AppDimens.md,
                canEdit ? AppDimens.xs : AppDimens.md, AppDimens.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text('Time logs',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
                Text('${logs.length}',
                    style: Theme.of(context).textTheme.labelMedium),
                if (canEdit)
                  IconButton(
                    tooltip: 'Add entry',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.add, color: AppColors.primary),
                    onPressed: onAdd,
                  ),
              ],
            ),
          ),
          for (var i = 0; i < logs.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1, indent: 64, color: AppColors.outlineVariant),
            _LogRow(
              log: logs[i],
              hours: _h(logs[i]),
              // A running timer row has no end yet — tapping it opens the Stop
              // sheet (it can't be edited until stopped). A completed row opens
              // the editor. A viewer (no edit rights) gets no tap.
              onTap: logs[i].isRunning
                  ? (canEdit ? onStop : null)
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

/// A single time-log row. A running row ticks live (elapsed time in place of
/// stored hours) and shows an explicit "Stop timer" button so the timer can be
/// stopped straight from the entry; a completed row shows its hours and, when
/// editable, opens the editor on tap.
class _LogRow extends StatefulWidget {
  const _LogRow({required this.log, required this.hours, this.onTap});
  final TimesheetLogRow log;
  final String hours;

  /// For a running row this stops the timer; for a completed row it opens the
  /// editor. Null when the viewer has no edit rights.
  final VoidCallback? onTap;

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.log.isRunning) _startTicking();
  }

  @override
  void didUpdateWidget(_LogRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A row can flip between running and stopped as the timesheet refreshes.
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
    final running = log.isRunning;
    // A running row has no To time yet, so its stored hours are 0. Show the
    // live elapsed time instead so the row reads like a real running timer.
    final trailingHours = running && log.fromTime != null
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
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600)),
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
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              if (!running && log.toTime != null) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 4),
              ],
              Text(trailingHours,
                  style: TextStyle(
                      color: running ? AppColors.error : AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontFeatures: running
                          ? const [FontFeature.tabularFigures()]
                          : null)),
            ],
          ),
          // Running entry: an explicit Stop button, so the timer can be stopped
          // straight from its entry (not just by tapping the row).
          if (running && onTap != null) ...[
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
    // Completed rows still open the editor on tap; a running row's tap is
    // handled by its explicit Stop button above, so it is not wrapped again.
    if (onTap == null || running) return body;
    return InkWell(onTap: onTap, child: body);
  }
}
