import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());

/// Raised when a device location cannot be obtained. [message] is user-facing.
class LocationException implements Exception {
  const LocationException(this.message, {this.openSettings = false});
  final String message;

  /// True when the only fix is for the user to change OS settings.
  final bool openSettings;

  @override
  String toString() => 'LocationException: $message';
}

/// Wraps geolocator: ensures services + permission, then returns a fix.
class LocationService {
  Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Location services are off. Turn on location to check in.',
        openSettings: true,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Location permission is required to check in.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is blocked. Enable it in Settings to check in.',
        openSettings: true,
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } on TimeoutException {
      throw const LocationException(
        'Timed out getting your location. Move to an open area and retry.',
      );
    }
  }

  /// Distance in metres between two coordinates.
  double distanceMetres(double lat1, double lon1, double lat2, double lon2) =>
      Geolocator.distanceBetween(lat1, lon1, lat2, lon2);

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
