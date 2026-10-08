import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/brand_button.dart';
import '../../call_detection/data/recording_repository.dart';
import '../../leads/application/lead_controller.dart' show leadDetailProvider;
import '../application/providers.dart';
import '../domain/crm_ref.dart';
import '../domain/models.dart';

final _ts = DateFormat('d MMM, h:mm a');

const _callStatuses = [
  'Completed', 'No Answer', 'Busy', 'Failed', 'Canceled',
  'Initiated', 'Ringing', 'In Progress', 'Queued',
];

class CallsTab extends ConsumerWidget {
  const CallsTab({super.key, required this.crmRef, this.suggestedPhone});
  final CrmRef crmRef;
  final String? suggestedPhone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(callsProvider(crmRef));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.canvas,
        icon: const Icon(Icons.add_call),
        label: const Text('Log call'),
        onPressed: () => _openSheet(context, ref),
      ),
      body: _CallsTabBody(
        crmRef: crmRef,
        async: async,
        onDial: (p) => _dial(context, p),
        onDelete: (n) => _delete(context, ref, n),
      ),
    );
  }
}

class _CallsTabBody extends ConsumerWidget {
  const _CallsTabBody({
    required this.crmRef,
    required this.async,
    required this.onDial,
    required this.onDelete,
  });
  final CrmRef crmRef;
  final AsyncValue async;
  final void Function(String) onDial;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(e is ApiException ? e.message : 'Could not load calls.')),
        data: (calls) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(callsProvider(crmRef));
              ref.invalidate(_recordingsProvider(crmRef));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.screenPadding,
                  AppDimens.screenPadding,
                  96),
              children: [
                _RecordingsSection(crmRef: crmRef),
                const SizedBox(height: AppDimens.lg),
                if (calls.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(children: [
                      Icon(Icons.call_outlined,
                          size: 40, color: AppColors.inkFaint),
                      const SizedBox(height: AppDimens.md),
                      Text('No call logs yet',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ]),
                  )
                else ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Text('Call log',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600)),
                  ),
                  for (final c in calls) ...[
                    _CallCard(
                      call: c,
                      onDial: () => onDial(c.type == CallDirection.incoming
                          ? c.fromNo
                          : c.to),
                      onDelete: () => onDelete(c.name),
                    ),
                    const SizedBox(height: AppDimens.sm),
                  ],
                ],
              ],
            ),
          );
        },
      );
  }
}

extension on CallsTab {
  Future<void> _dial(BuildContext context, String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the dialer.')));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete call log?'),
        content: const Text('This entry will be removed permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(crmCollabRepositoryProvider).deleteCall(name);
      ref.invalidate(callsProvider(crmRef));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) =>
          _CallSheet(crmRef: crmRef, suggestedPhone: suggestedPhone),
    );
  }
}

