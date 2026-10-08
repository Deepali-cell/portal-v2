import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../data/location_tracking_repository.dart';
import '../domain/models.dart';

class PersonLocationScreen extends ConsumerWidget {
  const PersonLocationScreen({super.key, required this.employee});
  final String employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCurrent = ref.watch(personCurrentProvider(employee));
    final asyncTrail = ref.watch(personTrailProvider(employee));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Live location'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () {
              ref.invalidate(personCurrentProvider(employee));
              ref.invalidate(personTrailProvider(employee));
            },
          ),
        ],
      ),
      body: asyncCurrent.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.xl),
            child: Text(
              "Couldn't load this person's location.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
        data: (current) {
          if (current.latest == null) {
            return _NoData(current: current);
          }
          return Column(
            children: [
              _Header(current: current),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: current.latest!.latLng,
                    initialZoom: 15,
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
                    // Today's trail as a polyline behind the current marker.
                    asyncTrail.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (trail) => trail.points.length >= 2
                          ? PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: trail.points
                                      .map((p) => p.latLng)
                                      .toList(),
                                  color: AppColors.primary
                                      .withValues(alpha: 0.55),
                                  strokeWidth: 3.5,
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: current.latest!.latLng,
                          width: 44,
                          height: 44,
                          child: Icon(Icons.location_on,
                              color: AppColors.error, size: 44),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              asyncTrail.maybeWhen(
                data: (t) => _TrailBar(count: t.points.length),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.current});
  final PersonCurrent current;

  @override
  Widget build(BuildContext context) {
    final latest = current.latest!;
    final ago = latest.minutesAgo == null
        ? '-'
        : latest.minutesAgo! < 1
            ? 'just now'
            : '${latest.minutesAgo!.toStringAsFixed(0)} min ago';
    final needsAttention = current.status.needsAttention;
    final statusLabel = current.status.label;
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      color: AppColors.surfaceContainerLowest,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: Text(
              _initials(current.employeeName),
              style: TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(current.employeeName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (current.designation.isNotEmpty)
                  Text(current.designation,
                      style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  'Last update $ago  ·  $statusLabel  ·  ${latest.accuracyM.toStringAsFixed(0)} m accuracy',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: needsAttention ? AppColors.error : null,
                      fontWeight:
                          needsAttention ? FontWeight.w700 : FontWeight.w400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
  }
}

class _TrailBar extends StatelessWidget {
  const _TrailBar({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    final label = count == 0
        ? 'No trail today'
        : count == 1
            ? '1 ping today'
            : '$count pings today';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md, vertical: AppDimens.sm),
      color: AppColors.surfaceContainerLowest,
      child: Row(
        children: [
          Icon(Icons.timeline, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(DateFormat('EEE, d MMM').format(DateTime.now()),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData({required this.current});
  final PersonCurrent current;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_disabled,
                size: 48, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppDimens.md),
            Text(
              '${current.employeeName} has not shared any location yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              current.trackingEnabled
                  ? 'Sharing is on but no ping has arrived yet.'
                  : 'Ask them to turn on Location sharing in the app.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
