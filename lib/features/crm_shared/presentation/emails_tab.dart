import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../../auth/application/auth_controller.dart';
import '../application/providers.dart';
import '../domain/crm_ref.dart';
import '../domain/models.dart';

final _ts = DateFormat('d MMM, h:mm a');

class EmailsTab extends ConsumerWidget {
  const EmailsTab({super.key, required this.crmRef, this.suggestedTo});
  final CrmRef crmRef;
  final String? suggestedTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(emailsProvider(crmRef));
    final isAdmin =
        ref.watch(authControllerProvider).profile?.can('admin') ?? false;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isAdmin) ...[
            FloatingActionButton.small(
              heroTag: 'emailSettingsFab',
              tooltip: 'Email settings',
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.navy,
              elevation: 1,
              onPressed: () => context.push(Routes.emailSettings),
              child: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(height: AppDimens.sm),
          ],
          FloatingActionButton.extended(
            heroTag: 'composeEmailFab',
            backgroundColor: AppColors.navy,
            foregroundColor: AppColors.canvas,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Compose'),
            onPressed: () => _compose(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(e is ApiException ? e.message : 'Could not load emails.')),
        data: (emails) {
          if (emails.isEmpty) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mail_outline,
                    size: 40, color: AppColors.inkFaint),
                const SizedBox(height: AppDimens.md),
                Text('No emails yet. Tap "Compose" to send the first.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center),
              ]),
            ));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(emailsProvider(crmRef)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding, AppDimens.screenPadding, AppDimens.screenPadding, 96),
              itemCount: emails.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppDimens.sm),
              itemBuilder: (_, i) => _EmailCard(email: emails[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => _ComposeSheet(crmRef: crmRef, defaultTo: suggestedTo),
    );
  }
}

class _EmailCard extends StatelessWidget {
  const _EmailCard({required this.email});
  final CrmEmail email;

  @override
  Widget build(BuildContext context) {
    final dirColor = email.sent ? AppColors.navy : AppColors.success;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(email.sent ? Icons.send : Icons.inbox,
                      size: 16, color: dirColor),
                  const SizedBox(width: AppDimens.xs),
                  Text(email.sent ? 'Sent' : 'Received',
                      style: TextStyle(
                          color: dirColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                  const Spacer(),
                  Text(_ts.format(email.creation.toLocal()),
                      style: TextStyle(
                          color: AppColors.inkFaint, fontSize: 12)),
                ],
              ),
              const SizedBox(height: AppDimens.xs),
              Text(email.subject,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                email.sent
                    ? 'To: ${email.recipients ?? "-"}'
                    : 'From: ${email.senderFullName ?? email.sender}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (email.content != null && email.content!.isNotEmpty) ...[
                const SizedBox(height: AppDimens.xs),
                Text(
                  _stripHtml(email.content!),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final dirColor = email.sent ? AppColors.navy : AppColors.success;
    final theme = Theme.of(context);
    final body = _stripHtml(email.content ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(AppDimens.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: direction badge + close.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppDimens.lg, AppDimens.md, AppDimens.sm, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: dirColor.withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(email.sent ? Icons.send : Icons.inbox,
                            size: 14, color: dirColor),
                        const SizedBox(width: AppDimens.xs),
                        Text(email.sent ? 'Sent' : 'Received',
                            style: TextStyle(
                                color: dirColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      ]),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Subject + meta.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppDimens.lg, AppDimens.xs, AppDimens.lg, AppDimens.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email.subject, style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppDimens.sm),
                    _MetaRow(label: 'From', value: email.sender),
                    _MetaRow(label: 'To', value: email.recipients ?? '-'),
                    _MetaRow(
                        label: 'Date',
                        value: _ts.format(email.creation.toLocal())),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scrollable body.
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimens.lg),
                  child: Text(
                    body.isEmpty ? '(No content)' : body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Pinned footer button — never scrolls away.
              Padding(
                padding: const EdgeInsets.all(AppDimens.md),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stripHtml(String s) => s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(label,
                style: style?.copyWith(
                    color: AppColors.inkFaint, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}

class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet({required this.crmRef, this.defaultTo});
  final CrmRef crmRef;
  final String? defaultTo;
  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  late final _to = TextEditingController(text: widget.defaultTo ?? '');
  final _cc = TextEditingController();
  final _bcc = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _showCcBcc = false;
  bool _meCopy = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_to, _cc, _bcc, _subject, _body]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _error = null);
    if (_to.text.trim().isEmpty) {
      setState(() => _error = 'Recipient is required.');
      return;
    }
    if (_subject.text.trim().isEmpty) {
      setState(() => _error = 'Subject is required.');
      return;
    }
    if (_body.text.trim().isEmpty) {
      setState(() => _error = 'Body is required.');
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(crmCollabRepositoryProvider).sendEmail(
            widget.crmRef,
            subject: _subject.text.trim(),
            content: _body.text.trim().replaceAll('\n', '<br>'),
            recipients: _to.text.trim(),
            cc: _cc.text.trim().isEmpty ? null : _cc.text.trim(),
            bcc: _bcc.text.trim().isEmpty ? null : _bcc.text.trim(),
            meCopy: _meCopy,
          );
      ref.invalidate(emailsProvider(widget.crmRef));
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Email sent.')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
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
                child: Text('Compose email',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.xl),
            TextField(
              controller: _to,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'To',
                helperText: 'Multiple recipients separated by commas',
              ),
            ),
            if (_showCcBcc) ...[
              const SizedBox(height: AppDimens.lg),
              TextField(
                controller: _cc,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Cc'),
              ),
              const SizedBox(height: AppDimens.lg),
              TextField(
                controller: _bcc,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Bcc'),
              ),
            ] else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showCcBcc = true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Cc / Bcc'),
                ),
              ),
            const SizedBox(height: AppDimens.md),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _body,
              minLines: 8,
              maxLines: 14,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Send me a copy'),
              value: _meCopy,
              activeThumbColor: AppColors.navy,
              onChanged: (v) => setState(() => _meCopy = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: TextStyle(color: AppColors.danger, fontSize: 13)),
              if (ref.watch(authControllerProvider).profile?.can('admin') ??
                  false) ...[
                const SizedBox(height: AppDimens.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(Routes.emailSettings);
                    },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Set up email'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppDimens.xl),
            BrandButton(
              label: 'Send',
              icon: Icons.send,
              loading: _sending,
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}
