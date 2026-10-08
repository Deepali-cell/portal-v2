import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(dioProvider)),
);

/// Site set-up health check. autoDispose so reopening the tab re-runs it and
/// shows the result of whatever the admin just fixed.
final setupCheckProvider = FutureProvider.autoDispose<SetupCheck>(
  (ref) => ref.read(adminRepositoryProvider).getSetupCheck(),
);

final screenConfigProvider = FutureProvider.autoDispose<ScreenConfig>(
  (ref) => ref.read(adminRepositoryProvider).getScreenConfig(),
);

final integrationsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.read(adminRepositoryProvider).getIntegrations(),
);

final adminMetaProvider = FutureProvider<AdminMeta>(
  (ref) => ref.read(adminRepositoryProvider).getMeta(),
);

/// Holds the permission matrix for the currently-loaded role. `load(role)`
/// switches role; `toggle` optimistically updates and persists to Frappe.
class RoleMatrixController extends AsyncNotifier<Map<String, PermFlags>> {
  String? _role;
  String? get role => _role;

  @override
  Future<Map<String, PermFlags>> build() async => const {};

  Future<void> load(String role) async {
    _role = role;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(adminRepositoryProvider).getMatrix(role),
    );
  }

  Future<void> toggle(String doctype, String ptype, bool value) async {
    final role = _role;
    final current = state.asData?.value;
    if (role == null || current == null) return;

    final optimistic = Map<String, PermFlags>.from(current);
    optimistic[doctype] = _apply(
      optimistic[doctype] ?? const PermFlags(),
      ptype,
      value,
    );
    state = AsyncData(optimistic);

    try {
      final fresh = await ref
          .read(adminRepositoryProvider)
          .setPerm(role: role, doctype: doctype, ptype: ptype, value: value);
      final updated = Map<String, PermFlags>.from(
        state.asData?.value ?? optimistic,
      );
      updated[doctype] = fresh;
      state = AsyncData(updated);
    } catch (_) {
      state = AsyncData(current); // revert
      rethrow;
    }
  }

  PermFlags _apply(PermFlags f, String ptype, bool v) => PermFlags(
    read: ptype == 'read' ? v : f.read,
    create: ptype == 'create' ? v : f.create,
    write: ptype == 'write' ? v : f.write,
    submit: ptype == 'submit' ? v : f.submit,
    delete: ptype == 'delete' ? v : f.delete,
    ifOwner: ptype == 'if_owner' ? v : f.ifOwner,
  );
}

final roleMatrixProvider =
    AsyncNotifierProvider<RoleMatrixController, Map<String, PermFlags>>(
      RoleMatrixController.new,
    );

// --- Reports: per-role access management ----------------------------------

final reportAdminMetaProvider = FutureProvider<ReportAdminMeta>(
  (ref) => ref.read(adminRepositoryProvider).getReportMeta(),
);

/// Holds the role-access state for one selected report. `load(reportKey)`
/// switches report; `toggle(role, value)` optimistically updates and persists.
class ReportRolesController extends AsyncNotifier<ReportRolesState?> {
  String? _reportKey;
  String? get reportKey => _reportKey;

  @override
  Future<ReportRolesState?> build() async => null;

  Future<void> load(String reportKey) async {
    _reportKey = reportKey;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(adminRepositoryProvider).getReportRoles(reportKey),
    );
  }

  Future<void> toggle(String role, bool value) async {
    final key = _reportKey;
    final current = state.asData?.value;
    if (key == null || current == null) return;

    final optimisticRoles = Map<String, bool>.from(current.roles)
      ..[role] = value;
    state = AsyncData(
      current.copyWith(
        roles: optimisticRoles,
        hasExplicitRoles: optimisticRoles.values.any((v) => v),
      ),
    );

    try {
      final fresh = await ref
          .read(adminRepositoryProvider)
          .setReportRole(reportKey: key, role: role, value: value);
      state = AsyncData(fresh);
    } catch (_) {
      state = AsyncData(current); // revert
      rethrow;
    }
  }
}

final reportRolesProvider =
    AsyncNotifierProvider<ReportRolesController, ReportRolesState?>(
      ReportRolesController.new,
    );
