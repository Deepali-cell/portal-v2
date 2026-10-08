import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/manufacturing_repository.dart';
import '../domain/dashboard_models.dart';

final manufacturingDashboardProvider =
    FutureProvider.autoDispose<ManufacturingDashboard>((ref) async {
  final json = await ref.read(manufacturingRepositoryProvider).dashboard();
  return ManufacturingDashboard.fromJson(json);
});
