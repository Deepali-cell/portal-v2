import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../domain/models.dart';

class RoleDashboardsRepository {
  RoleDashboardsRepository(this._dio);
  final Dio _dio;

  Future<HrSummary> hr({required RolePeriod period}) async {
    final data = await _get(ApiPaths.hrDashboard, {'period': period.apiName});
    return HrSummary.fromJson(data);
  }

  Future<ProjectsSummary> projects({
    required RolePeriod period,
    String scope = 'mine',
  }) async {
    final data = await _get(
      ApiPaths.projectsDashboard,
      {'period': period.apiName, 'scope': scope},
    );
    return ProjectsSummary.fromJson(data);
  }

  Future<AccountsSummary> accounts({required RolePeriod period}) async {
    final data = await _get(
      ApiPaths.accountsDashboard,
      {'period': period.apiName},
    );
    return AccountsSummary.fromJson(data);
  }

  Future<Map<String, dynamic>> _get(
      String path, Map<String, dynamic> query) async {
    try {
      final resp = await _dio.get(path, queryParameters: query);
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
}

final roleDashboardsRepositoryProvider = Provider<RoleDashboardsRepository>(
  (ref) => RoleDashboardsRepository(ref.watch(dioProvider)),
);

// Per-role period controllers (independent — user can pick "week" on HR and
// "month" on Accounts at the same time).

class HrPeriodController extends Notifier<RolePeriod> {
  // HR dashboard shows today's snapshot only (the period chips were removed),
  // so pending-leave counts reflect today rather than the whole week.
  @override
  RolePeriod build() => RolePeriod.today;
  void set(RolePeriod p) => state = p;
}

final hrPeriodProvider =
    NotifierProvider<HrPeriodController, RolePeriod>(HrPeriodController.new);

class ProjectsPeriodController extends Notifier<RolePeriod> {
  @override
  RolePeriod build() => RolePeriod.week;
  void set(RolePeriod p) => state = p;
}

final projectsPeriodProvider =
    NotifierProvider<ProjectsPeriodController, RolePeriod>(
        ProjectsPeriodController.new);

class AccountsPeriodController extends Notifier<RolePeriod> {
  @override
  RolePeriod build() => RolePeriod.month;
  void set(RolePeriod p) => state = p;
}

final accountsPeriodProvider =
    NotifierProvider<AccountsPeriodController, RolePeriod>(
        AccountsPeriodController.new);

// AsyncData providers — one per role, autoDispose so leaving Home releases them.

final hrSummaryProvider = FutureProvider.autoDispose<HrSummary>((ref) {
  final period = ref.watch(hrPeriodProvider);
  return ref.read(roleDashboardsRepositoryProvider).hr(period: period);
});

final projectsSummaryProvider =
    FutureProvider.autoDispose<ProjectsSummary>((ref) {
  final period = ref.watch(projectsPeriodProvider);
  return ref.read(roleDashboardsRepositoryProvider).projects(period: period);
});

final accountsSummaryProvider =
    FutureProvider.autoDispose<AccountsSummary>((ref) {
  final period = ref.watch(accountsPeriodProvider);
  return ref.read(roleDashboardsRepositoryProvider).accounts(period: period);
});
