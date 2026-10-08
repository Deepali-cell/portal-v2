import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/lead_repository.dart';
import '../domain/models.dart';

final leadRepositoryProvider = Provider<LeadRepository>(
  (ref) => LeadRepository(ref.watch(dioProvider)),
);

final leadsControllerProvider =
    AsyncNotifierProvider<LeadsController, LeadsContext>(LeadsController.new);

class LeadsController extends AsyncNotifier<LeadsContext> {
  @override
  Future<LeadsContext> build() => ref.read(leadRepositoryProvider).getContext();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(leadRepositoryProvider).getContext(),
    );
  }

  Future<void> create(Map<String, dynamic> fields) async {
    await ref.read(leadRepositoryProvider).create(fields);
    await reload();
  }

  Future<void> save(String name, Map<String, dynamic> fields) async {
    await ref.read(leadRepositoryProvider).update(name, fields);
    // Invalidate + await the refetch synchronously so the caller only
    // returns after the fresh detail is in the provider. Otherwise the
    // detail screen's next _prime() can run against the STALE cached
    // value — that was the "save shows once, reopen reverts" bug.
    ref.invalidate(leadDetailProvider(name));
    await ref.read(leadDetailProvider(name).future);
    await reload();
  }

  /// Convert this Lead to an ERPNext Opportunity (step 1 of
  /// Lead → Opportunity → Customer). Returns the new Opportunity's name.
  Future<String> convertToOpportunity(String name) async {
    final opportunity = await ref
        .read(leadRepositoryProvider)
        .convertToOpportunity(name);
    ref.invalidate(leadDetailProvider(name));
    await reload();
    return opportunity;
  }

  /// Backwards-compat alias — kept so older callers keep compiling.
  Future<String> convertToDeal(String name) => convertToOpportunity(name);
}

/// Detail for a single lead, fetched on demand by name. `.autoDispose` so
/// the cached value is thrown away when the last listener leaves the
/// screen — re-opening the same lead always re-fetches from the backend.
/// Without autoDispose the cache retained the pre-edit value even after
/// invalidate(), which surfaced as "save shows saved once but reopens
/// to the old value".
final leadDetailProvider = FutureProvider.autoDispose.family<Lead, String>(
  (ref, name) => ref.read(leadRepositoryProvider).getDetail(name),
);
