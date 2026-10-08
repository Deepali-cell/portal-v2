import 'package:flutter/foundation.dart' show kReleaseMode;

/// Centralised runtime configuration.
///
/// Overrides at build/run time via `--dart-define`. Example for local dev:
///   flutter run \
///     --dart-define=TCB_MIDDLEWARE_URL=http://127.0.0.1:8001 \
///     --dart-define=TCB_SEND_HOST_HEADER=true \
///     --dart-define=TCB_BIOMETRIC_LOCK=off
class AppConfig {
  AppConfig._();

  /// URL of TCB's middleware (control-plane).
  ///
  /// The mobile app calls `tcb_portal_control.api.tenant.resolve` here on
  /// login to look up the customer's ERPNext server URL. This is the ONE
  /// URL that is compile-time-baked into the binary. Every other URL is
  /// resolved at runtime per tenant.
  static const String middlewareBaseUrl = String.fromEnvironment(
    'TCB_MIDDLEWARE_URL',
    // defaultValue: 'https://office.tcbinfotech.com',
    defaultValue: 'https://swab-writing-upload.ngrok-free.dev',
  );

  /// Optional fallback server URL when no tenant is cached.
  ///
  /// Empty string (default) means "no fallback" — the user must enter a
  /// Company ID. Useful for local dev where you want to point straight at a
  /// known site and skip the middleware step entirely.
  static const String defaultTenantServerUrl = String.fromEnvironment(
    'TCB_DEFAULT_TENANT_URL',
    defaultValue: '',
  );

  /// Company this build is branded for. Set by tool/build_company_apk.sh;
  /// when non-empty the app resolves this company itself instead of asking
  /// the user for a Company ID.
  static const String brandCompanyId = String.fromEnvironment(
    'BRAND_COMPANY_ID',
    defaultValue: '',
  );

  /// Display name shown before the tenant is resolved (first launch).
  static const String brandName = String.fromEnvironment(
    'BRAND_NAME',
    defaultValue: 'TCB Portal',
  );

  static bool get isBrandedBuild => brandCompanyId.isNotEmpty;

  /// Frappe site name. Only sent as a `Host` header when [sendHostHeader] is
  /// true (local multi-site dev over HTTP). Never override Host on an HTTPS
  /// domain.
  static const String siteHost = String.fromEnvironment(
    'TCB_SITE_HOST',
    defaultValue: 'tcb.local',
  );

  static const bool sendHostHeader = bool.fromEnvironment(
    'TCB_SEND_HOST_HEADER',
    defaultValue: false,
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Whether to require a biometric/device-credential unlock when restoring a
  /// session. Can be disabled per-deployment (or for tests) via dart-define.
  static const bool biometricLockEnabled = bool.fromEnvironment(
    'TCB_BIOMETRIC_LOCK',
    defaultValue: true,
  );

  /// Public privacy-policy page, linked from the in-app data disclosures and
  /// required by Google Play. Set it for store builds:
  ///   --dart-define=TCB_PRIVACY_POLICY_URL=https://tcbinfotech.com/privacy
  static const String privacyPolicyUrl = String.fromEnvironment(
    'TCB_PRIVACY_POLICY_URL',
    defaultValue: '',
  );

  /// Whether the login screen offers "Change server" (pointing the app at a
  /// different control server). Debug/profile builds only by default: in a
  /// store build anyone could be talked into entering a phishing server that
  /// then receives their ERP password.
  static const bool allowServerOverride = bool.fromEnvironment(
    'TCB_ALLOW_SERVER_OVERRIDE',
    defaultValue: !kReleaseMode,
  );

  /// True for a URL the app may send credentials to: https always, plain
  /// http only in debug/profile builds (local benches).
  static bool isAllowedServerUrl(String url) {
    final u = Uri.tryParse(url.trim());
    if (u == null || u.host.isEmpty) return false;
    if (u.scheme == 'https') return true;
    return !kReleaseMode && u.scheme == 'http';
  }
}
