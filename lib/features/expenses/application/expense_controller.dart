import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/expense_repository.dart';
import '../domain/models.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref.watch(dioProvider)),
);

final expenseControllerProvider =
    AsyncNotifierProvider<ExpenseController, ExpenseContext>(
      ExpenseController.new,
    );

class ExpenseController extends AsyncNotifier<ExpenseContext> {
  DateTime? _from;
  DateTime? _to;

  DateTime get from {
    final f = _from;
    if (f != null) return f;
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  DateTime get to => _to ?? DateTime.now();

  @override
  Future<ExpenseContext> build() =>
      ref.read(expenseRepositoryProvider).getContext(from: from, to: to);

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(expenseRepositoryProvider).getContext(from: from, to: to),
    );
  }

  Future<void> setRange(DateTime newFrom, DateTime newTo) async {
    _from = newFrom;
    _to = newTo;
    await reload();
  }

  /// Files a draft claim, then attaches any receipt/proof files to it. The
  /// claim must exist before its files can be linked, so this creates it first
  /// and uploads each attachment against the returned name.
  Future<void> apply(
    List<ExpenseItem> items, {
    String? remark,
    List<String> attachments = const [],
  }) async {
    final repo = ref.read(expenseRepositoryProvider);
    final name = await repo.apply(items, remark: remark);
    for (final path in attachments) {
      await repo.addAttachment(name, path);
    }
    await reload();
  }

  /// Approve or reject one claim, then refresh the approvals list and the
  /// expense context (its pending count changes too).
  Future<void> actOnClaim({
    required String name,
    required String action,
    String? reason,
  }) async {
    await ref
        .read(expenseRepositoryProvider)
        .actOnClaim(name: name, action: action, reason: reason);
    ref.invalidate(pendingExpenseApprovalsProvider);
    await reload();
  }
}

/// Claims waiting on the signed in user, as approver or as HR.
final pendingExpenseApprovalsProvider =
    FutureProvider<List<PendingExpenseApproval>>(
      (ref) => ref.read(expenseRepositoryProvider).getPendingApprovals(),
    );

/// Date window for the HR "all claims" listing. Equality on the record lets it
/// key a family provider so changing the range refetches.
typedef ExpenseClaimsRange = ({DateTime from, DateTime to});

/// All expense claims in a window (HR/admin see everyone's, others their own).
/// Drives the HR module's Expense Claims screen; separate from
/// [expenseControllerProvider] so the employee self-service screen is untouched.
final allExpenseClaimsProvider = FutureProvider.autoDispose
    .family<List<ExpenseClaim>, ExpenseClaimsRange>(
      (ref, r) => ref
          .read(expenseRepositoryProvider)
          .getAllClaims(from: r.from, to: r.to),
    );

/// On-demand detail (with line items) for a single Expense Claim.
final expenseClaimDetailProvider =
    FutureProvider.family<ExpenseClaimDetail, String>(
      (ref, name) => ref.read(expenseRepositoryProvider).getClaimDetail(name),
    );
