import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/timesheet_controller.dart';
import '../domain/models.dart';

/// Modal sheet — pick activity → project → task → Start.
class StartTimerSheet extends ConsumerStatefulWidget {
  const StartTimerSheet({super.key, required this.ctx});
  final TimesheetContext ctx;
  @override
  ConsumerState<StartTimerSheet> createState() => _StartTimerSheetState();
}

class _StartTimerSheetState extends ConsumerState<StartTimerSheet> {
  String? _activity;
  String? _project;
  String? _task;
  bool _busy = false;
  String? _error;

  bool get _ready => _activity != null && _project != null && _task != null;

  Future<void> _start() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(timesheetControllerProvider.notifier).startTimer(
            activityType: _activity!,
            project: _project!,
            task: _task!,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not start the timer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final tasksAsync = _project == null
        ? const AsyncValue<List<TaskRef>>.data([])
        : ref.watch(projectTasksProvider(_project!));
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.xl + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
                child: Text('Start Timer',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.xl),
            DropdownButtonFormField<String>(
              initialValue: _activity,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Activity'),
              items: widget.ctx.activityTypes
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (v) => setState(() => _activity = v),
            ),
            const SizedBox(height: AppDimens.lg),
            DropdownButtonFormField<String>(
              initialValue: _project,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Project'),
              items: widget.ctx.projects
                  .map((p) =>
                      DropdownMenuItem(value: p.name, child: Text(p.label)))
                  .toList(),
              onChanged: (v) => setState(() {
                _project = v;
                _task = null;
              }),
            ),
            const SizedBox(height: AppDimens.lg),
            tasksAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.md),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text(
                  e is ApiException ? e.message : 'Could not load tasks.',
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 13)),
              data: (tasks) {
                if (_project == null) {
                  return Text('Pick a project first.',
                      style: Theme.of(context).textTheme.bodySmall);
                }
                if (tasks.isEmpty) {
                  return Text('No open tasks on this project.',
                      style: Theme.of(context).textTheme.bodySmall);
                }
                return DropdownButtonFormField<String>(
                  initialValue:
                      tasks.any((t) => t.name == _task) ? _task : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Task'),
                  items: tasks
                      .map((t) => DropdownMenuItem(
                          value: t.name, child: Text(t.subject)))
                      .toList(),
                  onChanged: (v) => setState(() => _task = v),
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            FilledButton.icon(
              onPressed: (_ready && !_busy) ? _start : null,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow, size: 18),
              label: const Text('Start'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondaryContainer,
                foregroundColor: AppColors.onSecondaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal sheet — enter description (mandatory, ≥ 4 chars) → Stop.
class StopTimerSheet extends ConsumerStatefulWidget {
  const StopTimerSheet({super.key, required this.timer});
  final ActiveTimer timer;
  @override
  ConsumerState<StopTimerSheet> createState() => _StopTimerSheetState();
}

class _StopTimerSheetState extends ConsumerState<StopTimerSheet> {
  final _description = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _stop() async {
    final desc = _description.text.trim();
    if (desc.length < 4) {
      setState(() =>
          _error = 'Description is required (at least 4 characters).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(timesheetControllerProvider.notifier).stopTimer(desc);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not stop the timer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _elapsed() {
    final d = widget.timer.elapsedNow();
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.xl + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
                child: Text('Stop Timer',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.md),
            Container(
              padding: const EdgeInsets.all(AppDimens.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.timer.task,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                      '${widget.timer.activityType} · ${widget.timer.project}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('Elapsed: ${_elapsed()}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What did you work on?',
                alignLabelWithHint: true,
                hintText: 'Required, at least 4 characters',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                  ),
                  child: const Text('Keep Running'),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _stop,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.stop, size: 18),
                  label: const Text('Stop'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondaryContainer,
                    foregroundColor: AppColors.onSecondaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showStopTimerSheet(BuildContext context, ActiveTimer timer) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => StopTimerSheet(timer: timer),
    );

Future<bool?> showStartTimerSheet(BuildContext context, TimesheetContext ctx) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => StartTimerSheet(ctx: ctx),
    );

/// Modal sheet - add or edit one time log row on a draft timesheet.
///
/// This is the mobile stand-in for the desk's Time Logs grid row: the same
/// fields ERPNext asks for on a Timesheet Detail (activity, from, to, project,
/// task, description, billable), with Hrs shown live as the desk computes it
/// from the two datetimes. Passing [row] switches the sheet from add to edit.
class TimeLogEditorSheet extends ConsumerStatefulWidget {
  const TimeLogEditorSheet({
    super.key,
    required this.ctx,
    this.timesheet,
    this.row,
  });

  final TimesheetContext ctx;

  /// Draft to append to / edit. Null when adding the very first row with no
  /// open draft yet — the server then creates one. Always set when editing.
  final String? timesheet;
  final TimesheetLogRow? row;

  @override
  ConsumerState<TimeLogEditorSheet> createState() => _TimeLogEditorSheetState();
}

class _TimeLogEditorSheetState extends ConsumerState<TimeLogEditorSheet> {
  late String? _activity;
  late String? _project;
  late String? _task;
  late DateTime _from;
  late DateTime _to;
  late bool _billable;
  late final TextEditingController _descCtrl;
  bool _busy = false;
  String? _error;

  static final _dateFmt = DateFormat('d MMM yyyy · h:mm a');

  bool get _isEdit => widget.row != null;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    final now = DateTime.now();
    _activity = r?.activityType;
    _project = r?.project;
    _task = r?.task;
    _from = r?.fromTime?.toLocal() ?? now.subtract(const Duration(hours: 1));
    _to = r?.toTime?.toLocal() ?? now;
    _billable = r?.billable ?? false;
    _descCtrl = TextEditingController(text: r?.description ?? '');
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  /// Hours exactly as ERPNext derives them: the gap between the two datetimes.
  double get _hours =>
      _to.isAfter(_from) ? _to.difference(_from).inSeconds / 3600.0 : 0;

  Future<void> _pick({required bool isFrom}) async {
  final current = isFrom ? _from : _to;

  // First select date
  final pickedDate = await showDatePicker(
    context: context,
    initialDate: current,
    firstDate: DateTime.now().subtract(const Duration(days: 365)),
    lastDate: DateTime.now().add(const Duration(days: 1)),
  );

  if (pickedDate == null || !mounted) return;

  // Then select time
  final pickedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
  );

  if (pickedTime == null || !mounted) return;

  final next = DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime.hour,
    pickedTime.minute,
  );

  setState(() {
    if (isFrom) {
      final span = _to.difference(_from);

      _from = next;

      // Keep To time valid
      if (!_to.isAfter(_from)) {
        _to = next.add(
          span.isNegative || span == Duration.zero
              ? const Duration(hours: 1)
              : span,
        );
      }
    } else {
      _to = next;
    }
  });
 }
  Future<void> _save() async {
    final desc = _descCtrl.text.trim();
    if (_activity == null) {
      setState(() => _error = 'Pick an activity type.');
      return;
    }
    if (_project == null || _task == null) {
      setState(() => _error = 'Pick a project and a task.');
      return;
    }
    if (!_to.isAfter(_from)) {
      setState(() => _error = 'To time must be later than From time.');
      return;
    }
    if (desc.length < 4) {
      setState(() => _error = 'Add a short description (at least 4 characters).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(timesheetControllerProvider.notifier);
      if (_isEdit) {
        await controller.updateLog(
          timesheet: widget.timesheet!,
          rowName: widget.row!.name!,
          activityType: _activity!,
          fromTime: _from,
          toTime: _to,
          project: _project!,
          task: _task!,
          description: desc,
          billable: _billable,
        );
      } else {
        await controller.addLog(
          timesheet: widget.timesheet,
          activityType: _activity!,
          fromTime: _from,
          toTime: _to,
          project: _project!,
          task: _task!,
          description: desc,
          billable: _billable,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save the entry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text(
            'This time entry will be removed from the timesheet.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(timesheetControllerProvider.notifier).deleteLog(
            timesheet: widget.timesheet!,
            rowName: widget.row!.name!,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not delete the entry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final tasksAsync = _project == null
        ? const AsyncValue<List<TaskRef>>.data([])
        : ref.watch(projectTasksProvider(_project!));
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.xl + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(_isEdit ? 'Edit Entry' : 'Add Entry',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: AppDimens.xl),
            DropdownButtonFormField<String>(
              initialValue: widget.ctx.activityTypes.contains(_activity)
                  ? _activity
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Activity'),
              items: widget.ctx.activityTypes
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: _busy ? null : (v) => setState(() => _activity = v),
            ),
            const SizedBox(height: AppDimens.lg),
            DropdownButtonFormField<String>(
              initialValue: widget.ctx.projects.any((p) => p.name == _project)
                  ? _project
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Project'),
              items: widget.ctx.projects
                  .map((p) =>
                      DropdownMenuItem(value: p.name, child: Text(p.label)))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                        _project = v;
                        _task = null;
                      }),
            ),
            const SizedBox(height: AppDimens.lg),
            tasksAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.md),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text(
                  e is ApiException ? e.message : 'Could not load tasks.',
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
              data: (tasks) {
                if (_project == null) {
                  return Text('Pick a project first.',
                      style: Theme.of(context).textTheme.bodySmall);
                }
                // A row being edited can point at a task that has since been
                // closed, and closed tasks are not in the open-task list. Keep
                // it as an option so editing the row does not silently drop it.
                final options = [
                  for (final t in tasks) (t.name, t.subject),
                  if (_task != null && !tasks.any((t) => t.name == _task))
                    (_task!, _task!),
                ];
                if (options.isEmpty) {
                  return Text('No open tasks on this project.',
                      style: Theme.of(context).textTheme.bodySmall);
                }
                return DropdownButtonFormField<String>(
                  initialValue: options.any((o) => o.$1 == _task) ? _task : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Task'),
                  items: options
                      .map((o) =>
                          DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                      .toList(),
                  onChanged: _busy ? null : (v) => setState(() => _task = v),
                );
              },
            ),
            const SizedBox(height: AppDimens.lg),
            InkWell(
              onTap: _busy ? null : () => _pick(isFrom: true),
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'From time',
                  prefixIcon: Icon(Icons.schedule),
                ),
                child: Text(_dateFmt.format(_from)),
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            InkWell(
              onTap: _busy ? null : () => _pick(isFrom: false),
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'To time',
                  prefixIcon: Icon(Icons.schedule),
                ),
                child: Text(_dateFmt.format(_to)),
              ),
            ),
            const SizedBox(height: AppDimens.md),
            Row(
              children: [
                Icon(Icons.timer_outlined,
                    size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Hrs: ${_hours.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _descCtrl,
              minLines: 2,
              maxLines: 4,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'What did you work on?',
                alignLabelWithHint: true,
                hintText: 'Required, at least 4 characters',
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            CheckboxListTile(
              value: _billable,
              onChanged:
                  _busy ? null : (v) => setState(() => _billable = v ?? false),
              title: Text('Is Billable',
                  style: Theme.of(context).textTheme.bodyMedium),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 18),
              label: Text(_isEdit ? 'Save changes' : 'Add entry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondaryContainer,
                foregroundColor: AppColors.onSecondaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
              ),
            ),
            if (_isEdit) ...[
              const SizedBox(height: AppDimens.sm),
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete entry'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool?> showTimeLogEditorSheet(
  BuildContext context, {
  required TimesheetContext ctx,
  String? timesheet,
  TimesheetLogRow? row,
}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) =>
          TimeLogEditorSheet(ctx: ctx, timesheet: timesheet, row: row),
    );
