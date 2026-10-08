import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/task_repository.dart';
import '../domain/models.dart';

final taskRepositoryProvider =
    Provider<TaskRepository>((ref) => TaskRepository(ref.watch(dioProvider)));

final taskControllerProvider =
    AsyncNotifierProvider<TaskController, TaskContext>(TaskController.new);

class TaskController extends AsyncNotifier<TaskContext> {
  @override
  Future<TaskContext> build() => ref.read(taskRepositoryProvider).getContext();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(taskRepositoryProvider).getContext());
  }

  Future<void> create({
    required String subject,
    String? description,
    String? priority,
    DateTime? expEndDate,
    String? project,
  }) async {
    await ref.read(taskRepositoryProvider).create(
          subject: subject,
          description: description,
          priority: priority,
          expEndDate: expEndDate,
          project: project,
        );
    await reload();
  }

  Future<void> setStatus(String name, String status) async {
    await ref.read(taskRepositoryProvider).setStatus(name, status);
    await reload();
  }

  // Named `saveTask` not `update` because `update` is reserved by the
  // AsyncNotifier base class (mutates state).
  Future<void> saveTask({
    required String name,
    String? subject,
    String? description,
    String? priority,
    DateTime? expEndDate,
    bool clearExpEndDate = false,
    String? project,
    bool clearProject = false,
    String? status,
  }) async {
    await ref.read(taskRepositoryProvider).update(
          name: name,
          subject: subject,
          description: description,
          priority: priority,
          expEndDate: expEndDate,
          clearExpEndDate: clearExpEndDate,
          project: project,
          clearProject: clearProject,
          status: status,
        );
    await reload();
    ref.invalidate(taskDetailProvider(name));
  }
}

/// On-demand single-task detail.
final taskDetailProvider = FutureProvider.family<TaskDetail, String>(
    (ref, name) => ref.read(taskRepositoryProvider).getDetail(name));
