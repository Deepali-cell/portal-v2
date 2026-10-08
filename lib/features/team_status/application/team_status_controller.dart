import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/team_status_repository.dart';
import '../domain/models.dart';

final teamStatusRepositoryProvider = Provider<TeamStatusRepository>(
    (ref) => TeamStatusRepository(ref.watch(dioProvider)));

final teamStatusProvider =
    FutureProvider.autoDispose<TeamStatusSnapshot>((ref) {
  return ref.read(teamStatusRepositoryProvider).fetch();
});
