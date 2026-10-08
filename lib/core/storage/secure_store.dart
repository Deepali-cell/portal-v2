import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Riverpod provider for the singleton [SecureStore].
final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

/// Encrypted key/value store for the API token and the cached user profile.
///
/// Backed by the platform keystore/keychain via `flutter_secure_storage`
/// (Keychain on iOS, encrypted storage on Android). Plaintext credentials are
/// never persisted; only the derived `api_key:api_secret` token is kept.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kToken = 'tcb.auth.token';
  static const _kProfile = 'tcb.auth.profile';
  static const _kTenant = 'tcb.tenant';
  static const _kControlUrl = 'tcb.control.base_url';
  static const _kLeadsViewPrefs = 'tcb.leads.view_prefs';
  static const _kCallDetectEnabled = 'tcb.call_detect.enabled';
  static const _kCallDetectFirstSetup = 'tcb.call_detect.first_setup_done';

  Future<void> writeToken(String token) =>
      _storage.write(key: _kToken, value: token);

  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<bool> hasToken() async => (await readToken())?.isNotEmpty ?? false;

  Future<void> writeProfile(String json) =>
      _storage.write(key: _kProfile, value: json);

  Future<String?> readProfile() => _storage.read(key: _kProfile);

  /// The serialised current [Tenant] (resolved via the middleware on login).
  Future<void> writeTenant(String json) =>
      _storage.write(key: _kTenant, value: json);

  Future<String?> readTenant() => _storage.read(key: _kTenant);

  Future<void> clearTenant() => _storage.delete(key: _kTenant);

  /// Optional override for the control-plane (middleware) base URL used to
  /// resolve a Company ID at login. Empty/unset means "use the URL baked into
  /// the build" (AppConfig.middlewareBaseUrl). Lets one APK point at a different
  /// control server — e.g. a laptop running its own control — without a rebuild.
  Future<void> writeControlUrl(String url) =>
      _storage.write(key: _kControlUrl, value: url);
  Future<String?> readControlUrl() => _storage.read(key: _kControlUrl);
  Future<void> clearControlUrl() => _storage.delete(key: _kControlUrl);

  /// Persisted UI prefs for the Leads list (sort + density). JSON-encoded.
  Future<void> writeLeadsViewPrefs(String json) =>
      _storage.write(key: _kLeadsViewPrefs, value: json);
  Future<String?> readLeadsViewPrefs() =>
      _storage.read(key: _kLeadsViewPrefs);

  /// Master toggle for native call detection + recording (Phase D.2.1).
  /// Stored as "1" / "0" strings to keep the API simple.
  Future<void> writeCallDetectEnabled(bool enabled) =>
      _storage.write(key: _kCallDetectEnabled, value: enabled ? '1' : '0');
  Future<bool> readCallDetectEnabled() async =>
      (await _storage.read(key: _kCallDetectEnabled)) == '1';

  Future<void> writeCallDetectFirstSetupDone() =>
      _storage.write(key: _kCallDetectFirstSetup, value: '1');
  Future<bool> readCallDetectFirstSetupDone() async =>
      (await _storage.read(key: _kCallDetectFirstSetup)) == '1';

  /// Sign-out: clears the auth token and cached profile. The tenant is
  /// intentionally preserved so the login screen stays pre-themed for the
  /// returning user. Use [clearAll] for "Switch company".
  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kProfile);
  }

  /// Full wipe — used by "Switch company" to reset everything.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
