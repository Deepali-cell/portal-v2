import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../home/presentation/app_shell.dart';
import '../application/leaderboard_controller.dart';
import '../domain/models.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider);
    final query = ref.watch(leaderboardQueryProvider);
    final dateFmt = DateFormat('d MMM');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(leaderboardProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e is ApiException
              ? e.message
              : "Couldn't load the leaderboard. Pull to refresh.",
          onRetry: () => ref.invalidate(leaderboardProvider),
        ),
        data: (snap) {
          if (!snap.isManagerView) {
            return const _NotManagerState();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(leaderboardProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding, AppDimens.md, AppDimens.screenPadding, AppDimens.xl),
              children: [
                _MetricChips(active: query.metric),
                const SizedBox(height: AppDimens.sm),
                _PeriodChips(active: query.period),
                const SizedBox(height: AppDimens.md),
                if (snap.fromDate != null && snap.toDate != null)
                  Text(
                    "${dateFmt.format(snap.fromDate!)} – ${dateFmt.format(snap.toDate!)} · ${query.metric.label}",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: AppDimens.md),
                if (snap.leaders.isEmpty)
                  _EmptyState()
                else ...[
                  for (var i = 0; i < snap.leaders.length; i++)
                    _LeaderRow(rank: i + 1, entry: snap.leaders[i]),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const PersistentBottomNav(),
    );
  }
}

class _MetricChips extends ConsumerWidget {
  const _MetricChips({required this.active});
  final LeaderboardMetric active;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final m in LeaderboardMetric.values) ...[
            _Chip(
              label: m.label,
              active: m == active,
              onTap: () =>
                  ref.read(leaderboardQueryProvider.notifier).setMetric(m),
            ),
            const SizedBox(width: AppDimens.xs),
          ],
        ],
      ),
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
        .read(leaderboardQueryProvider.notifier)
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
                  ref.read(leaderboardQueryProvider.notifier).setPreset(p);
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
            color: active ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
          ),
        ),
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.rank, required this.entry});
  final int rank;
  final LeaderboardEntry entry;

  Color _rankAccent() {
    if (rank == 1) return const Color(0xFFD4AF37); // gold
    if (rank == 2) return const Color(0xFFC0C0C0); // silver
    if (rank == 3) return const Color(0xFFCD7F32); // bronze
    return AppColors.onSurfaceVariant;
  }

  String _initials() {
    final parts =
        entry.fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md, vertical: AppDimens.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('#$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _rankAccent(),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                )),
          ),
          const SizedBox(width: AppDimens.sm),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.secondaryFixed,
            backgroundImage: (entry.image == null || entry.image!.isEmpty)
                ? null
                : NetworkImage(entry.image!),
            child: (entry.image == null || entry.image!.isEmpty)
                ? Text(_initials(),
                    style: TextStyle(
                        color: AppColors.onSecondaryFixed,
                        fontWeight: FontWeight.w700,
                        fontSize: 13))
                : null,
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.fullName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(entry.user,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text('${entry.value}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.xl),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bar_chart, color: AppColors.outline, size: 44),
            const SizedBox(height: AppDimens.md),
            Text('No activity in this period.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Pick a different metric or widen the date range.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotManagerState extends StatelessWidget {
  const _NotManagerState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline,
                color: AppColors.outline, size: 44),
            const SizedBox(height: AppDimens.md),
            Text("Manager view only",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              "The leaderboard is available to Sales Managers and admins. If you need access, contact your administrator.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: AppDimens.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
