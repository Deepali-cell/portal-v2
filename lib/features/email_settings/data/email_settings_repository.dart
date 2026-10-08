import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';

/// Current outgoing-email config as returned by the backend. Never carries the
/// password (write-only from the app's side).
class EmailSettings {
  const EmailSettings({
    required this.configured,
    this.accountName,
    this.emailId,
    this.smtpServer,
    this.smtpPort,
    this.useTls = true,
    this.useSsl = false,
    this.enabled = false,
  });

  final bool configured;
  final String? accountName;
  final String? emailId;
  final String? smtpServer;
  final int? smtpPort;
  final bool useTls;
  final bool useSsl;
  final bool enabled;

  factory EmailSettings.fromJson(Map<String, dynamic> j) => EmailSettings(
        configured: j['configured'] == true,
        accountName: j['account_name'] as String?,
        emailId: j['email_id'] as String?,
        smtpServer: j['smtp_server'] as String?,
        smtpPort: (j['smtp_port'] as num?)?.toInt(),
        useTls: (j['use_tls'] as num?)?.toInt() == 1,
        useSsl: (j['use_ssl'] as num?)?.toInt() == 1,
        enabled: (j['enabled'] as num?)?.toInt() == 1,
      );
}

class EmailSettingsRepository {
  EmailSettingsRepository(this._dio);
  final Dio _dio;

  Future<EmailSettings> fetch() async {
    try {
      final resp = await _dio.get(ApiPaths.emailSettingsGet);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return EmailSettings.fromJson(msg);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> save({
    required String emailId,
    String? password,
    String? provider,
    String? smtpServer,
    int? smtpPort,
    bool? useTls,
    bool? useSsl,
    String? accountName,
  }) async {
    try {
      await _dio.post(ApiPaths.emailSettingsSave, data: {
        'email_id': emailId,
        if (password != null && password.isNotEmpty) 'password': password,
        if (provider != null && provider.isNotEmpty) 'provider': provider,
        if (smtpServer != null && smtpServer.isNotEmpty) 'smtp_server': smtpServer,
        'smtp_port': ?smtpPort,
        if (useTls != null) 'use_tls': useTls ? 1 : 0,
        if (useSsl != null) 'use_ssl': useSsl ? 1 : 0,
        if (accountName != null && accountName.isNotEmpty) 'account_name': accountName,
      });
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<String> sendTest({String? to}) async {
    try {
      final resp = await _dio.post(ApiPaths.emailSettingsTest,
          data: {if (to != null && to.isNotEmpty) 'to': to});
      final msg = (resp.data['message'] as Map?)?.cast<String, dynamic>();
      return (msg?['sent_to'] as String?) ?? (to ?? '');
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  ApiException _err(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}

final emailSettingsRepositoryProvider = Provider<EmailSettingsRepository>(
  (ref) => EmailSettingsRepository(ref.watch(dioProvider)),
);

final emailSettingsProvider = FutureProvider.autoDispose<EmailSettings>(
  (ref) => ref.watch(emailSettingsRepositoryProvider).fetch(),
);
