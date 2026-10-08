import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/presentation/app_shell.dart';
import '../application/performance_controller.dart';
import '../domain/models.dart';

/// The Performance screen (replaces the old funnel). Shows "who did what in
/// which month / year": the signed-in user's own scorecard, plus — for
/// managers — team totals and a ranked per-person breakdown.
class PerformanceScreen extends ConsumerWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(performanceQueryProvider);
    final snap = ref.watch(performanceSnapshotProvider);
    final profile = ref.watch(authControllerProvider).profile;
    final isManager = profile?.can('manager_view') ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Performance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(performanceSnapshotProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(performanceSnapshotProvider);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
              AppDimens.md, AppDimens.screenPadding, AppDimens.xl),
          children: [
            _PeriodBar(query: q),
            const SizedBox(height: AppDimens.md),
            if (isManager) ...[
              _ScopeToggle(active: q.scope),
              const SizedBox(height: AppDimens.md),
            ],
            snap.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _Err(
                msg: e is ApiException
                    ? e.message
                    : "Couldn't load performance. Try again.",
                onRetry: () => ref.invalidate(performanceSnapshotProvider),
              ),
              data: (s) => _Body(snapshot: s, scope: q.scope),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const PersistentBottomNav(),
    );
  }
}

// ── Period navigator ────────────────────────────────────────────────────────
class _PeriodBar extends ConsumerWidget {
  const _PeriodBar({required this.query});
  final PerformanceQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(performanceQueryProvider.notifier);
    final r = query.range();
    final label = query.grain == PerfGrain.year
        ? '${query.year}'
        : DateFormat('MMMM yyyy').format(r.from);
    final atLatest = ctrl.atLatest;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.sm, vertical: AppDimens.xs),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: AppColors.primary,
                  onPressed: () => ctrl.step(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: atLatest ? AppColors.outlineVariant : AppColors.primary,
                  onPressed: atLatest ? null : () => ctrl.step(1),
                ),
              ],
            ),
            SegmentedButton<PerfGrain>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: PerfGrain.month, label: Text('Month')),
                ButtonSegment(value: PerfGrain.year, label: Text('Year')),
              ],
              selected: {query.grain},
              onSelectionChanged: (s) => ctrl.setGrain(s.first),
            ),
            const SizedBox(height: AppDimens.xs),
          ],
        ),
      ),
    );
  }
}

class _ScopeToggle extends ConsumerWidget {
  const _ScopeToggle({required this.active});
  final PerfScope active;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<PerfScope>(
      segments: const [
        ButtonSegment(
            value: PerfScope.mine,
            label: Text('My performance'),
            icon: Icon(Icons.person_outline)),
        ButtonSegment(
            value: PerfScope.team,
            label: Text('Team'),
            icon: Icon(Icons.groups_2_outlined)),
      ],
      selected: {active},
      onSelectionChanged: (s) =>
          ref.read(performanceQueryProvider.notifier).setScope(s.first),
    );
  }
}

// ── Body ────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  const _Body({required this.snapshot, required this.scope});
  final PerformanceSnapshot snapshot;
  final PerfScope scope;

  @override
  Widget build(BuildContext context) {
    final team = snapshot.team;
    final showTeam = scope == PerfScope.team && team != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTeam) ...[
          _Scorecard(
            title: 'Team total',
            subtitle: '${team.peopleCount} '
                '${team.peopleCount == 1 ? "person" : "people"} active',
            row: team.totals,
            highlight: true,
          ),
          const SizedBox(height: AppDimens.md),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text('By person',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w700)),
          ),
          if (team.people.isEmpty)
            _Empty()
          else
            for (var i = 0; i < team.people.length; i++)
              _PersonCard(rank: i + 1, row: team.people[i]),
        ] else ...[
          _Scorecard(
            title: 'My performance',
            subtitle: snapshot.self.fullName,
            row: snapshot.self,
            highlight: true,
          ),
          const SizedBox(height: AppDimens.md),
          if (snapshot.self.activity == 0 && snapshot.self.dealsWon == 0)
            _Empty(),
        ],
      ],
    );
  }
}

/// Big metric card used for "My performance" and "Team total".
class _Scorecard extends StatelessWidget {
  const _Scorecard({
    required this.title,
    required this.subtitle,
    required this.row,
    this.highlight = false,
  });
  final String title;
  final String subtitle;
  final PerformanceRow row;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight ? AppColors.primary : null,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: highlight ? AppColors.onPrimary : AppColors.primary,
                    fontWeight: FontWeight.w700)),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: highlight
                        ? AppColors.onPrimary.withValues(alpha: 0.85)
                        : AppColors.onSurfaceVariant)),
            const SizedBox(height: AppDimens.md),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppDimens.sm,
              mainAxisSpacing: AppDimens.sm,
              childAspectRatio: 1.15,
              children: [
                _Metric(
                    label: 'Deals won',
                    value: '${row.dealsWon}',
                    icon: Icons.emoji_events_outlined,
                    onDark: highlight),
                _Metric(
                    label: 'Revenue',
                    value: moneyShort(row.revenue),
                    icon: Icons.payments_outlined,
                    onDark: highlight),
                _Metric(
                    label: 'Opportunities',
                    value: '${row.opps}',
                    icon: Icons.handshake_outlined,
                    onDark: highlight),
                _Metric(
                    label: 'Leads',
                    value: '${row.leads}',
                    icon: Icons.person_search_outlined,
                    onDark: highlight),
                _Metric(
                    label: 'Calls',
                    value: '${row.calls}',
                    icon: Icons.call_outlined,
                    onDark: highlight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    this.onDark = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? AppColors.onPrimary : AppColors.primary;
    final bg = onDark
        ? AppColors.onPrimary.withValues(alpha: 0.12)
        : AppColors.surfaceContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  color: onDark
                      ? AppColors.onPrimary.withValues(alpha: 0.85)
                      : AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Ranked per-person row in team scope.
class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.rank, required this.row});
  final int rank;
  final PerformanceRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          children: [
            Row(
              children: [
                _RankBadge(rank: rank),
                const SizedBox(width: AppDimens.sm),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceContainer,
                  backgroundImage:
                      row.image != null ? NetworkImage(row.image!) : null,
                  child: row.image == null
                      ? Text(
                          _initials(row.fullName),
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        )
                      : null,
                ),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        row.revenue > 0
                            ? moneyShort(row.revenue)
                            : 'No revenue yet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _WonPill(count: row.dealsWon),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniStat(label: 'Leads', value: row.leads),
                _MiniStat(label: 'Opps', value: row.opps),
                _MiniStat(label: 'Calls', value: row.calls),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;
  @override
  Widget build(BuildContext context) {
    final medal = rank <= 3;
    final bg = switch (rank) {
      1 => const Color(0xFFF6C244),
      2 => const Color(0xFFC0C7D0),
      3 => const Color(0xFFCD7F45),
      _ => AppColors.surfaceContainer,
    };
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text('$rank',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: medal ? Colors.white : AppColors.onSurfaceVariant)),
    );
  }
}

class _WonPill extends StatelessWidget {
  const _WonPill({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text('$count won',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.insights_outlined,
                size: 36, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 10),
            Text('No activity in this period',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('Try another month or switch to Year.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Err extends StatelessWidget {
  const _Err({required this.msg, required this.onRetry});
  final String msg;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          children: [
            Text(msg, style: TextStyle(color: AppColors.onErrorContainer)),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
