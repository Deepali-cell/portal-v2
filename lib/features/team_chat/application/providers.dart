import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/team_chat_repository.dart';
import '../domain/models.dart';

final teamChatRepositoryProvider = Provider<TeamChatRepository>(
    (ref) => TeamChatRepository(ref.watch(dioProvider)));

final chatChannelsProvider =
    FutureProvider.autoDispose<List<ChatChannel>>((ref) =>
        ref.read(teamChatRepositoryProvider).listChannels());

final chatMessagesProvider =
    FutureProvider.autoDispose.family<List<ChatMessage>, String>(
        (ref, channel) =>
            ref.read(teamChatRepositoryProvider).listMessages(channel));
