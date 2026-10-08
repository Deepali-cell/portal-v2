import 'package:flutter/foundation.dart';

@immutable
class AdminScreenRef {
  const AdminScreenRef({
    required this.key,
    required this.doctype,
    required this.label,
    this.submittable = false,
  });
  final String key;
  final String doctype;
  final String label;

  /// True only when this DocType is submittable in ERPNext, so the panel
  /// shows the Submit action only where it actually applies.
  final bool submittable;

  factory AdminScreenRef.fromJson(Map<String, dynamic> j) => AdminScreenRef(
    key: j['key'] as String,
    doctype: j['doctype'] as String,
    label: j['label'] as String,
    submittable: (j['submittable'] ?? 0) == 1,
  );
}

@immutable
class AdminModule {
  const AdminModule({required this.module, required this.screens});
  final String module;
  final List<AdminScreenRef> screens;

  factory AdminModule.fromJson(Map<String, dynamic> j) => AdminModule(
    module: j['module'] as String,
    screens: ((j['screens'] as List?) ?? const [])
        .map((e) => AdminScreenRef.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

@immutable
class AdminMeta {
  const AdminMeta({required this.roles, required this.modules});
  final List<String> roles;
  final List<AdminModule> modules;

  factory AdminMeta.fromJson(Map<String, dynamic> j) => AdminMeta(
    roles: ((j['roles'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    modules: ((j['modules'] as List?) ?? const [])
        .map((e) => AdminModule.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// One curated report exposed in the Administrator panel's Reports tab.
@immutable
class ReportAdminRef {
  const ReportAdminRef({
    required this.key,
    required this.label,
    required this.report,
    this.refDoctype,
  });
  final String key;
  final String label;
  final String report;
  final String? refDoctype;

  factory ReportAdminRef.fromJson(Map<String, dynamic> j) => ReportAdminRef(
    key: j['key'] as String,
    label: (j['label'] ?? j['key']) as String,
    report: (j['report'] ?? '') as String,
    refDoctype: j['ref_doctype'] as String?,
  );
}

@immutable
class ReportAdminModule {
  const ReportAdminModule({required this.module, required this.reports});
  final String module;
  final List<ReportAdminRef> reports;

  factory ReportAdminModule.fromJson(Map<String, dynamic> j) =>
      ReportAdminModule(
        module: j['module'] as String,
        reports: ((j['reports'] as List?) ?? const [])
            .map(
              (e) =>
                  ReportAdminRef.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList(),
      );
}

@immutable
class ReportAdminMeta {
  const ReportAdminMeta({required this.roles, required this.modules});
  final List<String> roles;
  final List<ReportAdminModule> modules;

  factory ReportAdminMeta.fromJson(Map<String, dynamic> j) => ReportAdminMeta(
    roles: ((j['roles'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    modules: ((j['modules'] as List?) ?? const [])
        .map(
          (e) => ReportAdminModule.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
  );
}

/// Which roles currently have access to one report. When [hasExplicitRoles] is
/// false the report follows its ref_doctype read permission (unrestricted by
/// role), matching Frappe's own Report behaviour.
@immutable
class ReportRolesState {
  const ReportRolesState({
    required this.reportKey,
    required this.report,
    required this.hasExplicitRoles,
    required this.roles,
    this.refDoctype,
  });
  final String reportKey;
  final String report;
  final String? refDoctype;
  final bool hasExplicitRoles;

  /// role -> granted.
  final Map<String, bool> roles;

  ReportRolesState copyWith({
    Map<String, bool>? roles,
    bool? hasExplicitRoles,
  }) => ReportRolesState(
    reportKey: reportKey,
    report: report,
    refDoctype: refDoctype,
    hasExplicitRoles: hasExplicitRoles ?? this.hasExplicitRoles,
    roles: roles ?? this.roles,
  );

  factory ReportRolesState.fromJson(Map<String, dynamic> j) {
    final raw = ((j['roles'] as Map?) ?? const {}).cast<String, dynamic>();
    return ReportRolesState(
      reportKey: j['report_key'] as String,
      report: (j['report'] ?? '') as String,
      refDoctype: j['ref_doctype'] as String?,
      hasExplicitRoles:
          (j['has_explicit_roles'] ?? false) == true ||
          (j['has_explicit_roles'] ?? 0) == 1,
      roles: raw.map((k, v) => MapEntry(k, v == 1 || v == true)),
    );
  }
}

/// One doctype's permission flags for a role at permlevel 0.
@immutable
class PermFlags {
  const PermFlags({
    this.read = false,
    this.create = false,
    this.write = false,
    this.submit = false,
    this.delete = false,
    this.ifOwner = false,
  });

  final bool read;
  final bool create;
  final bool write;
  final bool submit;
  final bool delete;
  final bool ifOwner;

  bool byType(String t) => switch (t) {
    'read' => read,
    'create' => create,
    'write' => write,
    'submit' => submit,
    'delete' => delete,
    'if_owner' => ifOwner,
    _ => false,
  };

  factory PermFlags.fromJson(Map<String, dynamic> j) => PermFlags(
    read: (j['read'] ?? 0) == 1,
    create: (j['create'] ?? 0) == 1,
    write: (j['write'] ?? 0) == 1,
    submit: (j['submit'] ?? 0) == 1,
    delete: (j['delete'] ?? 0) == 1,
    ifOwner: (j['if_owner'] ?? 0) == 1,
  );
}

/// Outcome of one set-up check. `error` = a portal feature will not work until
/// fixed, `warn` = works but incomplete, `info` = optional, `ok` = all good.
enum SetupStatus { ok, warn, error, info }

SetupStatus _setupStatusFrom(String? s) => switch (s) {
  'ok' => SetupStatus.ok,
  'warn' => SetupStatus.warn,
  'error' => SetupStatus.error,
  _ => SetupStatus.info,
};

@immutable
class SetupCheckItem {
  const SetupCheckItem({
    required this.key,
    required this.label,
    required this.status,
    this.detail = '',
    this.fix = '',
  });
  final String key;
  final String label;
  final SetupStatus status;
  final String detail;
  final String fix;

  factory SetupCheckItem.fromJson(Map<String, dynamic> j) => SetupCheckItem(
    key: (j['key'] ?? '') as String,
    label: (j['label'] ?? '') as String,
    status: _setupStatusFrom(j['status'] as String?),
    detail: (j['detail'] ?? '') as String,
    fix: (j['fix'] ?? '') as String,
  );
}

@immutable
class SetupCheckGroup {
  const SetupCheckGroup({required this.title, required this.checks});
  final String title;
  final List<SetupCheckItem> checks;

  factory SetupCheckGroup.fromJson(Map<String, dynamic> j) => SetupCheckGroup(
    title: (j['title'] ?? '') as String,
    checks: ((j['checks'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => SetupCheckItem.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );
}

@immutable
class SetupCheck {
  const SetupCheck({
    required this.ok,
    required this.warn,
    required this.error,
    required this.info,
    required this.groups,
  });
  final int ok;
  final int warn;
  final int error;
  final int info;
  final List<SetupCheckGroup> groups;

  factory SetupCheck.fromJson(Map<String, dynamic> j) {
    final s = ((j['summary'] as Map?) ?? const {}).cast<String, dynamic>();
    int n(String k) => (s[k] as num?)?.toInt() ?? 0;
    return SetupCheck(
      ok: n('ok'),
      warn: n('warn'),
      error: n('error'),
      info: n('info'),
      groups: ((j['groups'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => SetupCheckGroup.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// One licence module as the admin's Screens page sees it.
@immutable
class LicensedModule {
  const LicensedModule({
    required this.key,
    required this.label,
    required this.enabled,
  });
  final String key; // 'hr', 'crm', ...
  final String label;

  /// Part of the company's licence (set by TCB, not editable here).
  final bool enabled;

  factory LicensedModule.fromJson(Map<String, dynamic> j) => LicensedModule(
    key: (j['key'] ?? '').toString(),
    label: (j['label'] ?? j['key'] ?? '').toString(),
    enabled: j['enabled'] == true,
  );
}

/// Licence modules plus the screens this site's admin switched off.
@immutable
class ScreenConfig {
  const ScreenConfig({required this.modules, required this.disabledScreens});
  final List<LicensedModule> modules;
  final Set<String> disabledScreens;

  factory ScreenConfig.fromJson(Map<String, dynamic> j) => ScreenConfig(
    modules: ((j['modules'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => LicensedModule.fromJson(e.cast<String, dynamic>()))
        .toList(),
    disabledScreens: ((j['disabled_screens'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet(),
  );
}

/// Outcome of saving / testing an integration's credentials.
@immutable
class IntegrationResult {
  const IntegrationResult({required this.ok, required this.message});
  final bool ok;
  final String message;
}
