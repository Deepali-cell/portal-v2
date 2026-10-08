import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/ui/app_message_dialog.dart';
import '../application/admin_controller.dart';
import '../domain/models.dart';
import 'admin_integrations_tab.dart';
import 'admin_screens_tab.dart';

/// In-app Administrator, ERPNext Role Permission Manager style. Two tabs:
///
///  * Doctypes: pick a Doctype + Role, toggle that role's real Frappe
///    permissions (writes to Custom DocPerm - the same store the desk Role
///    Permission Manager edits).
///  * Reports: pick a curated report, toggle which roles may run it (writes to
///    the report's own Frappe roles list).
///  * Screens: switch app screens on/off for the whole site, inside the
///    modules the company's TCB licence includes.
///  * Integrations: connect WhatsApp, AI call summaries, push and email.
///  * Setup check: read-only health check of what this ERP is missing (apps,
///    approval workflows, employee links, defaults) with a fix hint for each.
///
/// Visible only to System Manager (nav gated by the `admin` capability).
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Administrator'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Screens'),
              Tab(text: 'Doctypes'),
              Tab(text: 'Reports'),
              Tab(text: 'Integrations'),
              Tab(text: 'Setup check'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminScreensTab(),
            _DoctypePermTab(),
            _ReportPermTab(),
            AdminIntegrationsTab(),
            _SetupCheckTab(),
          ],
        ),
      ),
    );
  }
}

/// Tab 1: pick a Module -> DocType -> Role, then toggle actions.
class _DoctypePermTab extends ConsumerStatefulWidget {
  const _DoctypePermTab();

  @override
  ConsumerState<_DoctypePermTab> createState() => _DoctypePermTabState();
}

class _DoctypePermTabState extends ConsumerState<_DoctypePermTab> {
  String? _module;
  AdminScreenRef? _screen;
  String? _role;

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(adminMetaProvider);

    return metaAsync.when(
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
      data: (meta) {
        final modules = meta.modules
            .where((m) => m.screens.isNotEmpty)
            .toList();
        final screensInModule = <AdminScreenRef>[
          for (final m in modules)
            if (m.module == _module) ...m.screens,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.category_outlined),
                      const SizedBox(width: AppDimens.sm),
                      const SizedBox(width: 74, child: Text('Module:')),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _module,
                          hint: const Text('Select a module'),
                          items: modules
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m.module,
                                  child: Text(m.module),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _module = v;
                            _screen = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.xs),
                  Row(
                    children: [
                      const Icon(Icons.description_outlined),
                      const SizedBox(width: AppDimens.sm),
                      const SizedBox(width: 74, child: Text('Document\nType:')),
                      Expanded(
                        child: DropdownButton<AdminScreenRef>(
                          isExpanded: true,
                          value: _screen,
                          hint: Text(
                            _module == null
                                ? 'Select a module first'
                                : 'Select a document type',
                          ),
                          items: [
                            for (final s in screensInModule)
                              DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _module == null
                              ? null
                              : (v) => setState(() => _screen = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.xs),
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined),
                      const SizedBox(width: AppDimens.sm),
                      const SizedBox(width: 74, child: Text('Role:')),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _role,
                          hint: const Text('Select a role'),
                          items: meta.roles
                              .map(
                                (r) =>
                                    DropdownMenuItem(value: r, child: Text(r)),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _role = v);
                            ref.read(roleMatrixProvider.notifier).load(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: (_screen == null || _role == null)
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimens.lg),
                        child: Text(
                          'Pick a module, a document type and a role to set '
                          'its permissions',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _PermEditor(screen: _screen!),
            ),
          ],
        );
      },
    );
  }
}

/// The action toggles for the currently-selected Doctype, read from the loaded
/// role matrix.
class _PermEditor extends ConsumerWidget {
  const _PermEditor({required this.screen});
  final AdminScreenRef screen;

