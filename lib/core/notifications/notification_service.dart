import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_paths.dart';
import '../providers.dart';

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService(ref));

/// Push-notification integration point.
///
/// Backend is complete (FCM HTTP v1 + `register_device`/`unregister_device`).
/// The Firebase client SDK is NOT yet wired because it requires a Firebase
/// project + native config (see PUSH_SETUP.md). Once `firebase_messaging` is
/// added, fetch the FCM token in [syncRegistration] and pass it to
/// [registerToken]; the rest already works.
class NotificationService {
  NotificationService(this._ref);
  final Ref _ref;

  /// Called after sign-in. No-op until Firebase is configured.
  Future<void> syncRegistration() async {
    // TODO(push): once firebase_messaging is added:
    //   final token = await FirebaseMessaging.instance.getToken();
    //   await FirebaseMessaging.instance.requestPermission();
    //   if (token != null) await registerToken(token, platform);
    return;
  }

  Future<void> registerToken(String token, String platform) async {
    await _ref.read(dioProvider).post(
      ApiPaths.registerDevice,
      data: {'token': token, 'platform': platform},
    );
  }

  Future<void> unregisterToken(String token) async {
    await _ref.read(dioProvider).post(
      ApiPaths.unregisterDevice,
      data: {'token': token},
    );
  }
}
