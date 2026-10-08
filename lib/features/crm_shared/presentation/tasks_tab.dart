import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../application/providers.dart';
import '../domain/crm_ref.dart';
import '../domain/models.dart';

final _dueFmt = DateFormat('d MMM, h:mm a');

Color statusColor(CrmTaskStatus s) {
  switch (s) {
    case CrmTaskStatus.done:
      return AppColors.success;
    case CrmTaskStatus.canceled:
      return AppColors.inkMuted;
    case CrmTaskStatus.inProgress:
      return AppColors.warning;
    case CrmTaskStatus.backlog:
      return AppColors.inkMuted;
    case CrmTaskStatus.todo:
      return AppColors.navy;
  }
}

Color priorityColor(String p) {
  switch (p) {
    case 'High':
      return AppColors.danger;
    case 'Medium':
      return AppColors.warning;
    default:
      return AppColors.inkMuted;
  }
}

class CrmTasksTab extends ConsumerStatefulWidget {
  const CrmTasksTab({super.key, required this.crmRef});
  final CrmRef crmRef;

  @override
  ConsumerState<CrmTasksTab> createState() => _CrmTasksTabState();
}

class _CrmTasksTabState extends ConsumerState<CrmTasksTab> {
  // null = All; otherwise show only tasks in this status.
  CrmTaskStatus? _filter;

  CrmRef get crmRef => widget.crmRef;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final async = ref.watch(crmTasksProvider(crmRef));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.canvas,
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
        onPressed: () => _openSheet(context, ref, null),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Err(
            msg: e is ApiException ? e.message : 'Could not load tasks.',
            onRetry: () => ref.invalidate(crmTasksProvider(crmRef))),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const _Empty(icon: Icons.task_alt_outlined, label: 'No tasks yet');
          }
          // Count per status so the filter chips can show how many.
          final counts = <CrmTaskStatus, int>{};
          for (final t in tasks) {
            counts[t.status] = (counts[t.status] ?? 0) + 1;
          }
          final visible = _filter == null
              ? tasks
              : tasks.where((t) => t.status == _filter).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(crmTasksProvider(crmRef)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusFilterBar(
                  selected: _filter,
                  total: tasks.length,
                  counts: counts,
                  onChanged: (s) => setState(() => _filter = s),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const _Empty(
                          icon: Icons.filter_alt_off_outlined,
                          label: 'No tasks in this status')
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
                              AppDimens.sm, AppDimens.screenPadding, 96),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppDimens.md),
                          itemBuilder: (_, i) => _TaskCard(
                            task: visible[i],
                            onTap: () => _openSheet(context, ref, visible[i]),
                            onDelete: () => _confirmDelete(context, ref, visible[i]),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref, CrmTaskItem? task) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => _TaskSheet(crmRef: crmRef, existing: task),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, CrmTaskItem t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${t.title}" will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(crmCollabRepositoryProvider).deleteTask(t.name);
      ref.invalidate(crmTasksProvider(crmRef));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

/// Horizontal status filter for the CRM tasks list. "All" plus one chip per
/// status, each showing its live count; the selected chip is filled.
class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.selected,
    required this.total,
    required this.counts,
    required this.onChanged,
  });
  final CrmTaskStatus? selected;
  final int total;
  final Map<CrmTaskStatus, int> counts;
  final ValueChanged<CrmTaskStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.screenPadding, vertical: AppDimens.sm),
        children: [
          _chip(context,
              label: 'All',
              count: total,
              color: AppColors.navy,
              active: selected == null,
              onTap: () => onChanged(null)),
          for (final s in CrmTaskStatus.values)
            if ((counts[s] ?? 0) > 0)
              _chip(context,
                  label: s.api,
                  count: counts[s] ?? 0,
                  color: statusColor(s),
                  active: selected == s,
                  onTap: () => onChanged(s)),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context,
      {required String label,
      required int count,
      required Color color,
      required bool active,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: AppDimens.sm),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 6),
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: active ? color : color.withValues(alpha: 0.25)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$label · $count',
            style: TextStyle(
              color: active ? AppColors.canvas : color,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard(
      {required this.task, required this.onTap, required this.onDelete});
  final CrmTaskItem task;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppDimens.md, AppDimens.md, AppDimens.sm, AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(task.title,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: AppColors.danger, size: 20),
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sm),
              Wrap(spacing: AppDimens.sm, runSpacing: AppDimens.xs, children: [
                _chip(task.status.api, statusColor(task.status), filled: true),
                _chip(task.priority, priorityColor(task.priority)),
                if (task.dueDate != null)
                  _chip('Due ${_dueFmt.format(task.dueDate!.toLocal())}',
                      AppColors.inkMuted),
                if (task.assignedTo != null && task.assignedTo!.isNotEmpty)
                  _chip(task.assignedTo!, AppColors.inkMuted),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color c, {bool filled = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm, vertical: 3),
        decoration: BoxDecoration(
          color: filled ? c.withValues(alpha: 0.12) : Colors.transparent,
          border: filled ? null : Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Text(label,
            style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}

class _TaskSheet extends ConsumerStatefulWidget {
  const _TaskSheet({required this.crmRef, this.existing});
  final CrmRef crmRef;
  final CrmTaskItem? existing;
  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _assignedTo =
      TextEditingController(text: widget.existing?.assignedTo ?? '');
  late String _status = widget.existing?.status.api ?? 'Todo';
  late String _priority = widget.existing?.priority ?? 'Medium';
  DateTime? _due;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _due = widget.existing?.dueDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _assignedTo.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: DateTime(now.year + 2),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_due ?? now));
    if (t == null) return;
    setState(() => _due = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'A title is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(crmCollabRepositoryProvider);
      final assigned = _assignedTo.text.trim();
      if (_isEdit) {
        await repo.updateTask(widget.existing!.name,
            title: _title.text.trim(),
            description: _description.text.trim(),
            status: _status,
            priority: _priority,
            dueDate: _due,
            assignedTo: assigned.isEmpty ? null : assigned);
      } else {
        await repo.createTask(widget.crmRef,
            title: _title.text.trim(),
            description: _description.text.trim(),
            status: _status,
            priority: _priority,
            dueDate: _due,
            assignedTo: assigned.isEmpty ? null : assigned);
      }
      ref.invalidate(crmTasksProvider(widget.crmRef));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
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
                child: Text(_isEdit ? 'Edit task' : 'New task',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.xl),
            TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: AppDimens.lg),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: kCrmTaskStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: kCrmTaskPriorities
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v ?? _priority),
                ),
              ),
            ]),
            const SizedBox(height: AppDimens.lg),
            InkWell(
              onTap: _pickDue,
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Due (optional)',
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                child: Text(_due == null ? 'Select' : _dueFmt.format(_due!),
                    style: TextStyle(
                        color: _due == null ? AppColors.inkFaint : AppColors.ink)),
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
                controller: _assignedTo,
                decoration:
                    const InputDecoration(labelText: 'Assigned to (email)')),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            BrandButton(
                label: _isEdit ? 'Save changes' : 'Add task',
                loading: _saving,
                onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: AppColors.inkFaint),
            const SizedBox(height: AppDimens.md),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
      );
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
            Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            const SizedBox(height: AppDimens.md),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}
