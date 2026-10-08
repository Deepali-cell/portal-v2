import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';

import '../../../core/location/location_service.dart';
import '../../../core/providers.dart';
import '../data/attendance_repository.dart';
import '../domain/models.dart';

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final connectivityStatusProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => ref.watch(connectivityProvider).onConnectivityChanged,
);

final _queueBoxProvider =
    Provider<Box>((ref) => Hive.box(AttendanceRepository.boxName));

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(
    ref.watch(dioProvider),
    ref.watch(connectivityProvider),
    ref.watch(_queueBoxProvider),
  );
});

@immutable
class AttendanceState {
  const AttendanceState({
    required this.context,
    required this.pendingCount,
    this.position,
    this.nearest,
    this.distanceM,
    this.insideGeofence = false,
    this.locationError,
  });

  final AttendanceContext context;
  final int pendingCount;
  final Position? position;
  final OfficeLocation? nearest;
  final double? distanceM;
  final bool insideGeofence;
  final String? locationError;

  bool get hasLocation => position != null;
  bool get canCheckIn => insideGeofence;
}

final attendanceControllerProvider =
    AsyncNotifierProvider<AttendanceController, AttendanceState>(
        AttendanceController.new);

class AttendanceController extends AsyncNotifier<AttendanceState> {
  @override
  Future<AttendanceState> build() => _load();

  Future<AttendanceState> _load() async {
    final repo = ref.read(attendanceRepositoryProvider);

    // Best-effort: flush anything captured while offline before reading state.
    try {
      await repo.syncPending();
    } catch (_) {}

    final context = await repo.getContext();

    // Render immediately in a "locating" state; resolve GPS in the background
    // so a slow/blocked fix never gates the whole screen.
    Future.microtask(() => _resolveLocation(context));

    return AttendanceState(context: context, pendingCount: repo.pendingCount);
  }

  Future<void> _resolveLocation(AttendanceContext context) async {
    final current = state.value;
    final pendingCount = current?.pendingCount ?? 0;
    try {
      final position = await ref.read(locationServiceProvider).currentPosition();
      final n = _nearestTo(context.locations, position);
      final nearest = n?.$1;
      final distance = n?.$2;
      state = AsyncValue.data(AttendanceState(
        context: context,
        pendingCount: pendingCount,
        position: position,
        nearest: nearest,
        distanceM: distance,
        insideGeofence:
            nearest != null && distance != null && distance <= nearest.radius,
      ));
    } on LocationException catch (e) {
      state = AsyncValue.data(AttendanceState(
        context: context,
        pendingCount: pendingCount,
        locationError: e.message,
      ));
    } catch (_) {
      state = AsyncValue.data(AttendanceState(
        context: context,
        pendingCount: pendingCount,
        locationError: 'Could not determine your location.',
      ));
    }
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  /// Drains the offline queue without flipping the screen to a loading state;
  /// only refreshes if something was actually synced. Safe to call on reconnect.
  Future<void> trySync() async {
    final repo = ref.read(attendanceRepositoryProvider);
    if (repo.pendingCount == 0) return;
    final synced = await repo.syncPending();
    if (synced > 0) await reload();
  }

  /// Re-acquire a GPS fix and recompute geofence status without refetching
  /// server context (cheap; used by the "refresh location" affordance).
  Future<void> refreshLocation() async {
    final current = state.value;
    if (current == null) return reload();
    await _resolveLocation(current.context);
  }

  /// Marks IN/OUT using a fresh GPS fix.
  ///
  /// **On-site path** (default): server enforces the office geofence and the
  /// selfie-required rule for IN.
  ///
  /// **Off-site path** ([offsite] true): geofence is skipped, [reason] is
  /// mandatory. Used for WFH / client-site / field work. Lat/lon still
  /// captured for audit.
  ///
  /// Throws [LocationException] / [ApiException] for the UI to render.
  Future<MarkResult> mark(
    LogType type, {
    String? selfiePath,
    bool offsite = false,
    String? reason,
  }) async {
    final repo = ref.read(attendanceRepositoryProvider);
    // Always re-acquire location at the moment of marking — the cached state
    // can be stale or null if GPS resolved after the screen rendered.
    final position = await ref.read(locationServiceProvider).currentPosition();
    final result = await repo.mark(
      latitude: position.latitude,
      longitude: position.longitude,
      logType: type,
      selfiePath: selfiePath,
      offsite: offsite,
      reason: reason,
    );
    await reload();
    return result;
  }

  (OfficeLocation, double)? _nearestTo(
    List<OfficeLocation> locations,
    Position pos,
  ) {
    final svc = ref.read(locationServiceProvider);
    OfficeLocation? nearest;
    double? best;
    for (final loc in locations) {
      final d = svc.distanceMetres(
        pos.latitude,
        pos.longitude,
        loc.latitude,
        loc.longitude,
      );
      if (best == null || d < best) {
        best = d;
        nearest = loc;
      }
    }
    if (nearest == null || best == null) return null;
    return (nearest, best);
  }
}
