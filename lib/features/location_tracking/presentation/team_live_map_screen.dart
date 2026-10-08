import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/router/app_router.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../data/location_tracking_repository.dart';
import '../domain/models.dart';
import 'package:go_router/go_router.dart';

/// Manager-facing map that plots every reportee's most recent position.
/// Pin colour = online (green) / stale (amber) / offline (grey).
class TeamLiveMapScreen extends ConsumerStatefulWidget {
  const TeamLiveMapScreen({super.key});
  @override
  ConsumerState<TeamLiveMapScreen> createState() =>
      _TeamLiveMapScreenState();
}

class _TeamLiveMapScreenState extends ConsumerState<TeamLiveMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Refresh every 60 s while this screen is on top so the pins stay live.
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
    try {
      await ref.read(teamLiveProvider.future);
    } catch (_) {/* handled by AsyncValue.when */}
    if (!mounted) return;
    _spin.stop();
    _spin.value = 0;
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
            tooltip: 'Refresh',
            icon: RotationTransition(
              turns: _spin,
              child: Icon(Icons.refresh, color: AppColors.primary),
            ),
            onPressed: () => _refresh(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.xl),
            child: Text(
              "Couldn't load team locations. Pull to retry.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
        data: (people) => _buildBody(people),
      ),
    );
  }

  Widget _buildBody(List<TeamLivePerson> people) {
    final placed = people.where((p) => p.hasPosition).toList();
    if (placed.isEmpty) {
      return _EmptyState(anyPeople: people.isNotEmpty);
    }
    final center = _averageCenter(placed);
    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 11.5,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tcbinfotech.tcb_portal',
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: placed
                    .map((p) => Marker(
                          point: p.latLng!,
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: _PinButton(
                            person: p,
                            onTap: () => context.push(
                              Routes.locationPerson.replaceAll(
                                  ':employee', Uri.encodeComponent(p.employee)),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        _PeopleStrip(
          people: people,
          onTap: (p) {
            final pos = p.latLng;
            if (pos != null) {
              _map.move(pos, 15);
            }
            context.push(
              Routes.locationPerson.replaceAll(
                  ':employee', Uri.encodeComponent(p.employee)),
            );
          },
        ),
      ],
    );
  }

  LatLng _averageCenter(List<TeamLivePerson> pts) {
    double lat = 0, lng = 0;
    for (final p in pts) {
      lat += p.latitude!;
      lng += p.longitude!;
    }
    return LatLng(lat / pts.length, lng / pts.length);
  }
}

class _PinButton extends StatelessWidget {
  const _PinButton({required this.person, required this.onTap});
  final TeamLivePerson person;
  final VoidCallback onTap;

  Color get _color => switch (person.status) {
        LiveStatus.online => const Color(0xFF1B7F4D),
        LiveStatus.stale => const Color(0xFFE65100),
        LiveStatus.offline => const Color(0xFF6E7480),
        // "Needs attention" statuses share a red hue so managers can spot
        // them at a glance across all pins.
        LiveStatus.noPermission => const Color(0xFFB23A48),
        LiveStatus.locationOff => const Color(0xFFB23A48),
        LiveStatus.gpsUnavailable => const Color(0xFFE65100),
        LiveStatus.networkError => const Color(0xFF6E7480),
      };

  @override
  Widget build(BuildContext context) {
    final initials = person.employeeName.trim().isEmpty
        ? '?'
        : person.employeeName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((s) => s[0].toUpperCase())
            .join();
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Icon(Icons.arrow_drop_down, color: _color, size: 14),
        ],
      ),
    );
  }
}

class _PeopleStrip extends StatelessWidget {
  const _PeopleStrip({required this.people, required this.onTap});
  final List<TeamLivePerson> people;
  final void Function(TeamLivePerson) onTap;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md, vertical: AppDimens.sm),
        itemBuilder: (_, i) {
          final p = people[i];
          final subtitle = p.minutesAgo == null
              ? 'No pings yet'
              : '${p.minutesAgo!.toStringAsFixed(0)} min ago  ·  ${p.status.label}';
          return GestureDetector(
            onTap: () => onTap(p),
            child: Container(
              width: 160,
              padding: const EdgeInsets.all(AppDimens.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.employeeName,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: AppDimens.sm),
        itemCount: people.length,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.anyPeople});
  final bool anyPeople;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 48, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppDimens.md),
            Text(
              anyPeople
                  ? 'Your team has not shared any locations yet. Ask them to turn on Location sharing in the app.'
                  : "You don't have any direct or indirect reports.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
