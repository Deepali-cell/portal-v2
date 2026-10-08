import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../application/task_controller.dart';
import '../domain/models.dart';

final _dateFmt = DateFormat('d MMM');

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(taskControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.read(taskControllerProvider.notifier).reload(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Err(
          msg: e is ApiException ? e.message : 'Something unexpected happened. Please try again.',
          onRetry: () => ref.read(taskControllerProvider.notifier).reload(),
        ),
        data: (ctx) {
          return RefreshIndicator(
            onRefresh: () => ref.read(taskControllerProvider.notifier).reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.md,
                  AppDimens.screenPadding,
                  AppDimens.xl),
              children: [
                _Header(
                  title: 'Tasks & Projects',
                  subtitle: 'Track what you owe and what is in flight.',
                  cta: 'New Task',
                  onPressed: () => _openCreate(context, ctx),
                ),
                const SizedBox(height: AppDimens.lg),
                if (ctx.tasks.isEmpty)
                  const _EmptyCard(
                    icon: Icons.task_alt_outlined,
                    text: 'No tasks yet. Tap "New Task" to add one.',
                  )
                else
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppDimens.md,
                              AppDimens.md,
                              AppDimens.md,
                              AppDimens.sm),
                          child: Text('My Tasks',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                        ),
                        for (var i = 0; i < ctx.tasks.length; i++) ...[
                          if (i > 0)
                            Divider(
                                height: 1,
                                indent: 64,
                                color: AppColors.outlineVariant),
                          _TaskRow(
                              task: ctx.tasks[i], statuses: ctx.statuses),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, TaskContext ctx) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => _NewTaskSheet(ctx: ctx),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created.')));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onPressed,
  });
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppDimens.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add, size: 18),
            label: Text(cta),
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
      ],
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, required this.statuses});
  final TaskItem task;
  final List<String> statuses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _openEditSheet(context, ref),
      onLongPress: () => _changeStatus(context, ref),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.task_alt_outlined,
                  color: AppColors.onSurfaceVariant, size: 20),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                      [
                        task.priority,
                        if (task.expEndDate != null)
                          'Due ${_dateFmt.format(task.expEndDate!)}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            _StatusChip.task(task.status),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditSheet(BuildContext context, WidgetRef ref) async {
    final ctx = ref.read(taskControllerProvider).value;
    if (ctx == null) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => _EditTaskSheet(ctx: ctx, taskName: task.name),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated.')));
    }
  }

  Future<void> _changeStatus(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppDimens.lg),
              child: Text('Set status',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final s in statuses)
              ListTile(
                leading: Icon(Icons.circle,
                    size: 12, color: _StatusChip._taskColor(s).fg),
                title: Text(s),
                trailing: s == task.status ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != task.status) {
      try {
        await ref
            .read(taskControllerProvider.notifier)
            .setStatus(task.name, picked);
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  factory _StatusChip.task(String status) {
    final s = _taskColor(status);
    return _StatusChip(label: status, bg: s.bg, fg: s.fg);
  }

  static _StatusSpec _taskColor(String status) {
    switch (status) {
      case 'Completed':
        return _StatusSpec(
            bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixedVariant);
      case 'Cancelled':
        return _StatusSpec(
            bg: AppColors.surfaceContainerHigh, fg: AppColors.onSurfaceVariant);
      case 'Overdue':
        return const _StatusSpec(
            bg: AppColors.errorContainer, fg: AppColors.onErrorContainer);
      case 'Working':
      case 'Pending Review':
        return const _StatusSpec(bg: Color(0xFFFFF3E0), fg: Color(0xFFE65100));
      default:
        return _StatusSpec(
            bg: AppColors.secondaryFixed, fg: AppColors.onSecondaryFixedVariant);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}

class _StatusSpec {
  const _StatusSpec({required this.bg, required this.fg});
  final Color bg;
  final Color fg;
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Row(
          children: [
            Icon(icon, color: AppColors.outline),
            const SizedBox(width: AppDimens.md),
            Expanded(
                child: Text(text,
                    style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

class _NewTaskSheet extends ConsumerStatefulWidget {
  const _NewTaskSheet({required this.ctx});
  final TaskContext ctx;
  @override
  ConsumerState<_NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends ConsumerState<_NewTaskSheet> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String? _priority;
  String? _project;
  DateTime? _due;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _priority = widget.ctx.priorities.contains('Medium')
        ? 'Medium'
        : (widget.ctx.priorities.isNotEmpty
            ? widget.ctx.priorities.first
            : null);
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty) {
      setState(() => _error = 'Enter a subject.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(taskControllerProvider.notifier).create(
            subject: _subject.text.trim(),
            description: _description.text.trim(),
            priority: _priority,
            expEndDate: _due,
            project: _project,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                child: Text('New task',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.xl),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: AppDimens.lg),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: widget.ctx.priorities
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v),
            ),
            const SizedBox(height: AppDimens.lg),
            if (widget.ctx.projects.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _project,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Project (optional)'),
                items: widget.ctx.projects
                    .map((p) =>
                        DropdownMenuItem(value: p.name, child: Text(p.label)))
                    .toList(),
                onChanged: (v) => setState(() => _project = v),
              ),
            const SizedBox(height: AppDimens.lg),
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _due ?? now,
                  firstDate: now,
                  lastDate: DateTime(now.year + 2),
                );
                if (d != null) setState(() => _due = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Due date (optional)',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(_due == null ? 'Select' : _dateFmt.format(_due!),
                    style: TextStyle(
                        color: _due == null
                            ? AppColors.outline
                            : AppColors.onSurface)),
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            BrandButton(
                label: 'Create task',
                loading: _submitting,
                onPressed: _submit),
          ],
        ),
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

/// Edit-task sheet. Pre-fills from taskDetailProvider so we get fields the
/// list row doesn't carry (description, assignees). Calls
/// taskController.update on Save; permissions enforced server-side.
class _EditTaskSheet extends ConsumerStatefulWidget {
  const _EditTaskSheet({required this.ctx, required this.taskName});
  final TaskContext ctx;
  final String taskName;
  @override
  ConsumerState<_EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends ConsumerState<_EditTaskSheet> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String? _priority;
  String? _project;
  String? _status;
  DateTime? _due;
  bool _hydrated = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  void _hydrate(TaskDetail d) {
    if (_hydrated) return;
    _subject.text = d.subject;
    _description.text = d.description ?? '';
    _priority = d.priority;
    _project = d.project;
    _status = d.status;
    _due = d.expEndDate;
    _hydrated = true;
  }

  Future<void> _save(TaskDetail d) async {
    if (_subject.text.trim().isEmpty) {
      setState(() => _error = 'Subject can\'t be blank.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(taskControllerProvider.notifier).saveTask(
            name: widget.taskName,
            subject: _subject.text.trim() != d.subject
                ? _subject.text.trim()
                : null,
            description: _description.text.trim() != (d.description ?? '')
                ? _description.text.trim()
                : null,
            priority: _priority != null && _priority != d.priority ? _priority : null,
            project: _project != d.project ? _project : null,
            clearProject: _project == null && d.project != null,
            expEndDate: _due,
            clearExpEndDate: _due == null && d.expEndDate != null,
            status: _status != null && _status != d.status ? _status : null,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(taskDetailProvider(widget.taskName));
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.xl + bottom),
      child: async.when(
        loading: () => const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SizedBox(
          height: 160,
          child: Center(
            child: Text(
                e is ApiException ? e.message : 'Could not load task.',
                style: const TextStyle(color: AppColors.error)),
          ),
        ),
        data: (d) {
          _hydrate(d);
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text('Edit task',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                const SizedBox(height: 2),
                Center(
                  child: Text(widget.taskName,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(height: AppDimens.xl),
                TextField(
                  controller: _subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: AppDimens.lg),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: widget.ctx.statuses
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _status = v),
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: widget.ctx.priorities
                          .map((p) =>
                              DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (v) => setState(() => _priority = v),
                    ),
                  ),
                ]),
                const SizedBox(height: AppDimens.lg),
                if (widget.ctx.projects.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    initialValue: _project,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Project'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('(None)')),
                      ...widget.ctx.projects.map((p) =>
                          DropdownMenuItem<String?>(
                              value: p.name, child: Text(p.label))),
                    ],
                    onChanged: (v) => setState(() => _project = v),
                  ),
                const SizedBox(height: AppDimens.lg),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _due ?? now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 2),
                        );
                        if (picked != null) setState(() => _due = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Due date',
                          suffixIcon: Icon(Icons.calendar_today_outlined,
                              size: 18),
                        ),
                        child: Text(
                          _due == null ? 'No due date' : _dateFmt.format(_due!),
                          style: TextStyle(
                              color: _due == null
                                  ? AppColors.outline
                                  : AppColors.onSurface),
                        ),
                      ),
                    ),
                  ),
                  if (_due != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: () => setState(() => _due = null),
                      icon: Icon(Icons.close,
                          color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ]),
                const SizedBox(height: AppDimens.lg),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppDimens.md),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: AppDimens.xl),
                BrandButton(
                  label: 'Save changes',
                  loading: _submitting,
                  onPressed: () => _save(d),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
