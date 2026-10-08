import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/ui/app_message_dialog.dart';
import '../../../shared/widgets/mic_note_button.dart';

/// Modal bottom sheet for capturing a post-call outcome against a CRM Lead
/// or CRM Deal. Talks to `tcb_portal_erp.api.crm_calls.log_outcome`.
///
/// On success returns the new CRM Call Log id via `Navigator.pop`. The caller
/// should refresh whatever activity list it's showing.
Future<String?> showCallOutcomeSheet(
  BuildContext context, {
  required String referenceDoctype,
  required String referenceDocname,
  required String parentLabel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
    ),
    builder: (_) => _CallOutcomeSheet(
      referenceDoctype: referenceDoctype,
      referenceDocname: referenceDocname,
      parentLabel: parentLabel,
    ),
  );
}

enum _Outcome { connected, voicemail, noAnswer, busy, wrongNumber }

extension on _Outcome {
  String get backendValue => switch (this) {
        _Outcome.connected => 'Connected',
        _Outcome.voicemail => 'Voicemail',
        _Outcome.noAnswer => 'No answer',
        _Outcome.busy => 'Busy',
        _Outcome.wrongNumber => 'Wrong number',
      };
  String get label => switch (this) {
        _Outcome.connected => 'Connected',
        _Outcome.voicemail => 'Voicemail',
        _Outcome.noAnswer => 'No answer',
        _Outcome.busy => 'Busy',
        _Outcome.wrongNumber => 'Wrong number',
      };
  IconData get icon => switch (this) {
        _Outcome.connected => Icons.phone_in_talk,
        _Outcome.voicemail => Icons.voicemail_outlined,
        _Outcome.noAnswer => Icons.phone_missed_outlined,
        _Outcome.busy => Icons.phone_paused_outlined,
        _Outcome.wrongNumber => Icons.phone_disabled_outlined,
      };
}

class _CallOutcomeSheet extends ConsumerStatefulWidget {
  const _CallOutcomeSheet({
    required this.referenceDoctype,
    required this.referenceDocname,
    required this.parentLabel,
  });
  final String referenceDoctype;
  final String referenceDocname;
  final String parentLabel;

  @override
  ConsumerState<_CallOutcomeSheet> createState() => _CallOutcomeSheetState();
}

class _CallOutcomeSheetState extends ConsumerState<_CallOutcomeSheet> {
  _Outcome _outcome = _Outcome.connected;
  bool _outgoing = true;
  final _durationCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  DateTime? _followUp;
  bool _busy = false;
  String? _error;

  static final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void dispose() {
    _durationCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFollowUp() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUp ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _followUp = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final payload = <String, dynamic>{
        'reference_doctype': widget.referenceDoctype,
        'reference_docname': widget.referenceDocname,
        'result': _outcome.backendValue,
        'direction': _outgoing ? 'Outgoing' : 'Incoming',
      };
      final dur = double.tryParse(_durationCtrl.text.trim());
      if (dur != null && dur >= 0) payload['duration_seconds'] = dur;
      final s = _summaryCtrl.text.trim();
      if (s.isNotEmpty) payload['summary'] = s;
      if (_followUp != null) {
        payload['follow_up_date'] =
            '${_followUp!.year.toString().padLeft(4, '0')}-${_followUp!.month.toString().padLeft(2, '0')}-${_followUp!.day.toString().padLeft(2, '0')}';
      }
      final resp = await dio.post(ApiPaths.callLogOutcome, data: payload);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      if (mounted) Navigator.of(context).pop(msg['call_log']?.toString());
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyMessageFor(e).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.xl + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text('Log call outcome',
                  style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(widget.parentLabel,
                  style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: AppDimens.lg),
            _Section('Outcome'),
            const SizedBox(height: AppDimens.xs),
            Wrap(
              spacing: AppDimens.xs,
              runSpacing: AppDimens.xs,
              children: _Outcome.values
                  .map((o) => _OutcomeChip(
                        outcome: o,
                        selected: _outcome == o,
                        onTap: () => setState(() => _outcome = o),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppDimens.md),
            _Section('Direction'),
            const SizedBox(height: AppDimens.xs),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    label: Text('Outgoing'),
                    icon: Icon(Icons.call_made)),
                ButtonSegment(
                    value: false,
                    label: Text('Incoming'),
                    icon: Icon(Icons.call_received)),
              ],
              selected: {_outgoing},
              onSelectionChanged: (s) => setState(() => _outgoing = s.first),
            ),
            const SizedBox(height: AppDimens.md),
            TextField(
              controller: _durationCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Duration (seconds, optional)',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
            const SizedBox(height: AppDimens.md),
            TextField(
              controller: _summaryCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Summary (what was discussed)',
                alignLabelWithHint: true,
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 6),
                  child: MicNoteButton(
                    controller: _summaryCtrl,
                    tooltip: 'Dictate the summary',
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.md),
            InkWell(
              onTap: _busy ? null : _pickFollowUp,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Follow-up date (optional)',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  _followUp == null
                      ? 'None. No follow-up task will be created.'
                      : _dateFmt.format(_followUp!),
                ),
              ),
            ),
            if (_followUp != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      _busy ? null : () => setState(() => _followUp = null),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Clear follow-up'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Container(
                padding: const EdgeInsets.all(AppDimens.md),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: AppColors.onErrorContainer, size: 20),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: Text(_error!,
                          style:
                              TextStyle(color: AppColors.onErrorContainer)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppDimens.xl),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 18),
              label: const Text('Save outcome'),
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

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
    );
  }
}

class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip(
      {required this.outcome, required this.selected, required this.onTap});
  final _Outcome outcome;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(outcome.icon,
                size: 16,
                color:
                    selected ? AppColors.onPrimary : AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              outcome.label,
              style: TextStyle(
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
