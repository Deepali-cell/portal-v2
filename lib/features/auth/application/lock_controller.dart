import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether biometrics have been satisfied for the current app session.
/// Reset to `false` on sign-out and on each cold start.
final sessionUnlockedProvider =
    NotifierProvider<SessionUnlockedNotifier, bool>(SessionUnlockedNotifier.new);

class SessionUnlockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;
  void lock() => state = false;
}