class _CallCard extends StatelessWidget {
  const _CallCard({required this.call, required this.onDial, required this.onDelete});
  final CrmCall call;
  final VoidCallback onDial;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final isIn = call.type == CallDirection.incoming;
    final color = call.status == 'Completed'
        ? AppColors.success
        : (call.status == 'Failed' || call.status == 'No Answer'
            ? AppColors.danger
            : AppColors.warning);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.navyTint,
          child: Icon(
              isIn ? Icons.call_received : Icons.call_made,
              color: AppColors.navy, size: 18),
        ),
        isThreeLine: call.summary != null,
        title: Text(isIn ? call.fromNo : call.to,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${call.status} · ${call.startTime != null ? _ts.format(call.startTime!.toLocal()) : _ts.format(call.creation.toLocal())}'
              '${call.durationSeconds > 0 ? " · ${_dur(call.durationSeconds)}" : ""}',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            if (call.summary != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes,
                      size: 13, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      call.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Call back',
            icon: Icon(Icons.call, color: AppColors.navy),
            onPressed: onDial,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: onDelete,
          ),
        ]),
      ),
    );
  }

  String _dur(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

class _CallSheet extends ConsumerStatefulWidget {
  const _CallSheet({required this.crmRef, this.suggestedPhone});
  final CrmRef crmRef;
  final String? suggestedPhone;
  @override
  ConsumerState<_CallSheet> createState() => _CallSheetState();
}

class _CallSheetState extends ConsumerState<_CallSheet> {
  late final _from = TextEditingController();
  late final _to = TextEditingController(text: widget.suggestedPhone ?? '');
  late final _duration = TextEditingController();
  String _type = 'Outgoing';
  String _status = 'Completed';
  DateTime _when = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _when,
        firstDate: DateTime(_when.year - 1),
        lastDate: DateTime(_when.year + 1));
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (t == null) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_to.text.trim().isEmpty || _from.text.trim().isEmpty) {
      setState(() => _error = 'Both From and To numbers are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dur = int.tryParse(_duration.text.trim());
      await ref.read(crmCollabRepositoryProvider).createCall(
            widget.crmRef,
            fromNo: _from.text.trim(),
            to: _to.text.trim(),
            type: _type,
            status: _status,
            startTime: _when,
            durationSeconds: dur,
          );
      ref.invalidate(callsProvider(widget.crmRef));
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
                child: Text('Log a call',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.xl),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Direction'),
                  items: const [
                    DropdownMenuItem(value: 'Outgoing', child: Text('Outgoing')),
                    DropdownMenuItem(value: 'Incoming', child: Text('Incoming')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _callStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
              ),
            ]),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _from,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'From number'),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _to,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'To number'),
            ),
            const SizedBox(height: AppDimens.lg),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: _pickWhen,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'When',
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(_ts.format(_when),
                        style: TextStyle(color: AppColors.ink)),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration:
                      const InputDecoration(labelText: 'Duration (s)'),
                ),
              ),
            ]),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            BrandButton(
                label: 'Log call', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Phase D.2.5 — Call Recordings + AI Summary section
// ---------------------------------------------------------------------------

final _recordingsProvider = FutureProvider.autoDispose
    .family<List<CallRecording>, CrmRef>((ref, crmRef) {
  final repo = RecordingRepository(ref.watch(dioProvider));
  return repo.listFor(
    referenceDoctype: crmRef.doctype,
    referenceDocname: crmRef.name,
  );
});

/// Non-terminal recording states: while ANY row on this Lead sits in one
/// of these, the section auto-polls the backend every 5s so the user sees
/// the summary + AI-suggested next status card the moment the worker
/// finishes — without pull-to-refresh.
const _inProgressStatuses = {'Uploaded', 'Transcribing', 'Summarizing'};

class _RecordingsSection extends ConsumerStatefulWidget {
  const _RecordingsSection({required this.crmRef});
  final CrmRef crmRef;
  @override
  ConsumerState<_RecordingsSection> createState() =>
      _RecordingsSectionState();
}

class _RecordingsSectionState extends ConsumerState<_RecordingsSection> {
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Kick off / stop polling based on the latest snapshot. Called from
  /// build() after Riverpod hands us fresh data, so we always look at
  /// what the user is actually seeing.
  void _syncPoll(List<CallRecording> recs) {
    final anyInProgress =
        recs.any((r) => _inProgressStatuses.contains(r.status));
    if (anyInProgress) {
      _poll ??= Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        ref.invalidate(_recordingsProvider(widget.crmRef));
      });
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_recordingsProvider(widget.crmRef));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (recs) {
        _syncPoll(recs);
        if (recs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(children: [
                Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('AI call summaries',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            for (final r in recs) ...[
              _RecordingCard(rec: r, crmRef: widget.crmRef),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _RecordingCard extends ConsumerWidget {
  const _RecordingCard({required this.rec, required this.crmRef});
  final CallRecording rec;
  final CrmRef crmRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (badgeColor, badgeIcon) = _statusBadge(rec.status);
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(badgeIcon, size: 12, color: badgeColor),
                const SizedBox(width: 4),
                Text(rec.status,
                    style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 8),
            if (rec.durationSeconds != null && rec.durationSeconds! > 0)
              Text('${_fmtDuration(rec.durationSeconds!)}',
                  style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            if (rec.aiProcessedAt != null)
              Text(DateFormat('d MMM').format(rec.aiProcessedAt!),
                  style: Theme.of(context).textTheme.bodySmall),
          ]),
          if (rec.summary != null && rec.summary!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(rec.summary!,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (rec.keyPoints.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final kp in rec.keyPoints)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('• ',
                      style: TextStyle(color: AppColors.primary)),
                  Expanded(
                      child: Text(kp,
                          style: Theme.of(context).textTheme.bodySmall)),
                ]),
              ),
          ],
          if (rec.isReady) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.article_outlined, size: 16),
                label: const Text('View transcript'),
                onPressed: () => _openTranscript(context, ref),
              ),
            ),
          ],
          if (rec.suggestedStatus != null && rec.suggestedStatus!.isNotEmpty)
            _AiSuggestsBox(rec: rec, crmRef: crmRef, onApply: () => _apply(context, ref)),
          if (rec.errorMessage != null && rec.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(rec.errorMessage!,
                style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  (Color, IconData) _statusBadge(String s) {
    switch (s) {
      case 'Ready':
        return (AppColors.success, Icons.check_circle);
      case 'Failed':
        return (AppColors.danger, Icons.error_outline);
      case 'Uploaded':
      case 'Transcribing':
      case 'Summarizing':
        return (AppColors.navy, Icons.hourglass_empty);
      default:
        return (AppColors.inkFaint, Icons.help_outline);
    }
  }

  String _fmtDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return m > 0 ? '${m}m ${s.toString().padLeft(2, '0')}s' : '${s}s';
  }

  Future<void> _openTranscript(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => _TranscriptSheet(recordingName: rec.name),
    );
  }

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    try {
      final repo = RecordingRepository(ref.read(dioProvider));
      await repo.applySuggestedStatus(rec.name);
      ref.invalidate(_recordingsProvider(crmRef));
      // Also invalidate the parent lead so its status field + chip
      // updates immediately (previously stayed stale until refresh).
      if (crmRef.doctype == 'Lead') {
        ref.invalidate(leadDetailProvider(crmRef.name));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lead status → ${rec.suggestedStatus}'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException
              ? e.message
              : "Couldn't apply status. Try again."),
          backgroundColor: AppColors.errorContainer,
        ));
      }
    }
  }
}

