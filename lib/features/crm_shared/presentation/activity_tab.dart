import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/providers.dart';
import '../domain/crm_ref.dart';
import '../domain/models.dart';

final _ts = DateFormat('h:mm a');
final _dayFull = DateFormat('EEE d MMM yyyy');

class ActivityTab extends ConsumerWidget {
  const ActivityTab({super.key, required this.crmRef});
  final CrmRef crmRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(timelineProvider(crmRef));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is ApiException ? e.message : 'Could not load activity.'),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.xl),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history,
                      size: 40, color: AppColors.inkFaint),
                  const SizedBox(height: AppDimens.md),
                  Text('No activity yet.',
                      style: Theme.of(context).textTheme.bodyMedium),
                ]),
              ),
            );
          }
          // Group by local date.
          final grouped = <DateTime, List<TimelineEntry>>{};
          for (final e in items) {
            final d = e.creation.toLocal();
            final key = DateTime(d.year, d.month, d.day);
            grouped.putIfAbsent(key, () => []).add(e);
          }
          final sortedDays = grouped.keys.toList()
            ..sort((a, b) => b.compareTo(a));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(timelineProvider(crmRef)),
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              children: [
                for (final day in sortedDays) ...[
                  _DayHeader(day: day),
                  const SizedBox(height: AppDimens.sm),
                  ...grouped[day]!.map((e) => _EntryRow(entry: e)),
                  const SizedBox(height: AppDimens.lg),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});
  final DateTime day;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    String label;
    if (day == today) {
      label = 'Today';
    } else if (day == yesterday) {
      label = 'Yesterday';
    } else {
      label = _dayFull.format(day);
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.sm, bottom: AppDimens.xs),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.6)),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});
  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final v = _viewFor(entry);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: v.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(v.icon, size: 18, color: v.color),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: AppColors.ink, fontSize: 14),
                    children: [
                      TextSpan(
                        text: entry.owner,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(text: v.title),
                    ],
                  ),
                ),
                if (v.detail != null && v.detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(v.detail!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
                ],
                const SizedBox(height: 2),
                Text(_ts.format(entry.creation.toLocal()),
                    style: TextStyle(
                        color: AppColors.inkFaint, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryView {
  const _EntryView({required this.icon, required this.color, required this.title, this.detail});
  final IconData icon;
  final Color color;
  final String title;
  final String? detail;
}

_EntryView _viewFor(TimelineEntry e) {
  String? detail;
  switch (e.activityType) {
    case 'creation':
      return _EntryView(
        icon: Icons.add_circle_outline,
        color: AppColors.navy,
        title: 'created this record',
        detail: (e.dataRaw is String) ? e.dataRaw as String : null,
      );
    case 'comment':
      return _EntryView(
        icon: Icons.chat_bubble_outline,
        color: AppColors.navy,
        title: 'commented',
        detail: _stripHtml(e.contentRaw ?? ''),
      );
    case 'log':
      final d = e.dataRaw;
      if (d is String) {
        detail = _stripHtml(d);
      } else if (d is Map) {
        detail = d.entries.map((kv) => '${kv.key}: ${kv.value}').join(' · ');
      }
      return _EntryView(
        icon: Icons.history_edu,
        color: AppColors.inkMuted,
        title: 'updated',
        detail: detail,
      );
    case 'attachment_log':
      final d = e.dataRaw;
      String label = 'updated an attachment';
      if (d is Map) {
        final type = (d['type'] ?? '').toString();
        final fn = (d['file_name'] ?? '').toString();
        label = type == 'removed' ? 'removed attachment' : 'added attachment';
        detail = fn;
      } else if (d is String) {
        detail = _stripHtml(d);
      }
      return _EntryView(
        icon: Icons.attach_file,
        color: AppColors.warning,
        title: label,
        detail: detail,
      );
    case 'outgoing_call':
      final to = (e.raw['to'] ?? '').toString();
      return _EntryView(
        icon: Icons.call_made,
        color: AppColors.navy,
        title: 'called $to',
        detail: '${e.raw['status'] ?? ''} · ${e.raw['_duration'] ?? ''}'.trim(),
      );
    case 'incoming_call':
      final from = (e.raw['from'] ?? '').toString();
      return _EntryView(
        icon: Icons.call_received,
        color: AppColors.success,
        title: 'received call from $from',
        detail: '${e.raw['status'] ?? ''} · ${e.raw['_duration'] ?? ''}'.trim(),
      );
    case 'communication':
      final subj = (e.subjectRaw ?? '').toString();
      final dir = (e.raw['sent_or_received'] ?? '').toString();
      return _EntryView(
        icon: dir == 'Received' ? Icons.inbox_outlined : Icons.send_outlined,
        color: AppColors.navy,
        title: dir == 'Received' ? 'received email' : 'sent email',
        detail: subj.isEmpty ? null : subj,
      );
    case 'note':
      return _EntryView(
        icon: Icons.note_outlined,
        color: AppColors.navy,
        title: 'added a note',
        detail: (e.raw['title'] ?? '') as String?,
      );
    case 'task':
      return _EntryView(
        icon: Icons.task_alt_outlined,
        color: AppColors.navy,
        title: 'added a task',
        detail: (e.raw['title'] ?? '') as String?,
      );
    default:
      return _EntryView(
        icon: Icons.bolt_outlined,
        color: AppColors.inkMuted,
        title: e.activityType,
        detail: _stripHtml((e.contentRaw ?? '').toString()),
      );
  }
}

String _stripHtml(String s) => s
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
