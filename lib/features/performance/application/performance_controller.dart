import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/performance_repository.dart';
import '../domain/models.dart';

final performanceRepositoryProvider = Provider<PerformanceRepository>(
    (ref) => PerformanceRepository(ref.watch(dioProvider)));

/// Whose numbers to show.
enum PerfScope { mine, team }

extension PerfScopeX on PerfScope {
  String get apiValue => this == PerfScope.team ? 'team' : 'mine';
}

/// Month vs whole-year granularity.
enum PerfGrain { month, year }

/// Query state: scope + which month/year window.
@immutable
class PerformanceQuery {
  PerformanceQuery({
    this.scope = PerfScope.mine,
    this.grain = PerfGrain.month,
    int? year,
    int? month,
  })  : year = year ?? DateTime.now().year,
        month = month ?? DateTime.now().month;

  final PerfScope scope;
  final PerfGrain grain;
  final int year;
  final int month; // 1..12

  ({DateTime from, DateTime to}) range() {
    if (grain == PerfGrain.year) {
      return (from: DateTime(year, 1, 1), to: DateTime(year, 12, 31));
    }
    final from = DateTime(year, month, 1);
    // Last day of the month = day 0 of next month.
    final to = DateTime(year, month + 1, 0);
    return (from: from, to: to);
  }

  PerformanceQuery copyWith({
    PerfScope? scope,
    PerfGrain? grain,
    int? year,
    int? month,
  }) =>
      PerformanceQuery(
        scope: scope ?? this.scope,
        grain: grain ?? this.grain,
        year: year ?? this.year,
        month: month ?? this.month,
      );
}

final performanceQueryProvider =
    NotifierProvider<PerformanceQueryController, PerformanceQuery>(
        PerformanceQueryController.new);

class PerformanceQueryController extends Notifier<PerformanceQuery> {
  @override
  PerformanceQuery build() => PerformanceQuery();

  void setScope(PerfScope s) => state = state.copyWith(scope: s);
  void setGrain(PerfGrain g) => state = state.copyWith(grain: g);

  /// Step the current window backwards/forwards by one month or one year.
  void step(int delta) {
    if (state.grain == PerfGrain.year) {
      final y = state.year + delta;
      if (y > DateTime.now().year + 0) return; // no future years
      state = state.copyWith(year: y);
      return;
    }
    var y = state.year;
    var m = state.month + delta;
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    // Don't step past the current month.
    final now = DateTime.now();
    if (y > now.year || (y == now.year && m > now.month)) return;
    state = state.copyWith(year: y, month: m);
  }

  bool get atLatest {
    final now = DateTime.now();
    if (state.grain == PerfGrain.year) return state.year >= now.year;
    return state.year == now.year && state.month == now.month;
  }
}

final performanceSnapshotProvider =
    FutureProvider.autoDispose<PerformanceSnapshot>((ref) {
  final q = ref.watch(performanceQueryProvider);
  final r = q.range();
  return ref.read(performanceRepositoryProvider).fetch(
        scope: q.scope.apiValue,
        from: r.from,
        to: r.to,
      );
});
