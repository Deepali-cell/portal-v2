import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/ui/app_message_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/presentation/nav_destinations.dart';
import '../application/admin_controller.dart';
import '../domain/models.dart';

/// Admin > Screens: switch individual app screens on/off for everyone on this
/// site, inside the modules the company is licensed for.
///
/// Three layers decide what a user sees: the module licence (set by TCB,
/// read-only here), these screen switches, and the user's role permissions
/// (Doctypes tab). A screen shows only when all three allow it.
class AdminScreensTab extends ConsumerStatefulWidget {
  const AdminScreensTab({super.key});

  @override
  ConsumerState<AdminScreensTab> createState() => _AdminScreensTabState();
}

class _AdminScreensTabState extends ConsumerState<AdminScreensTab> {
  /// Working copy of the switched-off ids; null until the config loads.
  Set<String>? _disabled;
  Set<String> _saved = const {};
  bool _saving = false;

  bool get _dirty =>
      _disabled != null &&
      (_disabled!.length != _saved.length || !_disabled!.containsAll(_saved));

  Future<void> _save() async {
    final disabled = _disabled;
    if (disabled == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).setDisabledScreens(disabled);
      _saved = {...disabled};
      // Apply to this admin's own nav straight away; other users pick it up
      // the next time their app refreshes their profile.
      await ref.read(authControllerProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved. Users see the change next time they open the app.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(screenConfigProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Text(
            friendlyMessageFor(e).message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (cfg) {
        if (_disabled == null) {
          _disabled = {...cfg.disabledScreens};
          _saved = {...cfg.disabledScreens};
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              setState(() => _disabled = null);
              ref.invalidate(screenConfigProvider);
              await Future<void>.delayed(const Duration(milliseconds: 400));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppDimens.md,
                AppDimens.md,
                AppDimens.md,
                96,
              ),
              children: [
                Text(
                  'Turn screens off for everyone in your company. Modules come '
                  'from your licence; role permissions still apply on top.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppDimens.md),
                for (final m in cfg.modules) _module(m),
              ],
            ),
          ),
          floatingActionButton: _dirty
              ? FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                )
              : null,
        );
      },
    );
  }

  Widget _module(LicensedModule m) {
    final prefix = '${m.key}.';
    final screens = allDestinations
        .where((d) => d.id.startsWith(prefix))
        .toList();
    final subs = allSubScreens.where((s) => s.id.startsWith(prefix)).toList();
    if (screens.isEmpty && subs.isEmpty) return const SizedBox.shrink();
    final disabled = _disabled!;
    final ids = [...screens.map((d) => d.id), ...subs.map((s) => s.id)];
    final onCount = ids.where((id) => !disabled.contains(id)).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.md),
      child: Card(
        margin: EdgeInsets.zero,
        child: Theme(
          // Drop ExpansionTile's own dividers; the card already frames it.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            enabled: m.enabled,
            title: Text(
              m.label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: m.enabled ? AppColors.onSurface : AppColors.outline,
              ),
            ),
            subtitle: Text(
              m.enabled
                  ? '$onCount of ${ids.length} screens on'
                  : 'Not in your licence. Contact your provider to enable.',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            leading: Icon(
              m.enabled ? Icons.verified_outlined : Icons.lock_outline,
              color: m.enabled ? AppColors.primary : AppColors.outline,
            ),
            children: [
              for (final d in screens)
                _switch(d.id, d.icon, _screenLabel(d), disabled),
              if (subs.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.md,
                    AppDimens.sm,
                    AppDimens.md,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Opened from inside the module',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                for (final sc in subs)
                  _switch(sc.id, sc.icon, sc.label, disabled),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _switch(
    String id,
    IconData icon,
    String label,
    Set<String> disabled,
  ) => SwitchListTile(
    dense: true,
    secondary: Icon(icon, color: AppColors.primary),
    title: Text(label),
    value: !disabled.contains(id),
    onChanged: (on) => setState(() {
      on ? disabled.remove(id) : disabled.add(id);
    }),
  );

  /// Manufacturing holds two nav groups; label the Masters ones so e.g.
  /// "Items" reads clearly next to the production screens.
  String _screenLabel(NavDest d) => switch (d.module) {
        'Manufacturing Masters' => 'Masters · ${d.label}',
        // Self-service screens sit on Home, outside the module tiles.
        null => 'Self-service · ${d.label}',
        _ => d.label,
      };
}
