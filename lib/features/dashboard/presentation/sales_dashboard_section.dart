import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../deals/presentation/deal_detail_screen.dart';
import '../../leads/application/leads_view_prefs.dart';
import '../../leads/presentation/lead_detail_screen.dart';
import '../data/dashboard_repository.dart';
import '../domain/models.dart';

/// Drop-in widget that renders the unified Sales Dashboard.
/// Placed on the Home screen between Welcome and the Bento grid.
///
/// 6 sections:
///   1. Scope toggle (My / Team) — managers only
///   2. Today snapshot (5 KPIs in a horizontal strip)
///   3. Follow-ups bucket (today / overdue / upcoming)
///   4. Status-wise Lead cards (one per CRM Lead Status)
///   5. Status-wise Deal cards (compact strip)
///   6. Recent AI summaries (last 5 Ready recordings)
class SalesDashboardSection extends ConsumerWidget {
  const SalesDashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesDashboardProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDimens.lg),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => _DashboardError(
        msg: e is ApiException
            ? e.message
            : "Couldn't load the sales dashboard.",
        onRetry: () => ref.invalidate(salesDashboardProvider),
      ),
      data: (d) => _DashboardBody(snapshot: d),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.snapshot});
  final SalesDashboard snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Non-CRM users see nothing here; the Home Bento grid handles them.
    if (!snapshot.canLead && !snapshot.canDeal) return const SizedBox.shrink();
    // Team dashboard hides the "Today" snapshot, the "Sales team today"
    // per-rep roll-up, and the AI call summaries.
    final isTeam = snapshot.scope == 'team';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshot.isManagerView) _ScopeToggle(scope: snapshot.scope),
        const SizedBox(height: AppDimens.md),
        if (!isTeam) ...[
          _SectionHeader(
            title: 'Today',
            subtitle: "Live snapshot. Refresh anytime.",
          ),
          const SizedBox(height: 6),
          _TodayStrip(today: snapshot.today),
          const SizedBox(height: AppDimens.lg),
        ],
        if (snapshot.canLead) ...[
          _SectionHeader(
            title: 'Follow-ups',
            subtitle: 'Tap to see what\'s due',
          ),
          const SizedBox(height: 6),
          _FollowupsCard(bucket: snapshot.followups),
          const SizedBox(height: AppDimens.lg),
        ],
        if (snapshot.canLead && snapshot.leadStatuses.isNotEmpty) ...[
          _SectionHeader(
            title: 'Leads by status',
            subtitle:
                "${snapshot.leadStatuses.fold<int>(0, (a, b) => a + b.count)} total · tap a bucket to drill in",
          ),
          const SizedBox(height: 6),
          _StatusGrid(
            buckets: snapshot.leadStatuses,
            onTap: (s) {
              // Drill-in — set the pending status filter, then push
              // Leads. LeadsScreen reads + clears this on first build
              // so the list opens pre-filtered to the bucket's status.
              ref.read(pendingLeadStatusFilterProvider.notifier).set(s.status);
              AppNav.go(context, Routes.leads);
            },
          ),
          const SizedBox(height: AppDimens.lg),
        ],
        if (snapshot.canDeal && snapshot.dealStatuses.isNotEmpty) ...[
          _SectionHeader(
            title: 'Deals by stage',
            subtitle:
                "${snapshot.dealStatuses.fold<int>(0, (a, b) => a + b.count)} total · tap to open Deals",
          ),
          const SizedBox(height: 6),
          _StatusGrid(
            buckets: snapshot.dealStatuses,
            onTap: (s) => AppNav.go(context, Routes.deals),
          ),
          const SizedBox(height: AppDimens.lg),
        ],
        if (!isTeam && snapshot.perRep.isNotEmpty) ...[
          _SectionHeader(
            title: 'Sales team today',
            subtitle: "${snapshot.perRep.length} reps · sorted by activity",
          ),
          const SizedBox(height: 6),
          for (final rep in snapshot.perRep) ...[
            _PerRepCard(rep: rep),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: AppDimens.lg),
        ],
        if (!isTeam && snapshot.recentSummaries.isNotEmpty) ...[
          _SectionHeader(
            title: 'AI summaries',
            subtitle: "Latest call analyses. Tap to view.",
          ),
          const SizedBox(height: 6),
          for (final s in snapshot.recentSummaries) ...[
            _SummaryCard(summary: s),
            const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null)
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ScopeToggle extends ConsumerWidget {
  const _ScopeToggle({required this.scope});
  final String scope;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'mine', label: Text('My dashboard')),
        ButtonSegment(value: 'team', label: Text('Team dashboard')),
      ],
      selected: {scope},
      onSelectionChanged: (s) {
        ref.read(dashboardScopeProvider.notifier).set(s.first);
        ref.invalidate(salesDashboardProvider);
      },
    );
  }
}

