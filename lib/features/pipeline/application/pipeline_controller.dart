import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../leaderboard/application/leaderboard_controller.dart'
    show LeaderboardPeriod, LeaderboardPeriodX;
import '../data/pipeline_repository.dart';
import '../domain/models.dart';

final pipelineRepositoryProvider = Provider<PipelineRepository>(
    (ref) => PipelineRepository(ref.watch(dioProvider)));

/// Query state for the Pipeline screen. Reuses [LeaderboardPeriod] so the
/// same chip widget renders on both screens with consistent semantics.
@immutable
class PipelineQuery {
  const PipelineQuery({
    this.kind = PipelineKind.leads,
    this.scope = PipelineScope.mine,
    this.period = LeaderboardPeriod.thisMonth,
    this.customFrom,
    this.customTo,
  });

  final PipelineKind kind;
  final PipelineScope scope;
  final LeaderboardPeriod period;
  final DateTime? customFrom;
  final DateTime? customTo;

  ({DateTime? from, DateTime? to}) effectiveRange() {
    if (period == LeaderboardPeriod.custom) {
      return (from: customFrom, to: customTo);
    }
    return period.range();
  }

  PipelineQuery copyWith({
    PipelineKind? kind,
    PipelineScope? scope,
    LeaderboardPeriod? period,
    DateTime? customFrom,
    DateTime? customTo,
    bool clearCustom = false,
  }) =>
      PipelineQuery(
        kind: kind ?? this.kind,
        scope: scope ?? this.scope,
        period: period ?? this.period,
        customFrom: clearCustom ? null : (customFrom ?? this.customFrom),
        customTo: clearCustom ? null : (customTo ?? this.customTo),
      );
}

final pipelineQueryProvider =
    NotifierProvider<PipelineQueryController, PipelineQuery>(
        PipelineQueryController.new);

class PipelineQueryController extends Notifier<PipelineQuery> {
  @override
  PipelineQuery build() => const PipelineQuery();

  void setKind(PipelineKind k) => state = state.copyWith(kind: k);
  void setScope(PipelineScope s) => state = state.copyWith(scope: s);
  void setPreset(LeaderboardPeriod p) => state = state.copyWith(
      period: p, clearCustom: p != LeaderboardPeriod.custom);
  void setCustomRange(DateTime from, DateTime to) =>
      state = state.copyWith(
        period: LeaderboardPeriod.custom,
        customFrom: from,
        customTo: to,
      );
}

final pipelineSnapshotProvider =
    FutureProvider.autoDispose<PipelineSnapshot>((ref) {
  final q = ref.watch(pipelineQueryProvider);
  final range = q.effectiveRange();
  return ref.read(pipelineRepositoryProvider).fetch(
        kind: q.kind,
        scope: q.scope,
        from: range.from,
        to: range.to,
      );
});
