import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/directory_repository.dart';
import '../domain/models.dart';

final directoryRepositoryProvider = Provider<DirectoryRepository>(
    (ref) => DirectoryRepository(ref.watch(dioProvider)));

final directoryControllerProvider =
    AsyncNotifierProvider<DirectoryController, List<DirectoryEntry>>(
        DirectoryController.new);

class DirectoryController extends AsyncNotifier<List<DirectoryEntry>> {
  String _search = '';

  @override
  Future<List<DirectoryEntry>> build() =>
      ref.read(directoryRepositoryProvider).list();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(directoryRepositoryProvider).list(search: _search));
  }

  Future<void> setSearch(String search) async {
    _search = search.trim();
    state = await AsyncValue.guard(
        () => ref.read(directoryRepositoryProvider).list(search: _search));
  }
}
