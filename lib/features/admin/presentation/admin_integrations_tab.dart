import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/ui/app_message_dialog.dart';
import '../application/admin_controller.dart';
import '../domain/models.dart';

/// Admin > Integrations: the site admin connects WhatsApp, AI call summaries
/// and push notifications from the app instead of editing site_config.json.
///
/// Secrets go to the server once and are stored encrypted; they never come
/// back — a saved secret shows as "saved", and leaving the box empty keeps
/// it. Every save runs a live connection test and shows the result.
class AdminIntegrationsTab extends ConsumerWidget {
  const AdminIntegrationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(integrationsProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(integrationsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: Text(
                friendlyMessageFor(e).message,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        data: (data) {
          Map<String, dynamic> m(String k) =>
              ((data[k] as Map?) ?? const {}).cast<String, dynamic>();
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimens.md),
            children: [
              _WhatsAppCard(m('whatsapp')),
              _AiCard(m('ai')),
              _PushCard(m('push')),
              const _EmailCard(),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

/// Card frame: title, status chip, body, and the last test result.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.icon,
    required this.title,
    required this.status,
    required this.children,
    this.result,
  });
  final IconData icon;
  final String title;
  final Map<String, dynamic> status;
  final List<Widget> children;
  final IntegrationResult? result;

  @override
  Widget build(BuildContext context) {
    final configured = status['configured'] == true;
    final source = status['source'];
    final (label, color) = !configured
        ? ('Not connected', AppColors.outline)
        : source == 'app'
        ? ('Connected', const Color(0xFF15803D))
        : ('Set in server config', AppColors.primary);
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.md),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            ...children,
            if (result != null) ...[
              const SizedBox(height: AppDimens.sm),
              _ResultBanner(result!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner(this.r);
  final IntegrationResult r;

  @override
  Widget build(BuildContext context) {
    final color = r.ok ? const Color(0xFF15803D) : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            r.ok ? Icons.check_circle : Icons.error_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              r.message,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _field(
  TextEditingController c,
  String label, {
  String? hint,
  bool secret = false,
  bool secretSaved = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppDimens.sm),
    child: TextField(
      controller: c,
      obscureText: secret,
      autocorrect: !secret,
      enableSuggestions: !secret,
      decoration: InputDecoration(
        labelText: label,
        hintText: secret && secretSaved
            ? '●●●● saved — leave empty to keep'
            : hint,
        floatingLabelBehavior: secret && secretSaved
            ? FloatingLabelBehavior.always
            : null,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

/// Save / Test / Remove row. [onSave] null hides Save (push uses Upload).
class _Actions extends StatelessWidget {
  const _Actions({
    required this.busy,
    required this.canTest,
    required this.canRemove,
    required this.onTest,
    required this.onRemove,
    this.onSave,
  });
  final bool busy;
  final bool canTest;
  final bool canRemove;
  final VoidCallback onTest;
  final VoidCallback onRemove;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onSave != null)
          FilledButton.icon(
            onPressed: busy ? null : onSave,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save & test'),
          ),
        OutlinedButton(
          onPressed: busy || !canTest ? null : onTest,
          child: const Text('Test'),
        ),
        if (canRemove)
          TextButton(
            onPressed: busy ? null : onRemove,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
      ],
    );
  }
}

/// Common save/test/remove plumbing for the integration cards.
mixin _IntegrationActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool busy = false;
  IntegrationResult? result;

  String get integration;

  Future<void> run(Future<IntegrationResult> Function() action) async {
    setState(() => busy = true);
    try {
      final r = await action();
      if (mounted) setState(() => result = r);
      ref.invalidate(integrationsProvider);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => result = IntegrationResult(ok: false, message: e.message),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> test() =>
      run(() => ref.read(adminRepositoryProvider).testIntegration(integration));

  Future<void> remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this integration?'),
        content: const Text(
          'The settings saved here are deleted. If the server config has '
          'its own values, those are used again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await ref.read(adminRepositoryProvider).clearIntegration(integration);
      if (mounted) setState(() => result = null);
      ref.invalidate(integrationsProvider);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => result = IntegrationResult(ok: false, message: e.message),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

// ---------------------------------------------------------------------------
// WhatsApp
// ---------------------------------------------------------------------------

class _WhatsAppCard extends ConsumerStatefulWidget {
  const _WhatsAppCard(this.data);
  final Map<String, dynamic> data;
  @override
  ConsumerState<_WhatsAppCard> createState() => _WhatsAppCardState();
}

class _WhatsAppCardState extends ConsumerState<_WhatsAppCard>
    with _IntegrationActions {
  late final _phoneId = TextEditingController(
    text: widget.data['phone_number_id'] as String?,
  );
  final _token = TextEditingController();
  final _secret = TextEditingController();
  final _verify = TextEditingController();
  late final _template = TextEditingController(
    text: widget.data['template_name'] as String?,
  );
  late final _lang = TextEditingController(
    text: (widget.data['template_language'] as String?) ?? 'en',
  );
  late bool _param = widget.data['template_param'] != false;

  @override
  String get integration => 'whatsapp';

  @override
  void dispose() {
    for (final c in [_phoneId, _token, _secret, _verify, _template, _lang]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await run(
      () => ref.read(adminRepositoryProvider).saveIntegration('whatsapp', {
        'phone_number_id': _phoneId.text.trim(),
        'access_token': _token.text.trim(),
        'app_secret': _secret.text.trim(),
        'verify_token': _verify.text.trim(),
        'template_name': _template.text.trim(),
        'template_language': _lang.text.trim(),
        'template_param': _param,
      }),
    );
    for (final c in [_token, _secret, _verify]) {
      c.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final webhook = (d['webhook_url'] ?? '').toString();
    return _Frame(
      icon: Icons.chat_outlined,
      title: 'WhatsApp Business',
      status: d,
      result: result,
      children: [
        Text(
          'Salespeople send WhatsApp from the app using your company number; '
          "customers' replies show up on the lead/deal. Replies within 24 "
          'hours of the customer messaging you are free.',
          style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppDimens.md),
        _field(_phoneId, 'Phone Number ID'),
        _field(
          _token,
          'Access Token',
          secret: true,
          secretSaved: d['access_token_set'] == true,
        ),
        _field(
          _secret,
          'App Secret',
          secret: true,
          secretSaved: d['app_secret_set'] == true,
        ),
        _field(
          _verify,
          'Webhook Verify Token',
          hint: 'Any word — type the same in Meta',
          secret: true,
          secretSaved: d['verify_token_set'] == true,
        ),
        _webhookRow(webhook),
        const SizedBox(height: AppDimens.sm),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'First-contact template (optional, paid)',
            style: TextStyle(fontSize: 13.5),
          ),
          children: [
            _field(
              _template,
              'Template name',
              hint: 'Empty = customer must message first (free)',
            ),
            _field(_lang, 'Template language', hint: 'en'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Send the typed text as {{1}}'),
              value: _param,
              onChanged: (v) => setState(() => _param = v),
            ),
          ],
        ),
        _Actions(
          busy: busy,
          canTest: d['configured'] == true,
          canRemove: d['source'] == 'app',
          onSave: _save,
          onTest: test,
          onRemove: remove,
        ),
      ],
    );
  }

  Widget _webhookRow(String url) => Container(
    padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Webhook URL (paste in Meta, subscribe to "messages")',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(url, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Webhook URL copied')));
          },
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// AI call summaries
// ---------------------------------------------------------------------------

class _AiCard extends ConsumerStatefulWidget {
  const _AiCard(this.data);
  final Map<String, dynamic> data;
  @override
  ConsumerState<_AiCard> createState() => _AiCardState();
}

class _AiCardState extends ConsumerState<_AiCard> with _IntegrationActions {
  static const _providers = {
    'groq': 'Groq (free tier)',
    'openai': 'OpenAI',
    'anthropic': 'Anthropic (Claude)',
  };

  late String _provider =
      (widget.data['provider'] as String?)?.isNotEmpty == true
      ? widget.data['provider'] as String
      : 'groq';
  final _key = TextEditingController();
  late final _model = TextEditingController(
    text: widget.data['model'] as String?,
  );

  @override
  String get integration => 'ai';

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await run(
      () => ref.read(adminRepositoryProvider).saveIntegration('ai', {
        'provider': _provider,
        'api_key': _key.text.trim(),
        'model': _model.text.trim(),
      }),
    );
    _key.clear();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final defaults = ((d['default_models'] as Map?) ?? const {})
        .cast<String, dynamic>();
    // A saved key belongs to the saved provider; switching provider needs a new one.
    final keySaved =
        d['api_key_set'] == true && (d['provider'] ?? '') == _provider;
    return _Frame(
      icon: Icons.auto_awesome_outlined,
      title: 'AI call summaries',
      status: d,
      result: result,
      children: [
        Text(
          'Recorded sales calls are transcribed and summarised with next steps.',
          style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppDimens.md),
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.sm),
          child: DropdownButtonFormField<String>(
            initialValue: _provider,
            decoration: InputDecoration(
              labelText: 'Provider',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: [
              for (final e in _providers.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _provider = v ?? _provider),
          ),
        ),
        _field(_key, 'API Key', secret: true, secretSaved: keySaved),
        _field(
          _model,
          'Summary model (optional)',
          hint: 'Default: ${defaults[_provider] ?? ''}',
        ),
        if (_provider == 'anthropic')
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.sm),
            child: Text(
              'Claude cannot transcribe audio; transcription keeps using the '
              "server's own setting.",
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
        _Actions(
          busy: busy,
          canTest: d['configured'] == true,
          canRemove: d['source'] == 'app',
          onSave: _save,
          onTest: test,
          onRemove: remove,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Push notifications
// ---------------------------------------------------------------------------

class _PushCard extends ConsumerStatefulWidget {
  const _PushCard(this.data);
  final Map<String, dynamic> data;
  @override
  ConsumerState<_PushCard> createState() => _PushCardState();
}

class _PushCardState extends ConsumerState<_PushCard> with _IntegrationActions {
  @override
  String get integration => 'push';

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return;
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      setState(
        () => result = const IntegrationResult(
          ok: false,
          message: 'That file is not a text JSON file.',
        ),
      );
      return;
    }
    await run(
      () => ref.read(adminRepositoryProvider).uploadPushServiceAccount(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final project = (d['project_id'] ?? '').toString();
    return _Frame(
      icon: Icons.notifications_active_outlined,
      title: 'Push notifications',
      status: d,
      result: result,
      children: [
        Text(
          'Firebase Console > Project settings > Service accounts > Generate '
          'new private key, then upload that JSON file here.',
          style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceVariant),
        ),
        if (project.isNotEmpty) ...[
          const SizedBox(height: AppDimens.sm),
          Text(
            'Firebase project: $project',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: AppDimens.md),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : _upload,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(
                d['file_set'] == true ? 'Replace JSON' : 'Upload JSON',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _Actions(
          busy: busy,
          canTest: d['configured'] == true,
          canRemove: d['source'] == 'app',
          onTest: test,
          onRemove: remove,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Email (already has its own screen)
// ---------------------------------------------------------------------------

class _EmailCard extends StatelessWidget {
  const _EmailCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.md),
      child: ListTile(
        leading: Icon(Icons.alternate_email, color: AppColors.primary),
        title: const Text(
          'Email (SMTP)',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        subtitle: const Text('Outgoing email for leads and deals'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(Routes.emailSettings),
      ),
    );
  }
}