class _TodayStrip extends StatelessWidget {
  const _TodayStrip({required this.today});
  final TodaySnapshot today;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _KpiTile(label: 'Calls', value: '${today.calls}', icon: Icons.call),
          const SizedBox(width: 8),
          _KpiTile(
            label: 'Connected',
            value: '${today.callsConnected}',
            icon: Icons.call_made,
          ),
          const SizedBox(width: 8),
          _KpiTile(
            label: 'New leads',
            value: '${today.leadsAdded}',
            icon: Icons.person_add_alt,
          ),
          const SizedBox(width: 8),
          _KpiTile(
            label: 'Tasks due',
            value: '${today.tasksDue}',
            icon: Icons.task_alt,
          ),
          const SizedBox(width: 8),
          _KpiTile(
            label: 'Won this month',
            value: moneyShort(today.monthWonValue),
            icon: Icons.emoji_events_outlined,
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// The Follow-ups section is a single tappable summary card — no inline
// number breakdown. Tapping it opens a bottom sheet listing the actual
// due/overdue/upcoming items (mirrors how tapping a Lead-status bucket
// drills in, rather than showing everything inline up front).
class _FollowupsCard extends StatelessWidget {
  const _FollowupsCard({required this.bucket});
  final FollowupsBucket bucket;
  @override
  Widget build(BuildContext context) {
    final total = bucket.dueToday + bucket.overdue + bucket.upcomingWeek;
    final accent = bucket.overdue > 0
        ? const Color(0xFFB23A48)
        : (bucket.dueToday > 0 ? AppColors.primary : const Color(0xFF1B7F4D));
    final summary = total == 0
        ? 'All caught up'
        : [
            if (bucket.overdue > 0) '${bucket.overdue} overdue',
            if (bucket.dueToday > 0) '${bucket.dueToday} today',
            if (bucket.upcomingWeek > 0) '${bucket.upcomingWeek} this week',
          ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      onTap: () => _showFollowupsSheet(context, bucket),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              total == 0 ? Icons.check_circle_outline : Icons.event_repeat,
              color: accent,
              size: 22,
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    total == 0
                        ? 'No follow-ups pending'
                        : '$total follow-up${total == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(summary, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showFollowupsSheet(BuildContext context, FollowupsBucket bucket) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusXl),
      ),
    ),
    builder: (_) => _FollowupsSheet(bucket: bucket),
  );
}

class _FollowupsSheet extends StatelessWidget {
  const _FollowupsSheet({required this.bucket});
  final FollowupsBucket bucket;

  @override
  Widget build(BuildContext context) {
    final overdue = bucket.items.where((i) => i.bucket == 'overdue').toList();
    final dueToday = bucket.items
        .where((i) => i.bucket == 'due_today')
        .toList();
    final upcoming = bucket.items.where((i) => i.bucket == 'upcoming').toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppDimens.lg,
          AppDimens.md,
          AppDimens.lg,
          AppDimens.lg,
        ),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppDimens.md),
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            'Follow-ups',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppDimens.md),
          if (overdue.isNotEmpty)
            _FollowupGroup(
              label: 'Overdue',
              color: const Color(0xFFB23A48),
              items: overdue,
            ),
          if (dueToday.isNotEmpty)
            _FollowupGroup(
              label: 'Due today',
              color: AppColors.primary,
              items: dueToday,
            ),
          if (upcoming.isNotEmpty)
            _FollowupGroup(
              label: 'Next 7 days',
              color: const Color(0xFFB87800),
              items: upcoming,
            ),
          if (bucket.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.xl),
              child: Center(
                child: Text(
                  'All caught up. Nothing pending.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FollowupGroup extends StatelessWidget {
  const _FollowupGroup({
    required this.label,
    required this.color,
    required this.items,
  });
  final String label;
  final Color color;
  final List<FollowupItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label (${items.length})',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in items) _FollowupItemRow(item: item, color: color),
        ],
      ),
    );
  }
}

