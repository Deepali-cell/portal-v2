import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcb_portal/core/network/api_exception.dart';

ApiException _from403(dynamic body) {
  final req = RequestOptions(path: '/api/method/x');
  final e = DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: req,
      statusCode: 403,
      data: body,
    ),
  );
  return ApiException.fromDio(e);
}

void main() {
  group('ApiException parser', () {
    test('extracts a real human message from _server_messages', () {
      final body = {
        '_server_messages':
            jsonEncode([jsonEncode({'message': 'Sorry, you can\'t see this.', 'title': 'Message'})])
      };
      final ex = _from403(body);
      expect(ex.kind, ApiErrorKind.forbidden);
      expect(ex.message, 'Sorry, you can\'t see this.');
    });

    test('falls back to a clean default when _server_messages is empty '
        '(regression: empty payload used to render as raw JSON fragments)', () {
      final body = {
        '_server_messages':
            jsonEncode([jsonEncode({'message': '', 'as_table': false, 'title': 'Message'})]),
        'exc_type': 'PermissionError',
      };
      final ex = _from403(body);
      expect(ex.message,
          isNot(contains('as_table')),
          reason: 'must not leak JSON field names into the UI');
      expect(ex.message, 'You do not have permission to view this record.');
    });

    test('uses exc_type to label permission errors when message is missing', () {
      final ex = _from403({'exc_type': 'frappe.exceptions.PermissionError'});
      expect(ex.message, 'You do not have permission to view this record.');
    });

    test('strips HTML tags and decodes entities', () {
      final body = {
        '_server_messages': jsonEncode([
          jsonEncode({
            'message': '<p>You can\'t do that &amp; that\'s final.</p>',
            'title': 'Message',
          })
        ])
      };
      final ex = _from403(body);
      expect(ex.message, "You can't do that & that's final.");
    });
  });
}