/// Modal bottom sheet showing the full transcript for one recording.
/// The list endpoint (`list_recordings_for`) trims the transcript to keep
/// the payload small, so we lazy-fetch the full doc here via `get(name)`.
class _TranscriptSheet extends ConsumerWidget {
  const _TranscriptSheet({required this.recordingName});
  final String recordingName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future =
        RecordingRepository(ref.watch(dioProvider)).get(recordingName);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppDimens.xl, AppDimens.md, AppDimens.xl, AppDimens.md),
        child: FutureBuilder<CallRecording>(
          future: future,
          builder: (ctx, snap) {
            if (!snap.hasData && !snap.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  snap.error is ApiException
                      ? (snap.error as ApiException).message
                      : "Couldn't load transcript.",
                  style: TextStyle(color: AppColors.danger),
                ),
              );
            }
            final rec = snap.data!;
            final transcript = (rec.transcript ?? '').trim();
            return ListView(
              controller: scroll,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.md),
                Row(children: [
                  Icon(Icons.article_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Call transcript',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                ]),
                if (rec.aiProcessedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Processed ${_ts.format(rec.aiProcessedAt!.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppDimens.lg),
                if (rec.summary != null && rec.summary!.isNotEmpty) ...[
                  Text('Summary',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(rec.summary!,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppDimens.lg),
                ],
                Row(children: [
                  Text('Transcript',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (transcript.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.copy_outlined, size: 14),
                      label: const Text('Copy'),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: transcript));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Transcript copied'),
                              behavior: SnackBarBehavior.floating));
                        }
                      },
                    ),
                ]),
                const SizedBox(height: 6),
                if (transcript.isEmpty)
                  Text('No transcript captured for this recording.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic))
                else
                  SelectableText(transcript,
                      style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppDimens.xl),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Ordered SMB sales workflow. Position maps to how "advanced" a status
/// is in the pipeline — used to decide whether a suggestion is still
/// actionable ("Apply Nurture" on a Contacted lead) or the lead has
/// already outrun it ("Apply New" on a Nurture lead — meaningless).
///
/// Terminal states (Junk / Unqualified / Converted) get very large
/// positions so anything is considered "past" them. Unknown statuses
/// return null → we skip the ordering check and default to Apply so a
/// misconfigured tenant doesn't silently swallow the button.
int? _statusOrderPosition(String status) {
  const order = <String, int>{
    'new': 0,
    'contacted': 1,
    'follow-up': 2,
    'nurture': 3,
    'responded': 4,
    'discovery scheduled': 5,
    'qualified': 6,
    'hot': 7,
    // Terminal — anything qualifies as "past" these once they're set.
    'unqualified': 900,
    'junk': 901,
    'converted': 902,
  };
  return order[status.trim().toLowerCase()];
}

/// AI-suggested-status card — 4-state machine:
///
///   1. **Applied** — `rec.suggestionAppliedAt` is stamped. Shows
///      "✓ Applied: {from} → {suggested}". Never re-offers Apply.
///   2. **Already at target** — lead's current status equals suggested
///      (not applied). "✓ Already at {suggested}".
///   3. **Lead moved past** — lead's current position > suggested
///      position in the workflow (not applied). "→ Lead moved past —
///      currently {current}". No button — applying would rewind.
///   4. **Actionable** — none of the above. Renders the Apply button.
///
/// State selection is order-dependent: 1 > 2 > 3 > 4. So if a lead was
/// applied then later moved further, we still surface the audit trail
/// (Applied: X → Y) rather than the current mismatch.
class _AiSuggestsBox extends ConsumerWidget {
  const _AiSuggestsBox({
    required this.rec,
    required this.crmRef,
    required this.onApply,
  });
  final CallRecording rec;
  final CrmRef crmRef;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggested = rec.suggestedStatus!.trim();
    String? currentStatus;
    if (crmRef.doctype == 'Lead') {
      currentStatus =
          ref.watch(leadDetailProvider(crmRef.name)).value?.status;
    }

    // State selection.
    final Widget trailing;
    if (rec.suggestionAppliedAt != null) {
      // State 1: applied. Prefer the stamped from-status; fall back to
      // a plain dash only if the stamp somehow missed (shouldn't happen
      // post-fix).
      final from =
          (rec.suggestionAppliedFromStatus ?? '').trim().isNotEmpty
              ? rec.suggestionAppliedFromStatus!
              : '-';
      trailing = _appliedRow(from: from, to: suggested);
    } else if (currentStatus != null &&
        currentStatus.toLowerCase() == suggested.toLowerCase()) {
      // State 2: already at target (independent of user action).
      trailing = _alreadyAtRow(status: suggested);
    } else if (crmRef.doctype == 'Lead' &&
        _hasMovedPast(currentStatus, suggested)) {
      // State 3: lead progressed past the suggestion. Applying would
      // rewind, which is never right for a sales pipeline.
      trailing = _movedPastRow(currentStatus: currentStatus!);
    } else if (crmRef.doctype == 'Lead') {
      // State 4 — actionable.
      trailing = FilledButton.tonalIcon(
        icon: const Icon(Icons.check, size: 16),
        label: Text('Apply $suggested'),
        onPressed: onApply,
      );
    } else {
      // Non-Lead crmRef (e.g. Deal) — apply flow is Lead-only; render
      // the suggestion as read-only info.
      trailing = const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI suggests',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Text('Status → $suggested',
                style: TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600)),
            if (rec.suggestedNextAction != null &&
                rec.suggestedNextAction!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(rec.suggestedNextAction!,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ),
      ),
    );
  }

  bool _hasMovedPast(String? current, String suggested) {
    if (current == null) return false;
    final cp = _statusOrderPosition(current);
    final sp = _statusOrderPosition(suggested);
    if (cp == null || sp == null) return false;
    return cp > sp;
  }

  Widget _appliedRow({required String from, required String to}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Text('Applied: $from → $to',
              style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      );

  Widget _alreadyAtRow({required String status}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Text('Already at $status',
              style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      );

  Widget _movedPastRow({required String currentStatus}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_forward, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('Lead moved past. Now $currentStatus',
              style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      );
}
