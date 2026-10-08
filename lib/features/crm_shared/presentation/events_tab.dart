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

final _dt = DateFormat('d MMM, h:mm a');
const _categories = ['Meeting', 'Call', 'Event', 'Other'];

class EventsTab extends ConsumerWidget {
  const EventsTab({super.key, required this.crmRef});
  final CrmRef crmRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventsProvider(crmRef));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.canvas,
        icon: const Icon(Icons.event),
        label: const Text('New event'),
        onPressed: () => _openSheet(context, ref, null),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(e is ApiException ? e.message : 'Could not load events.')),
        data: (events) {
          if (events.isEmpty) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event_outlined,
                    size: 40, color: AppColors.inkFaint),
                const SizedBox(height: AppDimens.md),
                Text('No events scheduled',
                    style: Theme.of(context).textTheme.bodyMedium),
              ]),
            ));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(eventsProvider(crmRef)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding, AppDimens.screenPadding, AppDimens.screenPadding, 96),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppDimens.md),
              itemBuilder: (_, i) => _EventCard(
                event: events[i],
                onTap: () => _openSheet(context, ref, events[i]),
                onDelete: () => _delete(context, ref, events[i].name),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref, CrmEvent? e) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => _EventSheet(crmRef: crmRef, existing: e),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: const Text('This event will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(crmCollabRepositoryProvider).deleteEvent(name);
      ref.invalidate(eventsProvider(crmRef));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap, required this.onDelete});
  final CrmEvent event;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final upcoming = event.startsOn.isAfter(DateTime.now());
    final timeStr = event.allDay
        ? '${DateFormat('d MMM').format(event.startsOn.toLocal())} · all day'
        : '${_dt.format(event.startsOn.toLocal())}'
            '${event.endsOn != null ? " – ${DateFormat('h:mm a').format(event.endsOn!.toLocal())}" : ""}';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_categoryIcon(event.eventCategory),
                    color: AppColors.navy, size: 18),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Text(event.subject,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: onDelete,
                ),
              ]),
              Text(timeStr,
                  style: TextStyle(
                      color: upcoming ? AppColors.navy : AppColors.inkMuted,
                      fontWeight: FontWeight.w500,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Wrap(spacing: AppDimens.sm, children: [
                _chip(event.eventCategory ?? 'Event', AppColors.inkMuted),
                _chip(event.status,
                    event.status == 'Completed' ? AppColors.success : AppColors.warning),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Text(label,
            style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
      );

  IconData _categoryIcon(String? c) {
    switch (c) {
      case 'Meeting':
        return Icons.groups_outlined;
      case 'Call':
        return Icons.call;
      default:
        return Icons.event_note;
    }
  }
}

class _EventSheet extends ConsumerStatefulWidget {
  const _EventSheet({required this.crmRef, this.existing});
  final CrmRef crmRef;
  final CrmEvent? existing;
  @override
  ConsumerState<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<_EventSheet> {
  late final _subject = TextEditingController(text: widget.existing?.subject ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late String _category = widget.existing?.eventCategory ?? 'Meeting';
  late DateTime _starts =
      widget.existing?.startsOn ?? DateTime.now().add(const Duration(hours: 1));
  late DateTime? _ends = widget.existing?.endsOn;
  late bool _allDay = widget.existing?.allDay ?? false;
  bool _saving = false;
  String? _error;
  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1),
      lastDate: DateTime(initial.year + 2),
    );
    if (d == null || !mounted) return null;
    if (_allDay) return DateTime(d.year, d.month, d.day);
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    if (_subject.text.trim().isEmpty) {
      setState(() => _error = 'Subject is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(crmCollabRepositoryProvider);
      if (_isEdit) {
        await repo.updateEvent(widget.existing!.name,
            subject: _subject.text.trim(),
            startsOn: _starts,
            endsOn: _ends,
            eventCategory: _category,
            description: _description.text.trim(),
            allDay: _allDay);
      } else {
        await repo.createEvent(widget.crmRef,
            subject: _subject.text.trim(),
            startsOn: _starts,
            endsOn: _ends,
            eventCategory: _category,
            description: _description.text.trim(),
            allDay: _allDay);
      }
      ref.invalidate(eventsProvider(widget.crmRef));
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
                child: Text(_isEdit ? 'Edit event' : 'New event',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.xl),
            TextField(
                controller: _subject,
                decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: AppDimens.lg),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: AppDimens.lg),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All-day'),
              value: _allDay,
              activeThumbColor: AppColors.navy,
              onChanged: (v) => setState(() => _allDay = v),
            ),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await _pickDateTime(_starts);
                    if (d != null) setState(() => _starts = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Starts'),
                    child: Text(_dt.format(_starts)),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await _pickDateTime(_ends ?? _starts);
                    if (d != null) setState(() => _ends = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Ends'),
                    child: Text(_ends == null ? '-' : _dt.format(_ends!)),
                  ),
                ),
              ),
            ]),
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
                label: _isEdit ? 'Save changes' : 'Add event',
                loading: _saving,
                onPressed: _save),
          ],
        ),
      ),
    );
  }
}
