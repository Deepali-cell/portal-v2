import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/stock_repository.dart';
import '../domain/models.dart';

final stockRepositoryProvider = Provider<StockRepository>(
    (ref) => StockRepository(ref.watch(dioProvider)));

/// Item master list with live search. `setSearch` debounces via reload.
class ItemsController extends AsyncNotifier<List<Item>> {
  String _search = '';

  @override
  Future<List<Item>> build() =>
      ref.read(stockRepositoryProvider).listItems();

  Future<void> setSearch(String q) async {
    _search = q;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(stockRepositoryProvider).listItems(search: _search));
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(stockRepositoryProvider).listItems(search: _search));
  }
}

final itemsControllerProvider =
    AsyncNotifierProvider<ItemsController, List<Item>>(ItemsController.new);

final itemDetailProvider = FutureProvider.family<ItemDetail, String>(
    (ref, name) => ref.read(stockRepositoryProvider).getItem(name));
