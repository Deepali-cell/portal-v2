import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<List<NotificationItem>> list({bool unreadOnly = false}) async {
    try {
      final resp = await _dio.get(
        ApiPaths.notificationsList,
        queryParameters: {
          'limit': 50,
          if (unreadOnly) 'unread_only': 1,
        },
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) =>
              NotificationItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<int> unreadCount() async {
    try {
      final resp = await _dio.get(ApiPaths.notificationsUnreadCount);
      return ((resp.data['message'] as num?)?.toInt()) ?? 0;
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> markRead(String name) async {
    try {
      await _dio.post(ApiPaths.notificationMarkRead, data: {'name': name});
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post(ApiPaths.notificationsMarkAllRead);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  ApiException _err(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
