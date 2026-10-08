import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../home/presentation/app_shell.dart';
import '../application/team_status_controller.dart';
import '../domain/models.dart';

class TeamStatusScreen extends ConsumerWidget {
  const TeamStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(teamStatusProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Team status'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(teamStatusProvider),
          ),
        ],
      ),
      body: snap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Err(
          msg: e is ApiException
              ? e.message
              : "Couldn't load team status. Try again.",
          onRetry: () => ref.invalidate(teamStatusProvider),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(teamStatusProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.md,
                AppDimens.screenPadding,
                AppDimens.xl),
            children: [
              _SummaryBanner(snap: s),
              const SizedBox(height: AppDimens.md),
              if (s.users.isEmpty)
                _EmptyState()
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < s.users.length; i++) ...[
                        if (i > 0)
                          Divider(
                              height: 1,
                              indent: 60,
                              color: AppColors.outlineVariant),
                        _MemberRow(member: s.users[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const PersistentBottomNav(),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.snap});
  final dynamic snap;

  @override
  Widget build(BuildContext context) {
    final online = (snap.users as List)
        .where((u) => u.presence == Presence.online)
        .length;
    final idle = (snap.users as List)
        .where((u) => u.presence == Presence.idle)
        .length;
    final offline = (snap.users as List)
        .where((u) => u.presence == Presence.offline)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            _Pill(label: '$online', sub: 'Online', color: const Color(0xFF1B7F4D)),
            const SizedBox(width: AppDimens.sm),
            _Pill(label: '$idle', sub: 'Idle', color: const Color(0xFFB87800)),
            const SizedBox(width: AppDimens.sm),
            _Pill(label: '$offline', sub: 'Offline', color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.sub, required this.color});
  final String label;
  final String sub;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 20)),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});
  final TeamMemberStatus member;

  Color _presenceColor() => switch (member.presence) {
        Presence.online => const Color(0xFF1B7F4D),
        Presence.idle => const Color(0xFFB87800),
        Presence.offline => AppColors.outline,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md, vertical: 10),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.secondaryFixed,
                backgroundImage: (member.image == null || member.image!.isEmpty)
                    ? null
                    : NetworkImage(member.image!),
                child: (member.image == null || member.image!.isEmpty)
                    ? Text(member.initials,
                        style: TextStyle(
                            color: AppColors.onSecondaryFixed,
                            fontWeight: FontWeight.w700))
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _presenceColor(),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.surfaceContainerLowest, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.fullName,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${member.roleLabel} · ${member.lastActiveLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(children: [
                  _CountChip(
                      icon: Icons.phone_outlined,
                      value: member.callsToday,
                      tooltip: 'Calls today'),
                  const SizedBox(width: 8),
                  _CountChip(
                      icon: Icons.fact_check_outlined,
                      value: member.outcomesToday,
                      tooltip: 'Outcomes today'),
                  const SizedBox(width: 8),
                  _CountChip(
                      icon: Icons.person_search_outlined,
                      value: member.leadsOwned,
                      tooltip: 'Leads owned'),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(
      {required this.icon, required this.value, required this.tooltip});
  final IconData icon;
  final int value;
  final String tooltip;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 3),
            Text('$value',
                style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
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
        child: Center(
          child: Text('No sales reps configured yet.',
              style: Theme.of(context).textTheme.bodyMedium),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Card(
          color: AppColors.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(msg,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.onErrorContainer)),
                const SizedBox(height: 8),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
