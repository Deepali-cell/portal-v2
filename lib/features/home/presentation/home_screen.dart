import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../attendance/application/attendance_controller.dart';
import '../../attendance/domain/models.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../../leave/application/leave_controller.dart';
import '../../leave/domain/models.dart';
import '../../notifications/application/notifications_controller.dart';
import 'nav_destinations.dart';

/// Home screen. Three blocks, top to bottom:
///   1. A greeting hero with quick actions.
///   2. The module grid — every module the user can see, as a tappable card
///      that opens that module's area (its dashboard where it has one).
///   3. Recent activity.
/// The bottom bar shows only Home here; modules live on this screen as cards.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _HomeAppBar(profile: profile),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            _refreshHome(ref);
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              AppDimens.md,
              AppDimens.screenPadding,
              AppDimens.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WelcomeHero(profile: profile),
                const SizedBox(height: AppDimens.lg),
                _ModulesSection(profile: profile),
                const SizedBox(height: AppDimens.lg),
                const _RecentActivity(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Re-fetches the data shown on Home (recent activity + the unread badge).
void _refreshHome(WidgetRef ref) {
  ref.invalidate(attendanceControllerProvider);
  ref.invalidate(leaveControllerProvider);
  ref.invalidate(unreadCountProvider);
}

class _HomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _HomeAppBar({required this.profile});
  final Profile profile;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AppColors.surfaceContainerLowest,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: AppDimens.screenPadding,
      title: Row(
        children: [
          InkWell(
            onTap: () => context.push(Routes.profile),
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  profile.initials,
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          Text('TCB Portal', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _refreshHome(ref),
          tooltip: 'Refresh',
          icon: Icon(Icons.refresh, color: AppColors.primary),
        ),
        Consumer(
          builder: (context, ref, _) {
            final unread = ref.watch(unreadCountProvider).value ?? 0;
            return IconButton(
              onPressed: () => context.push(Routes.notifications),
              tooltip: 'Notifications',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications_outlined, color: AppColors.primary),
                  if (unread > 0)
                    Positioned(
                      right: -4,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.surfaceContainerLowest,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        IconButton(
          onPressed: () => _confirmSignOut(context, ref),
          tooltip: 'Sign out',
          icon: Icon(Icons.logout, color: AppColors.primary),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access the portal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.profile});
  final Profile profile;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = profile.fullName.split(' ').first;
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.graphiteHigh, AppColors.graphite],
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.graphite.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()},',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.80),
                ),
              ),
              Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome to Your workspace',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: AppDimens.md),
              Row(
                children: [
                  _HeroInfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: DateFormat('EEE, d MMM').format(DateTime.now()),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  _HeroInfoChip(
                    icon: Icons.grid_view_rounded,
                    label: '${homeModuleCards(profile).length} modules',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A frosted-glass info pill that reads well on the dark hero — used for
/// at-a-glance portal context (today's date, how many modules you can open).
class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.90)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModulesSection extends StatelessWidget {
  const _ModulesSection({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final cards = homeModuleCards(profile);
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: AppDimens.sm),
          child: Text(
            'Your modules',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppDimens.md,
            crossAxisSpacing: AppDimens.md,
            mainAxisExtent: 164,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) => _ModuleCard(card: cards[i]),
        ),
      ],
    );
  }
}

/// A module tile on Home. Lifts on hover (desktop/web) and dips on press for
/// a tactile "opening" feel before it navigates into the module.
class _ModuleCard extends StatefulWidget {
  const _ModuleCard({required this.card});
  final HomeModuleCard card;
  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final scale = _pressed ? 0.96 : (_hover ? 1.03 : 1.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.graphiteHigh, AppColors.graphite],
            ),
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
            border: Border.all(
              color: _hover
                  ? AppColors.primary.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.08),
              width: _hover ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hover
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.graphite.withValues(alpha: 0.25),
                blurRadius: _hover ? 22 : 10,
                offset: Offset(0, _hover ? 10 : 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              splashColor: Colors.white.withValues(alpha: 0.12),
              highlightColor: Colors.white.withValues(alpha: 0.06),
              onTap: () => AppNav.go(context, card.route),
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: Stack(
                children: [
                  // Oversized faint module glyph — gives each card its own
                  // identity without a bitmap asset.
                  Positioned(
                    right: -18,
                    bottom: -22,
                    child: Icon(
                      card.icon,
                      size: 118,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  // Soft top-left sheen for depth.
                  Positioned(
                    left: -24,
                    top: -30,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(
                          alpha: _hover ? 0.06 : 0.035,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.20),
                                    Colors.white.withValues(alpha: 0.06),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                card.icon,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const Spacer(),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _hover
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : Colors.white.withValues(alpha: 0.10),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.arrow_outward,
                                size: 15,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              card.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              card.tagline,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.62),
                                    height: 1.25,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(attendanceControllerProvider);
    final leave = ref.watch(leaveControllerProvider);

    final items = <_ActivityItem>[];

    attendance.whenData((s) {
      for (final log in s.context.todaysLogs.reversed) {
        items.add(
          _ActivityItem(
            icon: log.logType == LogType.inn
                ? Icons.login_rounded
                : Icons.logout_rounded,
            color: AppColors.secondary,
            tone: AppColors.secondaryFixed,
            title: log.logType == LogType.inn ? 'Checked in' : 'Checked out',
            subtitle: DateFormat('h:mm a').format(log.time.toLocal()),
            when: log.time,
          ),
        );
      }
    });

    leave.whenData((ctx) {
      for (final a in ctx.applications.take(3)) {
        items.add(
          _ActivityItem(
            icon: Icons.calendar_month,
            color: AppColors.primary,
            tone: AppColors.secondaryFixed,
            title: 'Leave ${_statusVerb(a.status)}',
            subtitle:
                '${a.leaveType} · ${DateFormat('d MMM').format(a.fromDate)}'
                '${a.fromDate == a.toDate ? "" : " – ${DateFormat('d MMM').format(a.toDate)}"}',
            when: a.fromDate,
          ),
        );
      }
    });

    items.sort((a, b) => b.when.compareTo(a.when));
    final top = items.take(5).toList();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.md,
              AppDimens.md,
              AppDimens.md,
              AppDimens.sm,
            ),
            child: Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.md,
                0,
                AppDimens.md,
                AppDimens.md,
              ),
              child: Text(
                'Nothing here yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...top.map((it) => _ActivityRow(item: it)),
        ],
      ),
    );
  }

  String _statusVerb(LeaveStatus s) {
    switch (s) {
      case LeaveStatus.approved:
        return 'approved';
      case LeaveStatus.rejected:
        return 'rejected';
      case LeaveStatus.cancelled:
        return 'cancelled';
      case LeaveStatus.open:
        return 'submitted';
    }
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.when,
  });
  final IconData icon;
  final Color color;
  final Color tone;
  final String title;
  final String subtitle;
  final DateTime when;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});
  final _ActivityItem item;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.outlineVariant, width: 0.4),
        ),
      ),
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: item.tone, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            _relative(item.when),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  String _relative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
