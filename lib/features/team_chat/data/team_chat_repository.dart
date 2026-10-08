import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../crm_shared/domain/models.dart' show UserOption;
import '../domain/models.dart';

class TeamChatRepository {
  TeamChatRepository(this._dio);
  final Dio _dio;

  Future<List<ChatChannel>> listChannels() async {
    try {
      final resp = await _dio.get(ApiPaths.chatChannels);
      return ((resp.data['message'] as List?) ?? const [])
          .map((e) => ChatChannel.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<ChatMessage>> listMessages(String channel) async {
    try {
      final resp = await _dio
          .get(ApiPaths.chatMessages, queryParameters: {'channel': channel});
      return ((resp.data['message'] as List?) ?? const [])
          .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> sendMessage(String channel, String message) async {
    try {
      await _dio.post(ApiPaths.chatSend,
          data: {'channel': channel, 'message': message});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Find or create the 1:1 channel with [user]; returns the channel id.
  Future<String> startDirect(String user) async {
    try {
      final resp =
          await _dio.post(ApiPaths.chatStartDirect, data: {'other_user': user});
      return (resp.data['message']['name'] ?? '').toString();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<UserOption>> searchUsers(String query) async {
    try {
      final resp = await _dio.get(ApiPaths.userSearch,
          queryParameters: {'query': query, 'limit': 20});
      return ((resp.data['message'] as List?) ?? const [])
          .map((e) => UserOption.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
