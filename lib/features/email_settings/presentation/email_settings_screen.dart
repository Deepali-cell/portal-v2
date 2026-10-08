import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../data/email_settings_repository.dart';

/// Portal-side outgoing email (SMTP) setup. A company admin configures their own
/// sending account here — no Frappe/ERPNext knowledge needed. Saving re-encrypts
/// the password with the current key, which also repairs a stale-key decrypt
/// error on the outgoing account.
class EmailSettingsScreen extends ConsumerStatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  ConsumerState<EmailSettingsScreen> createState() =>
      _EmailSettingsScreenState();
}

// value -> (label, smtp, port, tls, ssl). 'custom' shows the manual fields.
const _providers = <String, ({String label, String? host, int port, bool tls, bool ssl})>{
  'gmail': (label: 'Gmail', host: 'smtp.gmail.com', port: 587, tls: true, ssl: false),
  'outlook': (label: 'Outlook / Office 365', host: 'smtp.office365.com', port: 587, tls: true, ssl: false),
  'yahoo': (label: 'Yahoo', host: 'smtp.mail.yahoo.com', port: 465, tls: false, ssl: true),
  'zoho': (label: 'Zoho', host: 'smtp.zoho.com', port: 587, tls: true, ssl: false),
  'custom': (label: 'Custom / Other', host: null, port: 587, tls: true, ssl: false),
};

// Step-by-step guide to create an App Password for each provider. An App
// Password is a 16-char code the provider generates for a single app — it
// works even with 2-step verification on, and you paste it here instead of
// your normal login password.
const _appPwGuides = <String, ({String url, String urlLabel, List<String> steps})>{
  'gmail': (
    url: 'https://myaccount.google.com/apppasswords',
    urlLabel: 'Open Google App Passwords',
    steps: [
      'Turn on 2-Step Verification for your Google account first (App Passwords only appear after it is on).',
      'Open myaccount.google.com/apppasswords (sign in if asked).',
      'Type a name like "Workora" and tap Create.',
      'Google shows a 16-character code — copy it.',
      'Paste that code into the Password field here (no spaces needed).',
    ],
  ),
  'outlook': (
    url: 'https://account.microsoft.com/security',
    urlLabel: 'Open Microsoft Security',
    steps: [
      'Turn on 2-step verification at account.microsoft.com/security.',
      'Go to Advanced security options → App passwords → Create a new app password.',
      'Microsoft shows a code — copy it.',
      'Paste that code into the Password field here.',
    ],
  ),
  'yahoo': (
    url: 'https://login.yahoo.com/account/security',
    urlLabel: 'Open Yahoo Account Security',
    steps: [
      'Open login.yahoo.com/account/security.',
      'Tap "Generate app password" (or Manage app passwords).',
      'Pick "Other app", name it "Workora", and Generate.',
      'Copy the code shown and paste it into the Password field here.',
    ],
  ),
};

