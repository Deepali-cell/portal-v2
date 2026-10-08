import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/notifications_repository.dart';
import '../domain/models.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
    (ref) => NotificationsRepository(ref.watch(dioProvider)));

final notificationsListProvider =
    AsyncNotifierProvider<NotificationsListController, List<NotificationItem>>(
        NotificationsListController.new);

class NotificationsListController extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() =>
      ref.read(notificationsRepositoryProvider).list();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(notificationsRepositoryProvider).list());
    ref.invalidate(unreadCountProvider);
  }

  Future<void> markRead(String name) async {
    await ref.read(notificationsRepositoryProvider).markRead(name);
    // Optimistic local update so we don't pay a full re-fetch for one tap.
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current
          .map((n) => n.name == name
              ? NotificationItem(
                  name: n.name,
                  subject: n.subject,
                  type: n.type,
                  read: true,
                  creation: n.creation,
                  documentType: n.documentType,
                  documentName: n.documentName,
                  fromUser: n.fromUser,
                  emailContent: n.emailContent,
                )
              : n)
          .toList());
    }
    ref.invalidate(unreadCountProvider);
  }

  Future<void> markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current
          .map((n) => NotificationItem(
                name: n.name,
                subject: n.subject,
                type: n.type,
                read: true,
                creation: n.creation,
                documentType: n.documentType,
                documentName: n.documentName,
                fromUser: n.fromUser,
                emailContent: n.emailContent,
              ))
          .toList());
    }
    ref.invalidate(unreadCountProvider);
  }
}

/// Tiny separate provider for the home-bell badge so we can re-watch it
/// without refetching the whole list.
final unreadCountProvider = FutureProvider<int>(
    (ref) => ref.read(notificationsRepositoryProvider).unreadCount());