  List<(String, String)> _typesFor(AdminScreenRef s) => [
    ('read', 'View'),
    ('create', 'Create'),
    ('write', 'Edit'),
    if (s.submittable) ('submit', 'Submit'),
    ('delete', 'Delete'),
    ('if_owner', 'Own only'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(roleMatrixProvider);
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
      data: (matrix) {
        final flags = matrix[screen.doctype] ?? const PermFlags();
        return ListView(
          padding: const EdgeInsets.all(AppDimens.md),
          children: [
            Text(
              screen.label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              screen.doctype,
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppDimens.md),
            const Text(
              'Allowed actions:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppDimens.sm),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final t in _typesFor(screen))
                  FilterChip(
                    label: Text(t.$2),
                    selected: flags.byType(t.$1),
                    onSelected: (v) async {
                      try {
                        await ref
                            .read(roleMatrixProvider.notifier)
                            .toggle(screen.doctype, t.$1, v);
                      } catch (e) {
                        if (context.mounted) {
                          showFriendlyError(context, e);
                        }
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            Text(
              '"Own only" means the role can act only on records it created. '
              'Changes here are saved to Frappe instantly and match the desk '
              'Role Permission Manager.',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

/// Tab 2: pick a Module -> Report, then toggle which roles may run it.
class _ReportPermTab extends ConsumerStatefulWidget {
  const _ReportPermTab();

  @override
  ConsumerState<_ReportPermTab> createState() => _ReportPermTabState();
}

class _ReportPermTabState extends ConsumerState<_ReportPermTab> {
  String? _module;
  ReportAdminRef? _report;

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(reportAdminMetaProvider);

    return metaAsync.when(
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
      data: (meta) {
        final modules = meta.modules
            .where((m) => m.reports.isNotEmpty)
            .toList();
        final reportsInModule = <ReportAdminRef>[
          for (final m in modules)
            if (m.module == _module) ...m.reports,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.category_outlined),
                      const SizedBox(width: AppDimens.sm),
                      const SizedBox(width: 74, child: Text('Module:')),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _module,
                          hint: const Text('Select a module'),
                          items: modules
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m.module,
                                  child: Text(m.module),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _module = v;
                            _report = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.xs),
                  Row(
                    children: [
                      const Icon(Icons.assessment_outlined),
                      const SizedBox(width: AppDimens.sm),
                      const SizedBox(width: 74, child: Text('Report:')),
                      Expanded(
                        child: DropdownButton<ReportAdminRef>(
                          isExpanded: true,
                          value: _report,
                          hint: Text(
                            _module == null
                                ? 'Select a module first'
                                : 'Select a report',
                          ),
                          items: [
                            for (final r in reportsInModule)
                              DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _module == null
                              ? null
                              : (v) {
                                  setState(() => _report = v);
                                  if (v != null) {
                                    ref
                                        .read(reportRolesProvider.notifier)
                                        .load(v.key);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _report == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimens.lg),
                        child: Text(
                          'Pick a module and a report to choose which roles '
                          'can see it',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _ReportRoleEditor(report: _report!, allRoles: meta.roles),
            ),
          ],
        );
      },
    );
  }
}

/// The per-role access toggles for the currently-selected report.
class _ReportRoleEditor extends ConsumerWidget {
  const _ReportRoleEditor({required this.report, required this.allRoles});
  final ReportAdminRef report;
  final List<String> allRoles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reportRolesProvider);
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
      data: (rolesState) {
        if (rolesState == null || rolesState.reportKey != report.key) {
          return const Center(child: CircularProgressIndicator());
        }
        final roles = rolesState.roles;
        return ListView(
          padding: const EdgeInsets.all(AppDimens.md),
          children: [
            Text(
              report.label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              report.report,
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppDimens.md),
            const Text(
              'Roles that can see this report:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppDimens.sm),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final role in allRoles)
                  FilterChip(
                    label: Text(role),
                    selected: roles[role] ?? false,
                    onSelected: (v) async {
                      try {
                        await ref
                            .read(reportRolesProvider.notifier)
                            .toggle(role, v);
                      } catch (e) {
                        if (context.mounted) {
                          showFriendlyError(context, e);
                        }
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            Text(
              rolesState.hasExplicitRoles
                  ? 'Only the selected roles (and Administrator / System '
                        'Manager) can see this report. Changes save to Frappe '
                        'instantly.'
                  : 'No role selected yet: the report currently follows the '
                        'read permission of ${report.refDoctype ?? 'its document'}. '
                        'Pick one or more roles to restrict it.',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

/// Tab 3: read-only health check. Tells the admin what this ERP is missing so
/// a fresh install fails with a to-do list instead of confusing errors.
class _SetupCheckTab extends ConsumerWidget {
  const _SetupCheckTab();

  static const _green = Color(0xFF15803D);
  static const _amber = Color(0xFFB54708);
  static const _red = Color(0xFFB42318);
  static const _grey = Color(0xFF6B7280);

  (IconData, Color) _look(SetupStatus s) => switch (s) {
    SetupStatus.ok => (Icons.check_circle, _green),
    SetupStatus.warn => (Icons.warning_amber_rounded, _amber),
    SetupStatus.error => (Icons.error, _red),
    SetupStatus.info => (Icons.info_outline, _grey),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(setupCheckProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(setupCheckProvider);
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
        data: (r) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimens.md),
          children: [
            _summary(context, r),
            const SizedBox(height: AppDimens.md),
            for (final g in r.groups) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: AppDimens.sm,
                  bottom: AppDimens.xs,
                ),
                child: Text(
                  g.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < g.checks.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _row(context, g.checks[i]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, SetupCheck r) {
    final allGood = r.error == 0 && r.warn == 0;
    final (icon, color) = r.error > 0
        ? (Icons.error, _red)
        : r.warn > 0
        ? (Icons.warning_amber_rounded, _amber)
        : (Icons.check_circle, _green);
    final text = allGood
        ? 'Everything the portal needs is set up.'
        : [
            if (r.error > 0) '${r.error} to fix',
            if (r.warn > 0) '${r.warn} to review',
          ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
          Text(
            '${r.ok} OK',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, SetupCheckItem c) {
    final (icon, color) = _look(c.status);
    return Padding(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (c.detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      c.detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (c.fix.isNotEmpty &&
                    (c.status == SetupStatus.error ||
                        c.status == SetupStatus.warn ||
                        c.status == SetupStatus.info))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'How to fix: ${c.fix}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