class _FollowupItemRow extends StatelessWidget {
  const _FollowupItemRow({required this.item, required this.color});
  final FollowupItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final canOpen =
        item.referenceDocname != null &&
        (item.referenceDoctype == 'Lead' ||
            item.referenceDoctype == 'Opportunity');
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      onTap: !canOpen
          ? null
          : () {
              final docname = item.referenceDocname!;
              final isLead = item.referenceDoctype == 'Lead';
              // Close the follow-ups sheet, then open the detail screen with a
              // plain MaterialPageRoute on the root navigator. The Sales
              // workspace is a root-level page that sits outside the
              // StatefulShellRoute, so pushing the shell-branch leadDetail /
              // dealDetail routes via go_router crashes. A direct page push
              // (same pattern used elsewhere for linked docs) works reliably.
              Navigator.of(context).pop();
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => isLead
                      ? LeadDetailScreen(name: docname)
                      : DealDetailScreen(name: docname),
                ),
              );
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item.title == null || item.title!.isEmpty)
                        ? item.name
                        : item.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.dueDate != null)
                    Text(
                      'Due ${item.dueDate!.day}/${item.dueDate!.month}/${item.dueDate!.year}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (canOpen)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.buckets, required this.onTap});
  final List<StatusBucket> buckets;
  final void Function(StatusBucket) onTap;
  @override
  Widget build(BuildContext context) {
    // 2-column grid with auto-sized rows.
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        // Slightly less wide so the count + value row breathes vertically;
        // 2.1 was producing the cramped "₹10Cr crammed against bottom"
        // layout the user flagged.
        childAspectRatio: 2.1,
      ),
      itemCount: buckets.length,
      itemBuilder: (_, i) => _StatusCard(bucket: buckets[i], onTap: onTap),
    );
  }
}

class _StatusCard extends StatefulWidget {
  const _StatusCard({required this.bucket, required this.onTap});

  final StatusBucket bucket;
  final void Function(StatusBucket) onTap;

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  bool _navigating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        if (_navigating) return;

        setState(() {
          _navigating = true;
        });

        widget.onTap(widget.bucket);

        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _navigating = false;
            });
          }
        });
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: widget.bucket.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(
            color: widget.bucket.color.withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.bucket.status,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: widget.bucket.color,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.bucket.staleCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB23A48).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${widget.bucket.staleCount} stale',
                      style: const TextStyle(
                        color: Color(0xFFB23A48),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${widget.bucket.count}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: widget.bucket.color,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                if (widget.bucket.value > 0) ...[
                  const Spacer(),
                  Text(
                    moneyShort(widget.bucket.value),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: widget.bucket.color.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PerRepCard extends StatelessWidget {
  const _PerRepCard({required this.rep});
  final PerRepCard rep;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.secondaryFixed,
            backgroundImage: (rep.image == null || rep.image!.isEmpty)
                ? null
                : NetworkImage(rep.image!),
            child: (rep.image == null || rep.image!.isEmpty)
                ? Text(
                    rep.initials,
                    style: TextStyle(
                      color: AppColors.onSecondaryFixed,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rep.fullName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _RepStat(
                      icon: Icons.person_search_outlined,
                      value: '${rep.leadsOwned}',
                      label: 'leads',
                    ),
                    if (rep.leadsStale > 0)
                      _RepStat(
                        icon: Icons.error_outline,
                        value: '${rep.leadsStale}',
                        label: 'stale',
                        color: const Color(0xFFB23A48),
                      ),
                    _RepStat(
                      icon: Icons.call,
                      value: '${rep.callsToday}',
                      label: 'calls today',
                    ),
                    if (rep.tasksDue > 0)
                      _RepStat(
                        icon: Icons.event_available,
                        value: '${rep.tasksDue}',
                        label: 'due today',
                      ),
                    if (rep.tasksOverdue > 0)
                      _RepStat(
                        icon: Icons.warning_amber,
                        value: '${rep.tasksOverdue}',
                        label: 'overdue',
                        color: const Color(0xFFB87800),
                      ),
                    if (rep.dealsWonMonth > 0)
                      _RepStat(
                        icon: Icons.emoji_events_outlined,
                        value: '${rep.dealsWonMonth}',
                        label: 'won this month',
                        color: const Color(0xFF1B7F4D),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepStat extends StatelessWidget {
  const _RepStat({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(
          '$value ',
          style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12),
        ),
        Text(label, style: TextStyle(color: c, fontSize: 11)),
      ],
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.summary});
  final RecentSummary summary;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      onTap: () {
        // Tap → open the linked lead/deal so the user lands on the
        // Calls tab where the full summary card is rendered.
        if (summary.referenceDoctype == 'Lead' &&
            summary.referenceDocname != null) {
          context.push(Routes.leadDetail, extra: summary.referenceDocname);
        } else if (summary.referenceDoctype == 'Opportunity' &&
            summary.referenceDocname != null) {
          context.push(Routes.dealDetail, extra: summary.referenceDocname);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(AppDimens.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    summary.displayName,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (summary.suggestedStatus != null &&
                    summary.suggestedStatus!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '→ ${summary.suggestedStatus}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (summary.summary != null && summary.summary!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                summary.summary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.msg, required this.onRetry});
  final String msg;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.onErrorContainer),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(color: AppColors.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
