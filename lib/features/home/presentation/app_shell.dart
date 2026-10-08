import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // A floating, rounded "dock" that hovers above the page with a soft
    // shadow. Few tiles share the width evenly; many tiles scroll.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
        child: Container(
          height: AppDimens.bottomNavHeight,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              const minTile = 72.0;
              final fits = tiles.length * minTile <= c.maxWidth - 12;
              final items = [
                for (final t in tiles) _BottomNavItem(tile: t, expand: fits),
              ];
              if (fits) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(children: items),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(children: items),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({required this.tile, required this.expand});
  final _NavTile tile;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final selected = tile.selected;
    final accent = AppColors.secondary;
    final item = Semantics(
      selected: selected,
      button: true,
      label: tile.label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          tile.onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72, minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: selected ? 52 : 36,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            colors: [
                              accent.withValues(alpha: 0.18),
                              AppColors.violet.withValues(alpha: 0.14),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      selected ? tile.selectedIcon : tile.icon,
                      key: ValueKey(selected),
                      size: 22,
                      color: selected ? accent : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tile.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? accent : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return expand ? Expanded(child: item) : item;
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.tiles});
  final List<_NavTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimens.sidebarWidth,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radius3xl),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: AppColors.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'TCB',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TCB Portal',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Employee workspace',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.lg),
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text(
              'MENU',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
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
    final accent = AppColors.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md - 4,
            vertical: AppDimens.sm + 4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected ? tile.selectedIcon : tile.icon,
                size: 22,
                color: selected ? accent : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimens.sm + 4),
              Flexible(
                child: Text(
                  tile.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? accent : AppColors.onSurface,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
