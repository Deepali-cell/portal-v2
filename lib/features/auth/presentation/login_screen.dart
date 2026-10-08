import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const _AuroraBackdrop(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimens.screenPadding),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppDimens.maxContentWidth,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: tenant == null
                          ? const _CompanyIdStep(key: ValueKey('company'))
                          : _SignInStep(
                              key: const ValueKey('signin'),
                              tenant: tenant,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Phase 1: Company ID entry
// ============================================================================

class _CompanyIdStep extends ConsumerStatefulWidget {
  const _CompanyIdStep({super.key});

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
    // A company-branded build already knows its company: resolve it straight
    // away instead of asking for the ID.
    if (AppConfig.isBrandedBuild) {
      _idCtrl.text = AppConfig.brandCompanyId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _continue();
      });
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Server set to $_controlHost')));
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
        setState(
          () => _error =
              "Couldn't connect to the server. Check your internet, then try again. Contact your company admin if this keeps happening.",
        );
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
          const _AuthHeader(
            title: 'Welcome to ${AppConfig.brandName}',
            subtitle: 'Your whole workday, in one place.',
          ),
          const SizedBox(height: AppDimens.xl),
          _AuthCard(
            stepLabel: 'Step 1 of 2',
            heading: AppConfig.isBrandedBuild
                ? 'Connecting to your company'
                : 'Find your company',
            caption: AppConfig.isBrandedBuild
                ? 'Setting up the app for ${AppConfig.brandName}.'
                : 'Enter the Company ID shared by your admin.',
            children: [
              TextFormField(
                controller: _idCtrl,
                readOnly: AppConfig.isBrandedBuild,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _continue(),
                decoration: const InputDecoration(
                  labelText: 'Company ID',
                  hintText: 'e.g. ACME',
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
              const SizedBox(height: AppDimens.lg),
              BrandButton(
                label: AppConfig.isBrandedBuild ? 'Retry' : 'Continue',
                icon: Icons.arrow_forward_rounded,
                loading: _submitting,
                onPressed: _continue,
              ),
              if (!AppConfig.isBrandedBuild) ...[
                const SizedBox(height: AppDimens.md),
                const _HelpHint(
                  icon: Icons.help_outline_rounded,
                  text: "Don't know your Company ID? Ask your HR or admin.",
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDimens.md),
          // Control-server selector. Lets one build point at a different control
          // server (e.g. a laptop running its own) without a rebuild. The host
          // in effect is always shown so it is obvious which one you are on.
          if (AppConfig.allowServerOverride)
            TextButton.icon(
              onPressed: _submitting ? null : _changeServer,
              icon: Icon(
                _isCustomControl ? Icons.dns : Icons.dns_outlined,
                size: 16,
                color: _isCustomControl
                    ? AppColors.primary
                    : AppColors.inkFaint,
              ),
              label: Text(
                _controlHost.isEmpty
                    ? 'Change server'
                    : 'Server: $_controlHost${_isCustomControl ? " (custom)" : ""}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _isCustomControl
                      ? AppColors.primary
                      : AppColors.inkFaint,
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
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.current,
  );
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final v = _ctrl.text.trim();
    if (v.isNotEmpty && !AppConfig.isAllowedServerUrl(v)) {
      setState(
        () => _error = 'Must start with https:// (or http:// for local).',
      );
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
            'if your admin told you to, or to point at your own control server.',
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.inkFaint),
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
  const _SignInStep({super.key, required this.tenant});
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
        setState(
          () => _error =
              "Sign-in failed for an unknown reason. Please try again. If it keeps failing, contact your company admin.",
        );
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthHeader(
            title: widget.tenant.companyName,
            subtitle: 'Good to see you again 👋',
          ),
          const SizedBox(height: AppDimens.xl),
          _AuthCard(
            stepLabel: 'Step 2 of 2',
            heading: 'Sign in',
            caption: 'Use your employee email or username.',
            children: [
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
              const SizedBox(height: AppDimens.md),
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
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
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
              const SizedBox(height: AppDimens.lg),
              BrandButton(
                label: 'Sign in',
                icon: Icons.login_rounded,
                loading: _submitting,
                onPressed: _submit,
              ),
              // A company-branded build is locked to its company: switching
              // would just re-resolve the same one, so don't offer it.
              if (!AppConfig.isBrandedBuild) ...[
                const SizedBox(height: AppDimens.sm),
                Center(
                  child: TextButton.icon(
                    onPressed: _submitting ? null : _switchCompany,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Switch company'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDimens.lg),
          const _HelpHint(
            icon: Icons.verified_user_outlined,
            text: 'Your credentials are encrypted on this device.',
            onDark: true,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared error banner
// ============================================================================

/// Full-bleed aurora gradient on the top half of the screen with soft glowing
/// orbs, fading into the light canvas below.
class _AuroraBackdrop extends StatelessWidget {
  const _AuroraBackdrop();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    Widget orb(double size, Color c) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [c.withValues(alpha: 0.55), c.withValues(alpha: 0)],
        ),
      ),
    );
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: h * 0.52,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.heroGradient),
          child: Stack(
            children: [
              Positioned(
                top: -80,
                right: -60,
                child: orb(260, AppColors.violet),
              ),
              Positioned(
                bottom: -90,
                left: -70,
                child: orb(240, AppColors.sky),
              ),
              Positioned(
                top: h * 0.14,
                left: h * 0.18,
                child: orb(120, AppColors.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo + title on the gradient.
class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: AppDimens.lg),
        const BrandWordmark(size: 72, showLabel: false),
        const SizedBox(height: AppDimens.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

/// The white card that holds a login step's form.
class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.stepLabel,
    required this.heading,
    required this.caption,
    required this.children,
  });
  final String stepLabel;
  final String heading;
  final String caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radius3xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.graphite.withValues(alpha: 0.16),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                stepLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.sm + 4),
          Text(heading, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(caption, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppDimens.lg),
          ...children,
        ],
      ),
    );
  }
}

class _HelpHint extends StatelessWidget {
  const _HelpHint({
    required this.icon,
    required this.text,
    this.onDark = false,
  });
  final IconData icon;
  final String text;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
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
