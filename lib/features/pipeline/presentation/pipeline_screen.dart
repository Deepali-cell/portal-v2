import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/presentation/app_shell.dart';
import '../../leaderboard/application/leaderboard_controller.dart'
    show LeaderboardPeriod, LeaderboardPeriodX;
import '../application/pipeline_controller.dart';
import '../domain/models.dart';

class PipelineScreen extends ConsumerWidget {
  const PipelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(pipelineQueryProvider);
    final snap = ref.watch(pipelineSnapshotProvider);
    final profile = ref.watch(authControllerProvider).profile;
    // Top-level visibility — Pipeline tab is reachable only via Home card
    // which itself is gated; we re-check here as a defence-in-depth.
    final canSeeLeads = profile?.can('crm_lead') ?? false;
    final canSeeDeals = profile?.can('crm_deal') ?? false;
    final isManager = profile?.can('manager_view') ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Pipeline'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(pipelineSnapshotProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(pipelineSnapshotProvider);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppDimens.screenPadding, AppDimens.md, AppDimens.screenPadding, AppDimens.xl),
        children: [
          if (canSeeLeads && canSeeDeals)
            _KindToggle(active: query.kind),
          const SizedBox(height: AppDimens.md),
          // Scope toggle is ONLY rendered when the user has manager_view —
          // no visual hint of "team" data exists for Sales Users.
          if (isManager) ...[
            _ScopeToggle(active: query.scope),
            const SizedBox(height: AppDimens.md),
          ],
          _PeriodChips(active: query.period),
          const SizedBox(height: AppDimens.lg),
          snap.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator())),
            error: (e, _) => _Err(
              msg: e is ApiException
                  ? e.message
                  : "Couldn't load the pipeline. Try again.",
              onRetry: () => ref.invalidate(pipelineSnapshotProvider),
            ),
            data: (s) => _Funnel(snapshot: s, kind: query.kind),
          ),
        ],
        ),
      ),
      bottomNavigationBar: const PersistentBottomNav(),
    );
  }
}

class _KindToggle extends ConsumerWidget {
  const _KindToggle({required this.active});
  final PipelineKind active;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<PipelineKind>(
      segments: const [
        ButtonSegment(value: PipelineKind.leads, label: Text('Leads')),
        ButtonSegment(value: PipelineKind.deals, label: Text('Deals')),
      ],
      selected: {active},
      onSelectionChanged: (s) =>
          ref.read(pipelineQueryProvider.notifier).setKind(s.first),
    );
  }
}

class _ScopeToggle extends ConsumerWidget {
  const _ScopeToggle({required this.active});
  final PipelineScope active;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<PipelineScope>(
      segments: const [
        ButtonSegment(value: PipelineScope.mine, label: Text('My')),
        ButtonSegment(value: PipelineScope.team, label: Text('Team')),
      ],
      selected: {active},
      onSelectionChanged: (s) =>
          ref.read(pipelineQueryProvider.notifier).setScope(s.first),
    );
  }
}

class _PeriodChips extends ConsumerWidget {
  const _PeriodChips({required this.active});
  final LeaderboardPeriod active;

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
    );
    if (picked == null) return;
    ref
        .read(pipelineQueryProvider.notifier)
        .setCustomRange(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in LeaderboardPeriod.values) ...[
            _Chip(
              label: p.label,
              active: p == active,
              onTap: () {
                if (p == LeaderboardPeriod.custom) {
                  _pickCustomRange(context, ref);
                } else {
                  ref.read(pipelineQueryProvider.notifier).setPreset(p);
                }
              },
            ),
            const SizedBox(width: AppDimens.xs),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Funnel extends StatelessWidget {
  const _Funnel({required this.snapshot, required this.kind});
  final PipelineSnapshot snapshot;
  final PipelineKind kind;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM');
    final visibleStages = snapshot.stages.where((s) => s.count > 0).toList();
    final maxCount = visibleStages.isEmpty
        ? 1
        : visibleStages
            .map((s) => s.count)
            .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        snapshot.scope == 'team'
                            ? 'Team ${kind.label}'
                            : 'My ${kind.label}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text('${snapshot.totalCount}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                if (snapshot.fromDate != null && snapshot.toDate != null)
                  Text(
                    '${dateFmt.format(snapshot.fromDate!)} – ${dateFmt.format(snapshot.toDate!)}'
                    '${snapshot.totalValue > 0 ? "  ·  ${moneyShort(snapshot.totalValue)}" : ""}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.md),
        if (visibleStages.isEmpty)
          _EmptyState()
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.sm),
              child: Column(
                children: [
                  for (final s in visibleStages)
                    _StageBar(stage: s, maxCount: maxCount),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({required this.stage, required this.maxCount});
  final PipelineStage stage;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final pct = (stage.count / maxCount).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.sm, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stage.status,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (stage.staleCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 11, color: AppColors.onErrorContainer),
                      const SizedBox(width: 3),
                      Text('${stage.staleCount} stale',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onErrorContainer)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text('${stage.count}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700)),
              if (stage.value > 0) ...[
                const SizedBox(width: 6),
                Text('· ${moneyShort(stage.value)}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: AppColors.surfaceContainer,
              valueColor: AlwaysStoppedAnimation<Color>(stage.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined,
                size: 36, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 10),
            Text('No data for this period',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('Try a wider date range or a different scope.',
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
