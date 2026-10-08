import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/deal_repository.dart';
import '../domain/models.dart';

final dealRepositoryProvider =
    Provider<DealRepository>((ref) => DealRepository(ref.watch(dioProvider)));

final dealsControllerProvider =
    AsyncNotifierProvider<DealsController, DealsContext>(DealsController.new);

class DealsController extends AsyncNotifier<DealsContext> {
  @override
  Future<DealsContext> build() => ref.read(dealRepositoryProvider).getContext();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(dealRepositoryProvider).getContext());
  }

  Future<void> save(String name, Map<String, dynamic> fields) async {
    await ref.read(dealRepositoryProvider).update(name, fields);
    ref.invalidate(dealDetailProvider(name));
    await reload();
  }

  /// Convert this Opportunity to an ERPNext Customer (step 2 of
  /// Lead → Opportunity → Customer). Returns the new Customer's name.
  Future<String> convertToCustomer(String name) async {
    final customer =
        await ref.read(dealRepositoryProvider).convertToCustomer(name);
    ref.invalidate(dealDetailProvider(name));
    await reload();
    return customer;
  }
}

/// Detail for a single deal, fetched on demand by name.
final dealDetailProvider = FutureProvider.family<Deal, String>(
  (ref, name) => ref.read(dealRepositoryProvider).getDetail(name),
);
