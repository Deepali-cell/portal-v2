import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/date_range_bar.dart';
import '../application/expense_controller.dart';
import '../domain/models.dart';

final _dateFmt = DateFormat('d MMM yyyy');

/// HR module's Expense Claims screen. Two tabs:
///   • Claims   - every expense claim (HR/admin) with date + status filtering;
///                tapping one opens a read-only detail sheet.
///   • Requests - claims waiting on the signed-in user; the same detail sheet,
///                with Approve / Reject (reason) actions. This is the same
///                approval flow as the old Expense tab on Approval Requests,
///                which has been removed in favour of this screen.
class ExpenseClaimsScreen extends StatelessWidget {
  const ExpenseClaimsScreen({
    super.key,
    this.initialTab = 0,
    this.initialFilter,
  });

  /// 0 = Claims, 1 = Requests.
  final int initialTab;

  /// Optional starting status filter for the Claims tab, e.g. 'pending' — set
  /// when arriving from the HR dashboard's "Pending Expenses" card so the list
  /// opens already showing only what the card counted.
  final String? initialFilter;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: const AppBackButton(),
          backgroundColor: AppColors.surfaceContainerLowest,
          title: const Text('Expense Claims'),
          actions: [
            Consumer(
              builder: (context, ref, _) => IconButton(
                tooltip: 'Refresh',
                icon: Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () {
                  ref.invalidate(allExpenseClaimsProvider);
                  ref.invalidate(pendingExpenseApprovalsProvider);
                },
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Claims'),
              Tab(text: 'Requests'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _ClaimsTab(initialFilter: initialFilter),
              const _RequestsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Claims tab - all claims, filtered by date range + status
// ---------------------------------------------------------------------------
enum _StatusFilter { all, pending, approved, rejected, paid }

extension _StatusFilterX on _StatusFilter {
  String get label => switch (this) {
    _StatusFilter.all => 'All',
    _StatusFilter.pending => 'Pending',
    _StatusFilter.approved => 'Approved',
    _StatusFilter.rejected => 'Rejected',
    _StatusFilter.paid => 'Paid',
  };

  bool matches(ClaimStatus s) => switch (this) {
    _StatusFilter.all => true,
    _StatusFilter.pending =>
      s == ClaimStatus.draft || s == ClaimStatus.submitted,
    _StatusFilter.approved => s == ClaimStatus.approved,
    _StatusFilter.rejected => s == ClaimStatus.rejected,
    _StatusFilter.paid => s == ClaimStatus.paid,
  };
}

class _ClaimsTab extends ConsumerStatefulWidget {
  const _ClaimsTab({this.initialFilter});
  final String? initialFilter;

  @override
  ConsumerState<_ClaimsTab> createState() => _ClaimsTabState();
}

class _ClaimsTabState extends ConsumerState<_ClaimsTab>
    with AutomaticKeepAliveClientMixin {
  late DateTime _from;
  late DateTime _to;
  late _StatusFilter _filter;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Default to the all-time window so the list matches the dashboard's
    // all-time KPI counts; the "All" chip keeps this in one tap.
    final all = DateRangeBar.allTime();
    _from = all.from;
    _to = all.to;
    _filter = switch (widget.initialFilter) {
      'pending' => _StatusFilter.pending,
      'approved' => _StatusFilter.approved,
      'rejected' => _StatusFilter.rejected,
      'paid' => _StatusFilter.paid,
      _ => _StatusFilter.all,
    };
  }

  ExpenseClaimsRange get _range => (from: _from, to: _to);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(allExpenseClaimsProvider(_range));
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(allExpenseClaimsProvider(_range));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.md,
          AppDimens.screenPadding,
          AppDimens.xl,
        ),
        children: [
          DateRangeBar(
            from: _from,
            to: _to,
            showAll: true,
            onChanged: (f, t) => setState(() {
              _from = f;
              _to = t;
            }),
          ),
          const SizedBox(height: AppDimens.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _StatusFilter.values) ...[
                  ChoiceChip(
                    label: Text(f.label),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                  const SizedBox(width: AppDimens.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppDimens.xxxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: Text(
                e is ApiException ? e.message : 'Could not load claims.',
                textAlign: TextAlign.center,
              ),
            ),
            data: (all) {
              final claims = all
                  .where((c) => _filter.matches(c.status))
                  .toList();
              if (claims.isEmpty) {
                return const _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  text: 'No expense claims in this range.',
                );
              }
              return Column(
                children: [
                  for (final c in claims)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.md),
                      child: _ClaimCard(claim: c),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim});
  final ExpenseClaim claim;

  @override
  Widget build(BuildContext context) {
    final title =
        (claim.employeeName != null && claim.employeeName!.trim().isNotEmpty)
        ? claim.employeeName!
        : claim.name;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: () => _showClaimDetail(context, claim.name),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dateFmt.format(claim.postingDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    // While pending, spell out which hop it is sitting at
                    // (approver vs HR) so oversight sees more than just "Pending".
                    if (claim.status == ClaimStatus.draft &&
                        claim.stageLabel != null &&
                        claim.stageLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        claim.stageLabel!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(claim.totalClaimed, 'INR'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusChip(status: claim.status),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Requests tab - claims waiting on this user, with approve/reject in the sheet
// ---------------------------------------------------------------------------
class _RequestsTab extends ConsumerStatefulWidget {
  const _RequestsTab();

  @override
  ConsumerState<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<_RequestsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(pendingExpenseApprovalsProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(pendingExpenseApprovalsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: Text(
                e is ApiException ? e.message : 'Could not load requests.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                _EmptyState(
                  icon: Icons.inbox_outlined,
                  text: 'No expense claims waiting on you.',
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              AppDimens.md,
              AppDimens.screenPadding,
              AppDimens.xl,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppDimens.md),
            itemBuilder: (_, i) => _RequestCard(item: items[i]),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item});
  final PendingExpenseApproval item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: () => _showClaimDetail(context, item.name, approval: item),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.employeeName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixed,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Text(
                      item.asHr ? 'As HR' : 'Your team',
                      style: TextStyle(
                        color: AppColors.onSecondaryFixedVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Expense · ${money(item.totalClaimed, item.currency)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                _dateFmt.format(item.postingDate),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (item.stageLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.stageLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppDimens.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      _showClaimDetail(context, item.name, approval: item),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('View & action'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail sheet (read-only, or with approve/reject when [approval] is supplied)
// ---------------------------------------------------------------------------
/// Public entry so My Expenses opens the same read-only claim detail sheet.
Future<void> showClaimDetailSheet(BuildContext context, String name) =>
    _showClaimDetail(context, name);

Future<void> _showClaimDetail(
  BuildContext context,
  String name, {
  PendingExpenseApproval? approval,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusXl),
      ),
    ),
    builder: (_) => _ClaimDetailSheet(name: name, approval: approval),
  );
}

class _ClaimDetailSheet extends ConsumerStatefulWidget {
  const _ClaimDetailSheet({required this.name, this.approval});
  final String name;
  final PendingExpenseApproval? approval;

  @override
  ConsumerState<_ClaimDetailSheet> createState() => _ClaimDetailSheetState();
}

class _ClaimDetailSheetState extends ConsumerState<_ClaimDetailSheet> {
  bool _busy = false;

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  bool _opening = false;

  /// Receipts are stored as private files, which a plain URL can't open from an
  /// external browser (no auth token → 403). So we download the bytes through
  /// the authenticated API and open the saved copy in the device's default
  /// viewer (image/PDF). If no app can handle it, fall back to the OS share
  /// sheet so the file is never a dead end.
  Future<void> _open(ExpenseAttachment a) async {
    if (_opening) return;
    setState(() => _opening = true);
    _toast('Opening ${a.fileName}…');
    try {
      final path = await ref
          .read(expenseRepositoryProvider)
          .downloadAttachment(a.name);
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        // No viewer available for this type — hand it to the share sheet.
        await SharePlus.instance.share(
          ShareParams(files: [XFile(path)], fileNameOverrides: [a.fileName]),
        );
      }
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not open the file.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _act(String action) async {
    final item = widget.approval;
    if (item == null) return;
    String? reason;
    if (action == 'Reject') {
      reason = await _askReason(context, item.employeeName);
      if (reason == null) return; // cancelled
    } else {
      final ok = await _confirmApprove(
        context,
        '${item.employeeName} has claimed '
        '${money(item.totalClaimed, item.currency)}.',
      );
      if (!ok) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(expenseControllerProvider.notifier)
          .actOnClaim(name: widget.name, action: action, reason: reason);
      ref.invalidate(allExpenseClaimsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast(
        action == 'Approve'
            ? 'Approved. ${item.asHr ? "The claim is now closed." : "Sent to HR."}'
            : 'Rejected.',
      );
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not update the claim.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(expenseClaimDetailProvider(widget.name));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppDimens.xxxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppDimens.xl),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    e is ApiException ? e.message : 'Could not load the claim.',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          data: (d) => _content(context, d),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ExpenseClaimDetail d) {
    final theme = Theme.of(context);
    final canAct = widget.approval != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with title, status and close cross.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.lg,
            AppDimens.md,
            AppDimens.sm,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.employeeName.isEmpty ? d.name : d.employeeName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (d.postingDate != null)
                      Text(
                        _dateFmt.format(d.postingDate!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              _StatusChip(status: d.status),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: AppDimens.md),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.lg,
              0,
              AppDimens.lg,
              AppDimens.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (d.stageLabel.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.sm),
                    child: Text(
                      d.stageLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                // Amounts.
                Row(
                  children: [
                    Expanded(
                      child: _AmountBox(
                        label: 'Claimed',
                        value: money(d.totalClaimed, d.currency),
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: _AmountBox(
                        label: 'Sanctioned',
                        value: money(d.totalSanctioned, d.currency),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.lg),
                Text('Items', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppDimens.sm),
                for (final l in d.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.expenseType,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (l.expenseDate != null)
                                Text(
                                  _dateFmt.format(l.expenseDate!),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              if (l.description != null &&
                                  l.description!.trim().isNotEmpty)
                                Text(
                                  l.description!.trim(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppDimens.sm),
                        Text(
                          money(l.amount, d.currency),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (d.attachments.isNotEmpty) ...[
                  const Divider(height: AppDimens.xl),
                  Text('Attachments', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppDimens.sm),
                  for (final a in d.attachments)
                    _AttachmentRow(attachment: a, onOpen: () => _open(a)),
                ],
                if (d.remark != null && d.remark!.trim().isNotEmpty) ...[
                  const Divider(height: AppDimens.xl),
                  Text('Remark', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(d.remark!.trim(), style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
        if (canAct)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.lg,
              0,
              AppDimens.lg,
              AppDimens.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _act('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _act('Approve'),
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondaryContainer,
                      foregroundColor: AppColors.onSecondaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared widgets
// ---------------------------------------------------------------------------
class _AmountBox extends StatelessWidget {
  const _AmountBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment, required this.onOpen});
  final ExpenseAttachment attachment;
  final VoidCallback onOpen;

  IconData get _icon {
    final n = attachment.fileName.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.xs),
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.sm),
            child: Row(
              children: [
                Icon(_icon, color: AppColors.primary),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ClaimStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ClaimStatus.approved => ('Approved', const Color(0xFF15803D)),
      ClaimStatus.rejected => ('Rejected', const Color(0xFFB42318)),
      ClaimStatus.paid => ('Paid', const Color(0xFF2563EB)),
      ClaimStatus.unpaid => ('Unpaid', const Color(0xFFB54708)),
      ClaimStatus.cancelled => ('Cancelled', const Color(0xFF6B7280)),
      ClaimStatus.submitted => ('Submitted', const Color(0xFF2563EB)),
      ClaimStatus.draft => ('Pending', const Color(0xFFB54708)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.xxxl),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.onSurfaceVariant),
          const SizedBox(height: AppDimens.md),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Approve confirm + reject reason dialogs
// ---------------------------------------------------------------------------
Future<bool> _confirmApprove(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Approve this claim?'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Approve'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Returns the trimmed reason, or null if the user cancelled.
Future<String?> _askReason(BuildContext context, String who) {
  final ctrl = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Reject this claim?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$who will see this reason.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: AppDimens.md),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Reason',
                hintText: 'Required, at least 4 characters',
                errorText: error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.length < 4) {
                setDialogState(() => error = 'At least 4 characters.');
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    ),
  );
}
