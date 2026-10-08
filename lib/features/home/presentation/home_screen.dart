import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          color: AppColors.secondary,
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
                const SizedBox(height: AppDimens.xl - 4),
                _ModulesSection(profile: profile),
                const SizedBox(height: AppDimens.xl - 4),
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
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: AppColors.background,
      toolbarHeight: 72,
      titleSpacing: AppDimens.screenPadding,
      title: Row(
        children: [
          Semantics(
            button: true,
            label: 'Open profile',
            child: InkWell(
              onTap: () => context.push(Routes.profile),
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      AppColors.secondary,
                      AppColors.violet,
                      AppColors.sky,
                      AppColors.secondary,
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                  ),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      profile.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TCB Portal',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  profile.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _AppBarAction(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onTap: () => _refreshHome(ref),
        ),
        Consumer(
          builder: (context, ref, _) {
            final unread = ref.watch(unreadCountProvider).value ?? 0;
            return _AppBarAction(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              onTap: () => context.push(Routes.notifications),
              badge: unread > 0 ? (unread > 99 ? '99+' : '$unread') : null,
            );
          },
        ),
        _AppBarAction(
          icon: Icons.logout_rounded,
          tooltip: 'Sign out',
          onTap: () => _confirmSignOut(context, ref),
        ),
        const SizedBox(width: AppDimens.screenPadding - 6),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.logout_rounded, color: AppColors.error, size: 32),
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access the portal.',
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
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

/// Rounded-square app-bar action with an optional count badge. 44 px touch
/// target so it is easy to hit.
class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: badge == null ? tooltip : '$tooltip, $badge unread',
          child: Material(
            color: AppColors.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppColors.outlineVariant),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: 22, color: AppColors.onSurface),
                    if (badge != null)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 17,
                            minHeight: 17,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.rose,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.surfaceContainerLowest,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.profile});
  final Profile profile;

  (String, IconData) _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return ('Good morning', Icons.wb_sunny_rounded);
    if (h < 17) return ('Good afternoon', Icons.wb_cloudy_rounded);
    return ('Good evening', Icons.nightlight_round);
  }

  @override
  Widget build(BuildContext context) {
    final firstName = profile.fullName.split(' ').first;
    final (greeting, greetIcon) = _greeting();
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppDimens.radius3xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radius3xl),
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: -60,
              child: _Orb(size: 200, color: AppColors.violet),
            ),
            Positioned(
              left: -40,
              bottom: -70,
              child: _Orb(size: 170, color: AppColors.sky),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(greetIcon, size: 18, color: AppColors.amber),
                      const SizedBox(width: 6),
                      Text(
                        greeting,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$firstName 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome to your workspace',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: AppDimens.lg),
                  Wrap(
                    spacing: AppDimens.sm,
                    runSpacing: AppDimens.sm,
                    children: [
                      _HeroInfoChip(
                        icon: Icons.calendar_today_rounded,
                        label: DateFormat('EEE, d MMM').format(DateTime.now()),
                      ),
                      _HeroInfoChip(
                        icon: Icons.grid_view_rounded,
                        label: '${homeModuleCards(profile).length} modules',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft radial glow used to give gradient headers depth.
class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.50),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
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
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: 2,
        right: 2,
        bottom: AppDimens.sm + 4,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailing!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                ),
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
        _SectionHeader(title: 'Your modules', trailing: '${cards.length}'),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 1000
                ? 4
                : c.maxWidth >= 640
                ? 3
                : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: AppDimens.md - 2,
                crossAxisSpacing: AppDimens.md - 2,
                mainAxisExtent: 160,
              ),
              itemCount: cards.length,
              itemBuilder: (context, i) => _StaggeredIn(
                index: i,
                child: _ModuleCard(card: cards[i]),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Fades + lifts a child into place, staggered by [index], the first time it
/// is built. Gives the Home grid a lively entrance without being slow.
class _StaggeredIn extends StatelessWidget {
  const _StaggeredIn({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (index * 45).clamp(0, 400);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delay),
      curve: Interval(delay / (380 + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A module tile on Home. White card with the module's own gradient icon
/// tile. Lifts on hover (desktop/web) and dips on press for a tactile feel.
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
    final colors = AppColors.moduleGradient(card.module);
    final accent = colors.first;
    final scale = _pressed ? 0.97 : (_hover ? 1.02 : 1.0);
    final radius = BorderRadius.circular(AppDimens.radius2xl);
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: radius,
            border: Border.all(
              color: _hover
                  ? accent.withValues(alpha: 0.45)
                  : AppColors.outlineVariant.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: (_hover ? accent : AppColors.primary).withValues(
                  alpha: _hover ? 0.22 : 0.06,
                ),
                blurRadius: _hover ? 26 : 18,
                offset: Offset(0, _hover ? 12 : 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: radius,
              splashColor: accent.withValues(alpha: 0.10),
              highlightColor: accent.withValues(alpha: 0.05),
              onTap: () {
                HapticFeedback.selectionClick();
                AppNav.go(context, card.route);
              },
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: Stack(
                children: [
                  // Soft tinted wash in the corner — ties the card to its
                  // module colour without overpowering the text.
                  Positioned(
                    right: -30,
                    top: -30,
                    child: _Orb(
                      size: 120,
                      color: accent.withValues(alpha: 0.35),
                    ),
                  ),
                  Positioned(
                    right: -14,
                    bottom: -18,
                    child: Icon(
                      card.icon,
                      size: 92,
                      color: accent.withValues(alpha: 0.06),
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
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: colors,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
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
                              duration: const Duration(milliseconds: 160),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _hover
                                    ? accent
                                    : accent.withValues(alpha: 0.10),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.arrow_outward_rounded,
                                size: 16,
                                color: _hover ? Colors.white : accent,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              card.tagline,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.3,
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
            icon: Icons.event_available_rounded,
            color: AppColors.violet,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Recent activity'),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimens.radius2xl),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.8),
            ),
            boxShadow: AppColors.softShadow(),
          ),
          child: top.isEmpty
              ? const _ActivityEmpty()
              : Column(
                  children: [
                    for (var i = 0; i < top.length; i++)
                      _ActivityRow(item: top[i], first: i == 0),
                  ],
                ),
        ),
      ],
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

class _ActivityEmpty extends StatelessWidget {
  const _ActivityEmpty();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.xl,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: 0.08),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.secondary,
              size: 28,
            ),
          ),
          const SizedBox(height: AppDimens.md),
          Text('All quiet for now', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Your check-ins and leave updates will show up here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, this.first = false});
  final _ActivityItem item;
  final bool first;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(
                top: BorderSide(
                  color: AppColors.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.md - 2,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Icon(item.icon, color: item.color, size: 21),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _relative(item.when),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
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
