import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/todays_plan_repository.dart';
import '../domain/models.dart';

final todaysPlanRepositoryProvider = Provider<TodaysPlanRepository>(
  (ref) => TodaysPlanRepository(ref.watch(dioProvider)),
);

/// Today's Plan loads lazily on home-screen build and refreshes on demand.
///
/// Using AsyncNotifier (not FutureProvider) so the home can pull-to-refresh
/// and the controller can re-fetch after relevant mutations elsewhere
/// (e.g. a task being marked Done should invalidate this).
final todaysPlanControllerProvider =
    AsyncNotifierProvider<TodaysPlanController, TodaysPlan>(
      TodaysPlanController.new,
    );

class TodaysPlanController extends AsyncNotifier<TodaysPlan> {
  @override
  Future<TodaysPlan> build() => ref.read(todaysPlanRepositoryProvider).fetch();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(todaysPlanRepositoryProvider).fetch(),
    );
  }
}
