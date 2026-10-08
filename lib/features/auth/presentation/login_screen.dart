import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../features/attendance/data/attendance_repository.dart';
import '../../../features/tenant/application/tenant_controller.dart';
import '../../../features/tenant/domain/tenant.dart';
import '../../../shared/widgets/brand_button.dart';
import '../../../shared/widgets/brand_wordmark.dart';
import '../application/auth_controller.dart';

/// The login screen has two phases:
///
///  1. **Company ID** — shown when there is no resolved tenant on this device
///     (fresh install, or right after "Switch company"). One field plus a
///     Continue button. Calls the middleware's resolve endpoint on submit.
///
///  2. **Sign in** — shown when a tenant is resolved (either freshly or from
///     cached state). Username + Password + Sign in. Also shows a "Switch
///     company" link to drop the cached tenant and return to phase 1.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.screenPadding),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
              child: tenant == null
                  ? const _CompanyIdStep()
                  : _SignInStep(tenant: tenant),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Phase 1: Company ID entry
// ============================================================================

class _CompanyIdStep extends ConsumerStatefulWidget {
  const _CompanyIdStep();

  @override
  ConsumerState<_CompanyIdStep> createState() => _CompanyIdStepState();
}

class _CompanyIdStepState extends ConsumerState<_CompanyIdStep> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _controlUrl; // the control server currently in effect

  @override
  void initState() {
    super.initState();
    _loadControlUrl();
  }

  Future<void> _loadControlUrl() async {
    final url = await ref.read(tenantRepositoryProvider).controlBaseUrl();
    if (!mounted) return;
    setState(() => _controlUrl = url);
  }

  String get _controlHost {
    final u = _controlUrl;
    if (u == null || u.isEmpty) return '';
    return Uri.tryParse(u)?.host ?? u;
  }

  bool get _isCustomControl =>
      _controlUrl != null &&
      _controlUrl!.replaceAll(RegExp(r'/+$'), '') !=
          AppConfig.middlewareBaseUrl.replaceAll(RegExp(r'/+$'), '');

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeServer() async {
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => _ServerDialog(current: _controlUrl ?? ''),
    );
    if (result == null) return; // cancelled
    final store = ref.read(secureStoreProvider);
    if (result.isEmpty) {
      await store.clearControlUrl(); // back to the built-in default
    } else {
      await store.writeControlUrl(result);
    }
    await _loadControlUrl();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server set to $_controlHost')),
      );
    }
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(tenantControllerProvider.notifier)
          .resolveAndSet(_idCtrl.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            "Couldn't connect to the TCB server. Check your internet, then try again. Contact TCB Infotech if this keeps happening.");
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppDimens.xxxl),
          const BrandWordmark(size: 76),
          const SizedBox(height: AppDimens.xxl),
          Text(
            'Sign in to TCB Portal',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppDimens.xs),
          Text(
            'Enter your Company ID to continue.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimens.xxl),
          TextFormField(
            controller: _idCtrl,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _continue(),
            decoration: const InputDecoration(
              labelText: 'Company ID',
              hintText: 'e.g. TCB',
              prefixIcon: Icon(Icons.domain_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Enter your Company ID'
                : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppDimens.lg),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: AppDimens.xl),
          BrandButton(
            label: 'Continue',
            loading: _submitting,
            onPressed: _continue,
          ),
          const SizedBox(height: AppDimens.xl),
          Text(
            "Don't know your Company ID? Contact TCB Infotech.",
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodySmall?.copyWith(color: AppColors.inkFaint),
          ),
          const SizedBox(height: AppDimens.lg),
          // Control-server selector. Lets one build point at a different control
          // server (e.g. a laptop running its own) without a rebuild. The host
          // in effect is always shown so it is obvious which one you are on.
          if (AppConfig.allowServerOverride) TextButton.icon(
            onPressed: _submitting ? null : _changeServer,
            icon: Icon(
              _isCustomControl ? Icons.dns : Icons.dns_outlined,
              size: 16,
              color: _isCustomControl ? AppColors.primary : AppColors.inkFaint,
            ),
            label: Text(
              _controlHost.isEmpty
                  ? 'Change server'
                  : 'Server: $_controlHost${_isCustomControl ? " (custom)" : ""}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _isCustomControl ? AppColors.primary : AppColors.inkFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Control-server dialog (advanced): point the app at a different control server
// ============================================================================
class _ServerDialog extends StatefulWidget {
  const _ServerDialog({required this.current});
  final String current;

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.current);
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final v = _ctrl.text.trim();
    if (v.isNotEmpty && !AppConfig.isAllowedServerUrl(v)) {
      setState(() => _error = 'Must start with https:// (or http:// for local).');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Control server'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'The server that looks up your Company ID at login. Change it only '
            'if TCB told you to, or to point at your own control server.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimens.md),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Control server URL',
              hintText: 'https://swab-writing-upload.ngrok-free.dev',
              errorText: _error,
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            'Default: ${AppConfig.middlewareBaseUrl}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.inkFaint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        // Empty string signals "reset to the built-in default".
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: const Text('Use default'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// ============================================================================
// Phase 2: Username + Password
// ============================================================================

class _SignInStep extends ConsumerStatefulWidget {
  const _SignInStep({required this.tenant});
  final Tenant tenant;

  @override
  ConsumerState<_SignInStep> createState() => _SignInStepState();
}

class _SignInStepState extends ConsumerState<_SignInStep> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_userCtrl.text, _pwdCtrl.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            "Sign-in failed for an unknown reason. Please try again. If it keeps failing, contact TCB Infotech.");
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _switchCompany() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch company?'),
        content: const Text(
          'You will need to enter your Company ID again. Cached data will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Wipe everything that could belong to the previous tenant:
    //  * SecureStore — auth token, cached profile, cached tenant, biometric.
    //  * Hive boxes — offline checkin queue (more boxes go here as added).
    //  * Tenant controller state — back to null so the login screen shows
    //    the Company ID step again.
    await ref.read(secureStoreProvider).clearAll();
    await _clearLocalCaches();
    await ref.read(tenantControllerProvider.notifier).clear();
  }

  Future<void> _clearLocalCaches() async {
    final boxName = AttendanceRepository.boxName;
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppDimens.xxxl),
          const BrandWordmark(size: 76),
          const SizedBox(height: AppDimens.xxl),
          Text(
            widget.tenant.companyName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppDimens.xs),
          Text(
            'Sign in to your employee account',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimens.xxl),
          TextFormField(
            controller: _userCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              labelText: 'Email or username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Enter your email or username'
                : null,
          ),
          const SizedBox(height: AppDimens.lg),
          TextFormField(
            controller: _pwdCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your password' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppDimens.lg),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: AppDimens.xl),
          BrandButton(
            label: 'Sign in',
            loading: _submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: AppDimens.lg),
          TextButton(
            onPressed: _submitting ? null : _switchCompany,
            child: const Text('Switch company'),
          ),
          const SizedBox(height: AppDimens.md),
          Text(
            'Your credentials are encrypted on this device.',
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodySmall?.copyWith(color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared error banner
// ============================================================================

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.danger, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
