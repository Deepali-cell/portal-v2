import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import 'nav_destinations.dart';

/// One resolved nav tile: either a top-level destination (Home) or a module
/// launcher / a destination inside the currently-active module.
class _NavTile {
  const _NavTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// Root shell. Mobile gets the horizontally-scrollable bottom nav; tablet/
/// desktop (>=840 px) gets a persistent side rail. Both render two levels:
/// outside any module you see Home + one tile per module; once inside a
/// module the bar switches to that module's own items (plus a way back).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    final dests = destinationsFor(profile);
    final currentRoute = _currentRoute(context);
    final tiles = _buildNavTiles(context, dests, currentRoute);
    final wide = MediaQuery.sizeOf(context).width >= 840;

    // Global hardware-back handling for the whole portal. When GoRouter can pop
    // a genuinely pushed page (a detail screen, a root-level screen) we let
    // Flutter do it. Otherwise, if we have branch history to retrace we consume
    // the back and step to the previous screen; only at Home with no history
    // does the OS get to background the app.
    ref.watch(navHistoryProvider);
    final canRouterPop = GoRouter.of(context).canPop();
    final hasHistory = ref.read(navHistoryProvider).isNotEmpty;
    final scaffold = wide
        ? Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              children: [
                _SideRail(tiles: tiles),
                VerticalDivider(width: 1, color: AppColors.outlineVariant),
                Expanded(child: shell),
              ],
            ),
          )
        : Scaffold(
            backgroundColor: AppColors.background,
            body: shell,
            bottomNavigationBar: const PersistentBottomNav(),
          );

    return PopScope(
      canPop: canRouterPop || !hasHistory,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        AppNav.back(context);
      },
      child: scaffold,
    );
  }
}

String _currentRoute(BuildContext context) =>
    GoRouterState.of(context).matchedLocation;

/// Level 1 (no module active): Home + one tile per module that has at
/// least one visible destination. Level 2 (inside a module): a "Modules"
/// tile to go back to Home, followed by that module's own destinations.
List<_NavTile> _buildNavTiles(
  BuildContext context,
  List<NavDest> dests,
  String currentRoute,
) {
  final activeModule = activeModuleFor(dests, currentRoute);

  if (activeModule == null) {
    // Top level: only Home. Every module is reached from a card on the Home
    // screen, not from the bottom bar. The bar stays a single anchor tile.
    final tiles = <_NavTile>[];
    for (final d in dests.where((d) => d.module == null)) {
      final selected = isInBranch(d.route, currentRoute);
      tiles.add(
        _NavTile(
          icon: d.icon,
          selectedIcon: d.selectedIcon,
          label: d.label,
          selected: selected,
          onTap: () {
            if (!selected) AppNav.go(context, d.route);
          },
        ),
      );
    }
    return tiles;
  }

  // Inside a module: Home (back to the module grid) + that module's own tabs,
  // with its Dashboard first.
  final tiles = <_NavTile>[
    _NavTile(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
      selected: false,
      onTap: () {
        AppNav.go(context, Routes.home);
      },
    ),
  ];
  for (final d in dests.where((d) => d.module == activeModule)) {
    final selected = isInBranch(d.route, currentRoute);
    tiles.add(
      _NavTile(
        icon: d.icon,
        selectedIcon: d.selectedIcon,
        label: d.label,
        selected: selected,
        onTap: () {
          if (!selected) AppNav.go(context, d.route);
        },
      ),
    );
  }
  return tiles;
}

/// Bottom nav bar (running-timer strip + scrollable tiles) reused by
/// [AppShell] and by full-screen routes pushed outside the shell (e.g. Sales
/// Workspace and its sub-screens) so the tab bar stays visible everywhere.
class PersistentBottomNav extends ConsumerWidget {
  const PersistentBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    final dests = destinationsFor(profile);
    final currentRoute = _currentRoute(context);
    final tiles = _buildNavTiles(context, dests, currentRoute);
    return _ScrollableBottomNav(tiles: tiles);
  }
}

class _ScrollableBottomNav extends StatelessWidget {
  const _ScrollableBottomNav({required this.tiles});
  final List<_NavTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.graphiteHigh, AppColors.graphite],
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.graphite.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppDimens.bottomNavHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [for (final t in tiles) _BottomNavItem(tile: t)],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({required this.tile});
  final _NavTile tile;

  @override
  Widget build(BuildContext context) {
    final selected = tile.selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 14 : 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? Border.all(color: Colors.white.withValues(alpha: 0.22))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? tile.selectedIcon : tile.icon,
                size: 20,
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.62),
              ),
              const SizedBox(height: 1),
              Text(
                tile.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.62),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.tiles});
  final List<_NavTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimens.sidebarWidth,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
                alignment: Alignment.center,
                child: Text(
                  'TCB',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Text(
                'TCB Portal',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.xl),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [for (final t in tiles) _SideTile(tile: t)],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideTile extends StatelessWidget {
  const _SideTile({required this.tile});
  final _NavTile tile;

  @override
  Widget build(BuildContext context) {
    final selected = tile.selected;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md,
            vertical: AppDimens.sm + 4,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryFixed : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(
                selected ? tile.selectedIcon : tile.icon,
                color: selected
                    ? AppColors.onSecondaryFixed
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimens.sm),
              Flexible(
                child: Text(
                  tile.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? AppColors.onSecondaryFixed
                        : AppColors.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
