import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_store.dart';
import 'api_exception.dart';

/// Builds and owns the app's [Dio] instance for talking to the active
/// tenant's ERPNext.
///
/// Responsibilities:
///  - inject the `Authorization: token <key>:<secret>` header from [SecureStore]
///  - optionally set the `Host` header for local multi-site dev
///  - normalise every error into an [ApiException]
///  - invoke [onUnauthorized] once when the server rejects the token, so the
///    app can force a sign-out
///
/// The [serverUrl] is supplied at construction time and is expected to be
/// the resolved tenant's URL. The owning Riverpod provider rebuilds this
/// instance when the tenant changes.
class DioClient {
  DioClient(
    this._store, {
    required String serverUrl,
    this.onUnauthorized,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: serverUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
          if (AppConfig.sendHostHeader) 'Host': AppConfig.siteHost,
        },
        // We map non-2xx to ApiException ourselves.
        validateStatus: (code) => code != null && code < 400,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _store.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'token $token';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          final ex = ApiException.fromDio(e);
          // Force sign-out ONLY when the server invalidates the session (401).
          // 403 means "you can't access this specific resource" — the token is
          // still valid, so surface the message to the screen instead.
          if (ex.kind == ApiErrorKind.unauthorized) onUnauthorized?.call();
          handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              type: e.type,
              error: ex,
            ),
          );
        },
      ),
    );
  }

  final SecureStore _store;
  final void Function()? onUnauthorized;
  late final Dio dio;
}
