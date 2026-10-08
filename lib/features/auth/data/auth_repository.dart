import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/storage/secure_store.dart';
import '../domain/profile.dart';

/// Authentication boundary against Frappe.
///
/// Login is a two-step handshake: password login establishes a session, then
/// the per-user API key/secret is fetched and stored. Every later request uses
/// the token, so neither the password nor the session is retained on-device.
class AuthRepository {
  AuthRepository(this._dio, this._store, this._serverUrl);

  final Dio _dio; // token-authenticated app client (per current tenant)
  final SecureStore _store;
  final String _serverUrl;

  Future<Profile> login(String usr, String pwd) async {
    if (_serverUrl.isEmpty) {
      throw const ApiException(
        ApiErrorKind.unknown,
        'No company server is selected. Enter your Company ID first.',
      );
    }
    final handshake = Dio(
      BaseOptions(
        baseUrl: _serverUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          if (AppConfig.sendHostHeader) 'Host': AppConfig.siteHost,
        },
        validateStatus: (code) => code != null && code < 400,
      ),
    );

    try {
      final loginResp = await handshake.post(
        ApiPaths.login,
        data: {'usr': usr.trim(), 'pwd': pwd},
      );
      final cookie = _sessionCookie(loginResp.headers.map['set-cookie']);

      final credResp = await handshake.post(
        ApiPaths.credentials,
        options: Options(
          headers: cookie != null ? {'Cookie': cookie} : null,
        ),
      );
      final msg = (credResp.data['message'] as Map).cast<String, dynamic>();
      final token = '${msg['api_key']}:${msg['api_secret']}';
      await _store.writeToken(token);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } finally {
      handshake.close(force: true);
    }

    final profile = await fetchProfile();
    await _store.writeProfile(jsonEncode(profile.toJson()));
    return profile;
  }

  Future<Profile> fetchProfile() async {
    try {
      final resp = await _dio.get(ApiPaths.profile);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return Profile.fromJson(msg);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  Future<Employee> updateMyProfile(Map<String, dynamic> patch) async {
    try {
      final resp = await _dio.post(ApiPaths.profileUpdate, data: patch);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return Employee.fromJson(msg);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  Future<Profile?> cachedProfile() async {
    final raw = await _store.readProfile();
    if (raw == null || raw.isEmpty) return null;
    try {
      return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasToken() => _store.hasToken();

  Future<void> logout() async {
    try {
      // Kill this phone's API token on the server, then the web session.
      await _dio.post(ApiPaths.revokeCredentials);
    } catch (_) {
      // best-effort; an older server without the endpoint still logs out
    }
    try {
      await _dio.post(ApiPaths.logout);
    } catch (_) {
      // best-effort server logout; local clear below is what matters
    }
    await _store.clear();
  }

  ApiException _asApiException(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);

  String? _sessionCookie(List<String>? setCookies) {
    if (setCookies == null) return null;
    for (final c in setCookies) {
      final sid = c.split(';').first.trim();
      if (sid.startsWith('sid=')) return sid;
    }
    return null;
  }
}
