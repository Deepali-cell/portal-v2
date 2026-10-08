import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../config/app_config.dart';

final biometricServiceProvider =
    Provider<BiometricService>((ref) => BiometricService());

/// Thin wrapper over device biometrics (Face ID / Touch ID / fingerprint).
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// True when the device can perform a biometric or device-credential check.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && (canCheck || await _hasEnrolled());
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> _hasEnrolled() async {
    try {
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Prompts the user. Returns true only on a successful unlock.
  Future<bool> authenticate({String reason = 'Unlock ${AppConfig.brandName}'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // allow device PIN/passcode fallback
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
