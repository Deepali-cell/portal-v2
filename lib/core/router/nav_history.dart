import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// A linear history of the shell-branch locations the user has walked through.
///
/// The app is a hub-and-spoke built on [StatefulShellRoute.indexedStack]. Moving
/// between branches (Home -> a module -> a list -> a dashboard) is done with
/// `context.go(...)`, which swaps the indexed stack and keeps **no** cross-branch
/// back stack. Without help, a branch-root screen therefore has nothing to pop:
/// no AppBar back arrow appears and the hardware back key exits the app instead
/// of returning to the previous screen.
///
/// We record every forward branch switch here (via [AppNav.go]) so a single
/// global back affordance ([AppBackButton] + the [PopScope] in the shell) can
/// retrace it. Screens that are *pushed* on a navigator (detail screens, the
/// root-level screens) already pop correctly on their own; [AppNav] defers to
/// `GoRouter.pop()` for those and only falls back to this history when the
/// router itself cannot pop.
class NavHistoryNotifier extends Notifier<List<String>> {
  /// Cap so a long session of tab-hopping cannot grow the stack without bound.
  static const _maxDepth = 50;

  @override
  List<String> build() => const [];

  /// Record [location] as a screen we can return to. Consecutive duplicates are
  /// collapsed so repeatedly tapping the same tile does not stack copies.
  void push(String location) {
    if (location.isEmpty) return;
    if (state.isNotEmpty && state.last == location) return;
    final next = [...state, location];
    if (next.length > _maxDepth) next.removeRange(0, next.length - _maxDepth);
    state = next;
  }

  /// Remove and return the most recent location, or null when empty.
  String? pop() {
    if (state.isEmpty) return null;
    final copy = [...state];
    final prev = copy.removeLast();
    state = copy;
    return prev;
  }

  void clear() => state = const [];
}

final navHistoryProvider = NotifierProvider<NavHistoryNotifier, List<String>>(
  NavHistoryNotifier.new,
);

/// Navigation helpers that keep [navHistoryProvider] in sync so back always
/// lands on the previous screen, portal-wide.
class AppNav {
  AppNav._();

  /// Switch to a shell-branch [route], recording where we came from so a later
  /// back retraces it.
  ///
  /// Any screens sitting on the ROOT navigator (Sales Workspace, Pipeline,
  /// Leaderboard - the routes registered with `parentNavigatorKey:
  /// rootNavigatorKey`) are popped first. Going straight to `context.go(route)`
  /// while such a screen is still on top can hit Flutter's
  /// `!keyReservation.contains(key)` GlobalKey assertion, since the branch
  /// switch and the root-stack pop would otherwise happen in the same frame.
  /// `GoRouter.of(context)` is captured up front (the caller's own screen may be
  /// one of the popped ones, deactivating `context`), and each pop is awaited so
  /// GoRouter's page list settles before the next step.
  static Future<void> go(BuildContext context, String route) async {
    final goRouter = GoRouter.of(context);
    final current = GoRouterState.of(context).matchedLocation;
    if (current != route) {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(navHistoryProvider.notifier).push(current);
    }
    final root = rootNavigatorKey.currentState;
    while (root != null && root.canPop()) {
      await root.maybePop();
    }
    goRouter.go(route);
  }

  /// The single back action used by [AppBackButton] and the shell's [PopScope].
  ///
  /// Order of preference: pop a genuinely pushed page (detail screens etc.);
  /// else retrace the branch history; else fall back to Home; else, already at
  /// Home with nothing recorded, let the OS background the app.
  static void back(BuildContext context) {
    final goRouter = GoRouter.of(context);
    if (goRouter.canPop()) {
      goRouter.pop();
      return;
    }
    final prev = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(navHistoryProvider.notifier).pop();
    if (prev != null) {
      goRouter.go(prev);
      return;
    }
    final here = GoRouterState.of(context).matchedLocation;
    if (here != Routes.home) {
      goRouter.go(Routes.home);
      return;
    }
    SystemNavigator.pop();
  }

  /// Whether a back affordance would do anything from the current location.
  /// False only when we are at Home with no pushed page and no history.
  static bool canGoBack(BuildContext context) {
    if (GoRouter.of(context).canPop()) return true;
    if (ProviderScope.containerOf(
      context,
      listen: false,
    ).read(navHistoryProvider).isNotEmpty) {
      return true;
    }
    return GoRouterState.of(context).matchedLocation != Routes.home;
  }
}

/// A back arrow for AppBars on branch-root screens, which otherwise have nothing
/// to pop. Behaves like the standard back button on pushed screens (pops the
/// page) and retraces the branch history everywhere else. Renders nothing when
/// there is genuinely nowhere to go back to (i.e. at Home).
class AppBackButton extends ConsumerWidget {
  const AppBackButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild when history changes so the arrow appears/disappears correctly.
    ref.watch(navHistoryProvider);
    if (!AppNav.canGoBack(context)) return const SizedBox.shrink();
    return IconButton(
      icon: const BackButtonIcon(),
      color: color,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => AppNav.back(context),
    );
  }
}
