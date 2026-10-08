import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/providers.dart';
import '../domain/crm_ref.dart';
import '../domain/models.dart';

final _ts = DateFormat('d MMM');

class AttachmentsTab extends ConsumerStatefulWidget {
  const AttachmentsTab({super.key, required this.crmRef});
  final CrmRef crmRef;
  @override
  ConsumerState<AttachmentsTab> createState() => _AttachmentsTabState();
}

class _AttachmentsTabState extends ConsumerState<AttachmentsTab> {
  bool _uploading = false;

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(withData: false);
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;
    setState(() => _uploading = true);
    try {
      await ref
          .read(crmCollabRepositoryProvider)
          .uploadAttachment(widget.crmRef, path);
      ref.invalidate(attachmentsProvider(widget.crmRef));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(CrmAttachment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete attachment?'),
        content: Text('"${a.fileName}" will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(crmCollabRepositoryProvider).deleteAttachment(a.name);
      ref.invalidate(attachmentsProvider(widget.crmRef));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _open(CrmAttachment a) async {
    final uri = Uri.parse(a.absoluteUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No app to open this file.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(attachmentsProvider(widget.crmRef));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.canvas,
        icon: _uploading
            ? SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.canvas))
            : const Icon(Icons.upload_file),
        label: const Text('Upload'),
        onPressed: _uploading ? null : _upload,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is ApiException ? e.message : 'Could not load files.'),
        ),
        data: (files) {
          if (files.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(AppDimens.xl),
              child: Text('No attachments yet.'),
            ));
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(attachmentsProvider(widget.crmRef)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding, AppDimens.screenPadding, AppDimens.screenPadding, 96),
              itemCount: files.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppDimens.sm),
              itemBuilder: (_, i) {
                final a = files[i];
                return Card(
                  child: ListTile(
                    leading: Icon(_iconFor(a.fileName), color: AppColors.navy),
                    title: Text(a.fileName,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${_size(a.fileSize)} · ${_ts.format(a.creation.toLocal())}'
                        '${a.isPrivate ? " · private" : ""}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: AppColors.danger),
                      onPressed: () => _delete(a),
                    ),
                    onTap: () => _open(a),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.gif')) {
      return Icons.image_outlined;
    }
    if (n.endsWith('.doc') || n.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    if (n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
