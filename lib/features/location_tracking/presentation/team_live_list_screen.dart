import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../home/presentation/app_shell.dart';
import '../data/location_tracking_repository.dart';
import '../domain/models.dart';

/// Landing screen for the "Field team" card. Lists every trackable reportee
/// with their live status; the map is one tap away. Refresh is a first-class
/// action here - the app-bar icon spins while a fetch is in flight and a
/// snackbar confirms when new data lands.
class TeamLiveListScreen extends ConsumerStatefulWidget {
  const TeamLiveListScreen({super.key});
  @override
  ConsumerState<TeamLiveListScreen> createState() =>
      _TeamLiveListScreenState();
}

class _TeamLiveListScreenState extends ConsumerState<TeamLiveListScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _spin.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    _spin.repeat();
    if (!silent) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Refreshing team locations…'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
    }
    ref.invalidate(teamLiveProvider);
    // Wait for the new future to settle so the snackbar timing matches reality.
    try {
      final people = await ref.read(teamLiveProvider.future);
      if (!mounted) return;
      _spin.stop();
      _spin.value = 0;
      if (!silent) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(
                'Updated ${people.length} ${people.length == 1 ? 'person' : 'people'} at ${DateFormat('HH:mm').format(DateTime.now())}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } catch (_) {
      if (!mounted) return;
      _spin.stop();
      _spin.value = 0;
      if (!silent) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text("Couldn't refresh. Check your connection."),
            behavior: SnackBarBehavior.floating,
          ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(teamLiveProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Field team'),
        actions: [
          IconButton(
            tooltip: 'Open map',
            icon: Icon(Icons.map_outlined, color: AppColors.primary),
            onPressed: () => context.push(Routes.locationTeamMap),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: RotationTransition(
              turns: _spin,
              child: Icon(Icons.refresh, color: AppColors.primary),
            ),
            onPressed: () => _refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _refresh(),
        child: async.when(
          loading: () => const _LoadingList(),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimens.xl),
                child: Text(
                  "Couldn't load team locations. Pull down to retry.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          data: (people) => _Body(people: people),
        ),
      ),
      bottomNavigationBar: const PersistentBottomNav(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.people});
  final List<TeamLivePerson> people;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimens.xl),
            child: Column(
              children: [
                const SizedBox(height: AppDimens.xl),
                Icon(Icons.people_outline,
                    size: 48, color: AppColors.onSurfaceVariant),
                const SizedBox(height: AppDimens.md),
                Text(
                  "No trackable teammates yet",
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  "You'll see your direct sales reportees here once they open the app.",
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimens.md),
      itemCount: people.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimens.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header row with counts by status.
          return _Header(people: people);
        }
        final p = people[index - 1];
        return _PersonTile(person: p);
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.people});
  final List<TeamLivePerson> people;

  @override
  Widget build(BuildContext context) {
    final online = people.where((p) => p.status == LiveStatus.online).length;
    final needs = people.where((p) => p.status.needsAttention).length;
    final offline = people.length - online - needs;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sm),
      child: Row(
        children: [
          _pill(context,
              '$online online', const Color(0xFF1B7F4D), Icons.circle),
          const SizedBox(width: 6),
          _pill(context, '$needs need attention',
              const Color(0xFFB23A48), Icons.error_outline),
          const SizedBox(width: 6),
          _pill(context, '$offline offline',
              const Color(0xFF6E7480), Icons.circle_outlined),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label, Color colour, IconData ic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 10, color: colour),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: colour, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person});
  final TeamLivePerson person;

  Color get _color => switch (person.status) {
        LiveStatus.online => const Color(0xFF1B7F4D),
        LiveStatus.stale => const Color(0xFFE65100),
        LiveStatus.offline => const Color(0xFF6E7480),
        LiveStatus.noPermission => const Color(0xFFB23A48),
        LiveStatus.locationOff => const Color(0xFFB23A48),
        LiveStatus.gpsUnavailable => const Color(0xFFE65100),
        LiveStatus.networkError => const Color(0xFF6E7480),
      };

  IconData get _icon => switch (person.status) {
        LiveStatus.online => Icons.location_on,
        LiveStatus.stale => Icons.access_time,
        LiveStatus.offline => Icons.location_off_outlined,
        LiveStatus.noPermission => Icons.gpp_bad_outlined,
        LiveStatus.locationOff => Icons.location_disabled,
        LiveStatus.gpsUnavailable => Icons.satellite_alt_outlined,
        LiveStatus.networkError => Icons.wifi_off_outlined,
      };

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
  }

  String _minutesLabel() {
    if (person.minutesAgo == null) return 'No updates yet';
    final m = person.minutesAgo!.round();
    if (m < 1) return 'Just now';
    if (m < 60) return '$m min ago';
    final h = m ~/ 60;
    if (h < 24) return '${h}h ago';
    return '${h ~/ 24}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        onTap: () => context.push(
          Routes.locationPerson
              .replaceAll(':employee', Uri.encodeComponent(person.employee)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      _initials(person.employeeName),
                      style: TextStyle(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(person.employeeName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_icon, size: 12, color: _color),
                            const SizedBox(width: 4),
                            Text(person.status.label,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: _color,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ],
                    ),
                    if (person.designation.isNotEmpty)
                      Text(person.designation,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      person.hasPosition
                          ? '${_minutesLabel()}  ·  Last seen ${person.latitude!.toStringAsFixed(4)}, ${person.longitude!.toStringAsFixed(4)}'
                          : _minutesLabel(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimens.md),
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.sm),
          child: Card(
            margin: EdgeInsets.zero,
            child: SizedBox(
              height: 82,
              child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
