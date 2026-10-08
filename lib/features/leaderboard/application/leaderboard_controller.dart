import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/leaderboard_repository.dart';
import '../domain/models.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
    (ref) => LeaderboardRepository(ref.watch(dioProvider)));

/// Date-range presets the user can pick. The actual from/to dates are
/// computed lazily from "now" so the leaderboard always reflects the
/// user's intent ("this month" means the calendar month containing today).
enum LeaderboardPeriod { thisMonth, lastMonth, thisWeek, last7Days, custom }

extension LeaderboardPeriodX on LeaderboardPeriod {
  String get label => switch (this) {
        LeaderboardPeriod.thisMonth => 'This month',
        LeaderboardPeriod.lastMonth => 'Last month',
        LeaderboardPeriod.thisWeek => 'This week',
        LeaderboardPeriod.last7Days => 'Last 7 days',
        LeaderboardPeriod.custom => 'Custom',
      };

  /// Compute the (from, to) for this preset relative to `now`. Returns
  /// nulls for `custom` — caller must supply explicit dates.
  ({DateTime? from, DateTime? to}) range({DateTime? now}) {
    final today = now ?? DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    switch (this) {
      case LeaderboardPeriod.thisMonth:
        return (from: DateTime(day.year, day.month, 1), to: day);
      case LeaderboardPeriod.lastMonth:
        final firstOfThis = DateTime(day.year, day.month, 1);
        final lastOfLast = firstOfThis.subtract(const Duration(days: 1));
        final firstOfLast = DateTime(lastOfLast.year, lastOfLast.month, 1);
        return (from: firstOfLast, to: lastOfLast);
      case LeaderboardPeriod.thisWeek:
        // ISO: Monday is weekday 1. Walk back to Monday.
        final monday = day.subtract(Duration(days: day.weekday - 1));
        return (from: monday, to: day);
      case LeaderboardPeriod.last7Days:
        return (from: day.subtract(const Duration(days: 7)), to: day);
      case LeaderboardPeriod.custom:
        return (from: null, to: null);
    }
  }
}

/// Current selection (metric + period preset + explicit dates for custom).
class LeaderboardQuery {
  const LeaderboardQuery({
    this.metric = LeaderboardMetric.dealsWon,
    this.period = LeaderboardPeriod.thisMonth,
    this.customFrom,
    this.customTo,
  });
  final LeaderboardMetric metric;
  final LeaderboardPeriod period;
  final DateTime? customFrom;
  final DateTime? customTo;

  /// Effective (from, to) for this query — handles preset OR custom.
  ({DateTime? from, DateTime? to}) effectiveRange() {
    if (period == LeaderboardPeriod.custom) {
      return (from: customFrom, to: customTo);
    }
    return period.range();
  }

  LeaderboardQuery copyWith({
    LeaderboardMetric? metric,
    LeaderboardPeriod? period,
    DateTime? customFrom,
    DateTime? customTo,
    bool clearCustom = false,
  }) =>
      LeaderboardQuery(
        metric: metric ?? this.metric,
        period: period ?? this.period,
        customFrom: clearCustom ? null : (customFrom ?? this.customFrom),
        customTo: clearCustom ? null : (customTo ?? this.customTo),
      );
}

final leaderboardQueryProvider =
    NotifierProvider<LeaderboardQueryController, LeaderboardQuery>(
        LeaderboardQueryController.new);

class LeaderboardQueryController extends Notifier<LeaderboardQuery> {
  @override
  LeaderboardQuery build() => const LeaderboardQuery();
  void setMetric(LeaderboardMetric m) => state = state.copyWith(metric: m);
  void setPreset(LeaderboardPeriod p) =>
      state = state.copyWith(period: p, clearCustom: p != LeaderboardPeriod.custom);
  void setCustomRange(DateTime from, DateTime to) =>
      state = state.copyWith(
        period: LeaderboardPeriod.custom,
        customFrom: from,
        customTo: to,
      );
}

final leaderboardProvider =
    FutureProvider.autoDispose<LeaderboardSnapshot>((ref) {
  final q = ref.watch(leaderboardQueryProvider);
  final range = q.effectiveRange();
  return ref.read(leaderboardRepositoryProvider).fetch(
        metric: q.metric,
        from: range.from,
        to: range.to,
      );
});
