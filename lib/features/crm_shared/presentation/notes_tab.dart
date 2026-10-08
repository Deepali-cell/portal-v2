import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../../../shared/widgets/mic_note_button.dart';
import '../application/providers.dart';
import '../domain/crm_ref.dart';
import '../domain/models.dart';

final _ts = DateFormat('d MMM, h:mm a');

class NotesTab extends ConsumerWidget {
  const NotesTab({super.key, required this.crmRef});
  final CrmRef crmRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notesProvider(crmRef));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.canvas,
        icon: const Icon(Icons.add),
        label: const Text('Add note'),
        onPressed: () => _openSheet(context, ref, null),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Err(
            msg: e is ApiException ? e.message : 'Could not load notes.',
            onRetry: () => ref.invalidate(notesProvider(crmRef))),
        data: (notes) {
          if (notes.isEmpty) {
            return const _Empty(icon: Icons.note_outlined, label: 'No notes yet');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notesProvider(crmRef)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding, AppDimens.screenPadding, AppDimens.screenPadding, 96),
              itemCount: notes.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppDimens.md),
              itemBuilder: (_, i) => _NoteCard(
                note: notes[i],
                onEdit: () => _openSheet(context, ref, notes[i]),
                onDelete: () => _confirmDelete(context, ref, notes[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref, CrmNote? note) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => _NoteSheet(crmRef: crmRef, existing: note),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, CrmNote n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('"${n.title}" will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(crmCollabRepositoryProvider).deleteNote(n.name);
      ref.invalidate(notesProvider(crmRef));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onEdit, required this.onDelete});
  final CrmNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(note.title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: onDelete,
                  ),
                ],
              ),
              if (note.content != null && note.content!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _stripHtml(note.content!),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.ink),
                  ),
                ),
              const SizedBox(height: AppDimens.xs),
              Text('${note.owner} · ${_ts.format(note.creation.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  String _stripHtml(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _NoteSheet extends ConsumerStatefulWidget {
  const _NoteSheet({required this.crmRef, this.existing});
  final CrmRef crmRef;
  final CrmNote? existing;
  @override
  ConsumerState<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends ConsumerState<_NoteSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _content =
      TextEditingController(text: widget.existing?.content ?? '');
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
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
      if (_isEdit) {
        await repo.updateNote(widget.existing!.name,
            title: _title.text.trim(), content: _content.text.trim());
      } else {
        await repo.createNote(widget.crmRef,
            title: _title.text.trim(), content: _content.text.trim());
      }
      ref.invalidate(notesProvider(widget.crmRef));
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
                child: Text(_isEdit ? 'Edit note' : 'New note',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.xl),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _content,
              minLines: 4,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: 'Content',
                alignLabelWithHint: true,
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 6),
                  child: MicNoteButton(
                    controller: _content,
                    tooltip: 'Dictate note content',
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            BrandButton(
                label: _isEdit ? 'Save changes' : 'Add note',
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
