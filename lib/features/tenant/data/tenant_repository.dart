import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/storage/secure_store.dart';
import '../domain/tenant.dart';

/// Calls the TCB middleware's tenant resolve endpoint.
///
/// Points at the control-plane base URL — the stored override if the user set
/// one (SecureStore.readControlUrl), otherwise the URL baked into the build
/// (AppConfig.middlewareBaseUrl). This is the ONLY call the mobile makes against
/// the control server, and it happens once per Company-ID entry (login, or
/// "Switch company"). NOT the per-tenant ERPNext URL (we don't have it yet).
class TenantRepository {
  TenantRepository(this._store);

  final SecureStore _store;

  /// The control-plane base URL to use right now: the stored override, or the
  /// compile-time default. Trailing slashes stripped.
  Future<String> controlBaseUrl() async {
    final override = AppConfig.allowServerOverride
        ? (await _store.readControlUrl())?.trim()
        : null;
    final base = (override != null &&
            override.isNotEmpty &&
            AppConfig.isAllowedServerUrl(override))
        ? override
        : AppConfig.middlewareBaseUrl;
    return base.replaceAll(RegExp(r'/+$'), '');
  }

  Future<Tenant> resolve(String companyId) async {
    final base = await controlBaseUrl();
    final dio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
          if (AppConfig.sendHostHeader) 'Host': AppConfig.siteHost,
        },
        validateStatus: (code) => code != null && code < 400,
      ),
    );
    try {
      final resp = await dio.get(
        ApiPaths.tenantResolve,
        queryParameters: {'company_id': companyId.trim()},
      );
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      // Normalise the logo URL: backend may return a site-relative path
      // (e.g. /files/acme.png) or an absolute URL whose host is internal
      // (tcb.local). Either way, the mobile needs a URL it can fetch
      // directly. Re-anchor any relative-looking path to the control base.
      msg['logo_url'] = _absoluteLogoUrl(msg['logo_url'] as String?, base);
      final tenant = Tenant.fromResolveResponse(msg);
      // The password goes to this URL next: never over plain http in a
      // store build.
      if (!AppConfig.isAllowedServerUrl(tenant.serverUrl)) {
        throw const ApiException(
          ApiErrorKind.unknown,
          'This company server is not set up for secure (https) access. Contact TCB Infotech.',
        );
      }
      return tenant;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } finally {
      dio.close(force: true);
    }
  }

  /// Logo paths from Frappe can be `/files/x.png`, `/private/files/x.png`,
  /// or absolute URLs against an internal host like `http://tcb.local/...`.
  /// Rewrite to an absolute URL the phone can reach via the control server.
  static String? _absoluteLogoUrl(String? raw, String base) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();
    if (s.startsWith('/')) return '$base$s';
    if (s.startsWith('http://') || s.startsWith('https://')) {
      // If it already points at the middleware host, keep as-is.
      if (s.startsWith(base)) return s;
      // Strip the embedded host and re-anchor to the middleware.
      final idx = s.indexOf('/', s.indexOf('://') + 3);
      if (idx > 0) return '$base${s.substring(idx)}';
      return s;
    }
    // Bare filename — assume /files/.
    return '$base/files/$s';
  }
}