class _EmailSettingsScreenState extends ConsumerState<EmailSettingsScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _smtp = TextEditingController();
  final _port = TextEditingController(text: '587');
  String _provider = 'gmail';
  bool _tls = true;
  bool _ssl = false;
  bool _obscure = true;
  bool _saving = false;
  bool _testing = false;
  bool _prefilled = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _password, _smtp, _port]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyProvider(String key) {
    setState(() {
      _provider = key;
      final p = _providers[key]!;
      if (key != 'custom') {
        _smtp.text = p.host ?? '';
        _port.text = '${p.port}';
        _tls = p.tls;
        _ssl = p.ssl;
      }
    });
  }

  // Prefill once from the saved config (password is never returned).
  void _prefill(EmailSettings s) {
    if (_prefilled || !s.configured) return;
    _prefilled = true;
    _email.text = s.emailId ?? '';
    _smtp.text = s.smtpServer ?? '';
    _port.text = '${s.smtpPort ?? 587}';
    _tls = s.useTls;
    _ssl = s.useSsl;
    // Match a known provider by host, else Custom.
    final match = _providers.entries
        .firstWhere((e) => e.value.host == s.smtpServer,
            orElse: () => const MapEntry('custom', (label: '', host: null, port: 587, tls: true, ssl: false)))
        .key;
    _provider = match;
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_provider == 'custom' && _smtp.text.trim().isEmpty) {
      setState(() => _error = 'SMTP server is required for a custom provider.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(emailSettingsRepositoryProvider).save(
            emailId: email,
            password: _password.text,
            provider: _provider == 'custom' ? null : _provider,
            smtpServer: _smtp.text.trim(),
            smtpPort: int.tryParse(_port.text.trim()),
            useTls: _tls,
            useSsl: _ssl,
          );
      ref.invalidate(emailSettingsProvider);
      _password.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email settings saved.')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      _error = null;
      _testing = true;
    });
    try {
      final to = await ref.read(emailSettingsRepositoryProvider).sendTest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Test email sent to $to.')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Test failed. Please try again.');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(emailSettingsProvider);
    final isCustom = _provider == 'custom';
    final needsAppPw = _provider == 'gmail' || _provider == 'outlook' || _provider == 'yahoo';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Email settings'),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _form(context, isCustom, needsAppPw,
            banner: e is ApiException ? e.message : 'Could not load settings.'),
        data: (s) {
          _prefill(s);
          return _form(context, isCustom, needsAppPw,
              configured: s.configured, currentEmail: s.emailId);
        },
      ),
    );
  }

  Widget _form(
    BuildContext context,
    bool isCustom,
    bool needsAppPw, {
    bool configured = false,
    String? currentEmail,
    String? banner,
  }) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding, AppDimens.lg,
          AppDimens.screenPadding, AppDimens.xxxl),
      children: [
        // Intro card.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.mark_email_read_outlined,
                    color: AppColors.navy, size: 22),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Outgoing email',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        configured
                            ? 'Currently sending as ${currentEmail ?? "-"}. Update below to change it.'
                            : 'Set up the account the portal sends emails from.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.lg),

        if (banner != null) ...[
          _Banner(text: banner),
          const SizedBox(height: AppDimens.lg),
        ],

        Text('Provider', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppDimens.sm),
        DropdownButtonFormField<String>(
          initialValue: _provider,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final e in _providers.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value.label)),
          ],
          onChanged: (v) => v == null ? null : _applyProvider(v),
        ),
        const SizedBox(height: AppDimens.lg),

        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'you@company.com',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppDimens.lg),

        TextField(
          controller: _password,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: configured ? 'Password (leave blank to keep)' : 'Password',
            helperText: needsAppPw
                ? 'Use an App Password, not your login password.'
                : null,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),

        // How-to guide for creating an App Password (Gmail/Outlook/Yahoo).
        if (needsAppPw && _appPwGuides[_provider] != null) ...[
          const SizedBox(height: AppDimens.md),
          _AppPasswordHelp(
            providerLabel: _providers[_provider]!.label,
            guide: _appPwGuides[_provider]!,
          ),
        ],

        // Custom SMTP fields.
        if (isCustom) ...[
          const SizedBox(height: AppDimens.lg),
          TextField(
            controller: _smtp,
            decoration: const InputDecoration(
              labelText: 'SMTP server',
              hintText: 'smtp.yourhost.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'SMTP port',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use TLS (STARTTLS)'),
            value: _tls,
            activeThumbColor: AppColors.navy,
            onChanged: (v) => setState(() {
              _tls = v;
              if (v) _ssl = false;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use SSL'),
            value: _ssl,
            activeThumbColor: AppColors.navy,
            onChanged: (v) => setState(() {
              _ssl = v;
              if (v) _tls = false;
            }),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: AppDimens.md),
          Text(_error!,
              style: TextStyle(color: AppColors.danger, fontSize: 13)),
        ],

        const SizedBox(height: AppDimens.xl),
        BrandButton(
          label: 'Save',
          icon: Icons.save_outlined,
          loading: _saving,
          onPressed: _save,
        ),
        const SizedBox(height: AppDimens.md),
        OutlinedButton.icon(
          onPressed: (_testing || !configured) ? null : _test,
          icon: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_outlined),
          label: Text(configured ? 'Send test email' : 'Save first to test'),
        ),
      ],
    );
  }
}

/// Collapsible "How to get an App Password" card with numbered steps and a
/// button that opens the provider's app-password page in the browser.
class _AppPasswordHelp extends StatelessWidget {
  const _AppPasswordHelp({required this.providerLabel, required this.guide});
  final String providerLabel;
  final ({String url, String urlLabel, List<String> steps}) guide;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(guide.url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${guide.url}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.navy.withValues(alpha: 0.04),
      child: Theme(
        // Remove the ExpansionTile's default divider lines.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 2),
          childrenPadding:
              const EdgeInsets.fromLTRB(AppDimens.md, 0, AppDimens.md, AppDimens.md),
          leading: Icon(Icons.help_outline, color: AppColors.navy, size: 20),
          title: Text('How do I get an App Password?',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text('$providerLabel · a code that replaces your password',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.inkMuted)),
          children: [
            Text(
              'An App Password is a one-time 16-character code your email '
              'provider generates for this app. It works even with 2-step '
              'verification on — use it here instead of your normal password.',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppDimens.md),
            for (var i = 0; i < guide.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(guide.steps[i],
                            style: theme.textTheme.bodyMedium),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppDimens.xs),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _open(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(guide.urlLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(text,
                style: TextStyle(color: AppColors.danger, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
