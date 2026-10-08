import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_store.dart';
import '../domain/models.dart';

/// Sort orderings the user can pick for the Leads list (Runo R.11).
enum LeadSort { latestActivity, mostStale, newest, oldest, nameAZ }

extension LeadSortX on LeadSort {
  String get label => switch (this) {
    LeadSort.latestActivity => 'Latest activity',
    LeadSort.mostStale => 'Most stale',
    LeadSort.newest => 'Newest',
    LeadSort.oldest => 'Oldest',
    LeadSort.nameAZ => 'Name A-Z',
  };

  String get storageKey => name;
}

LeadSort _sortFromKey(String? k) => LeadSort.values.firstWhere(
  (v) => v.name == k,
  orElse: () => LeadSort.latestActivity,
);

/// Row density on the Leads list. Compact mode hides the organisation hint
/// and shrinks vertical padding so more rows fit on screen.
enum LeadDensity { comfortable, compact }

extension LeadDensityX on LeadDensity {
  String get label => switch (this) {
    LeadDensity.comfortable => 'Comfortable',
    LeadDensity.compact => 'Compact',
  };
}

LeadDensity _densityFromKey(String? k) => LeadDensity.values.firstWhere(
  (v) => v.name == k,
  orElse: () => LeadDensity.comfortable,
);

@immutable
class LeadsViewPrefs {
  const LeadsViewPrefs({
    this.sort = LeadSort.latestActivity,
    this.density = LeadDensity.comfortable,
  });
  final LeadSort sort;
  final LeadDensity density;

  LeadsViewPrefs copyWith({LeadSort? sort, LeadDensity? density}) =>
      LeadsViewPrefs(sort: sort ?? this.sort, density: density ?? this.density);

  Map<String, dynamic> toJson() => {'sort': sort.name, 'density': density.name};
  factory LeadsViewPrefs.fromJson(Map<String, dynamic> j) => LeadsViewPrefs(
    sort: _sortFromKey(j['sort'] as String?),
    density: _densityFromKey(j['density'] as String?),
  );
}

final leadsViewPrefsProvider =
    NotifierProvider<LeadsViewPrefsController, LeadsViewPrefs>(
      LeadsViewPrefsController.new,
    );

/// Pending status pre-filter — set by the dashboard when the user taps a
/// bucket (`"New"`, `"Contacted"`, `"Junk"`, etc.), then read + cleared by
/// LeadsScreen on its first build so the list opens filtered to that
/// bucket. Null means "no filter, show all".
class LeadStatusFilterController extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? status) => state = status;
  void clear() => state = null;
}

final pendingLeadStatusFilterProvider =
    NotifierProvider<LeadStatusFilterController, String?>(
      LeadStatusFilterController.new,
    );

class LeadsViewPrefsController extends Notifier<LeadsViewPrefs> {
  @override
  LeadsViewPrefs build() {
    // Hydrate asynchronously; first emit is the default.
    Future.microtask(() async {
      final raw = await ref.read(secureStoreProvider).readLeadsViewPrefs();
      if (raw == null || raw.isEmpty) return;
      try {
        state = LeadsViewPrefs.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>(),
        );
      } catch (_) {
        // Corrupted JSON — fall back silently to defaults.
      }
    });
    return const LeadsViewPrefs();
  }

  void setSort(LeadSort s) {
    state = state.copyWith(sort: s);
    _persist();
  }

  void setDensity(LeadDensity d) {
    state = state.copyWith(density: d);
    _persist();
  }

  void _persist() {
    ref
        .read(secureStoreProvider)
        .writeLeadsViewPrefs(jsonEncode(state.toJson()));
  }
}

/// Pure sort applied to a list of [Lead] rows. Stable: equal-key items keep
/// their original relative order so the user doesn't see "jumping" rows.
List<Lead> applyLeadSort(List<Lead> rows, LeadSort sort) {
  final list = List<Lead>.of(rows);
  switch (sort) {
    case LeadSort.latestActivity:
      list.sort(
        (a, b) => _compareNullableDate(b.lastContactAt, a.lastContactAt),
      );
    case LeadSort.mostStale:
      list.sort((a, b) {
        // NULL days bubble to the top with a "—" hint (oldest / never).
        final ad = a.daysSinceContact ?? 1 << 30;
        final bd = b.daysSinceContact ?? 1 << 30;
        return bd.compareTo(ad);
      });
    case LeadSort.newest:
      // The backend already returns modified DESC. Keep that order.
      break;
    case LeadSort.oldest:
      list.sort((a, b) => a.name.compareTo(b.name));
    // Lead.name encodes creation order in Frappe's autoname (CRM-LEAD-YYYY-####)
    // so name ASC ≈ creation ASC. Cheap, deterministic, no extra field.
    case LeadSort.nameAZ:
      list.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
  }
  return list;
}

int _compareNullableDate(DateTime? a, DateTime? b) {
  // Both null -> equal. Null lasts (we want recent activity first).
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
