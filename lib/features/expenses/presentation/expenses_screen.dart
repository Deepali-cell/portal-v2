import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../../../shared/widgets/date_range_bar.dart';
import '../../../shared/widgets/employee_only_notice.dart';
import '../../auth/application/auth_controller.dart';
import '../application/expense_controller.dart';
import '../domain/models.dart';
import 'expense_claims_screen.dart' show showClaimDetailSheet;

final _dateFmt = DateFormat('d MMM yyyy');
final _rangeFmt = DateFormat('d MMM yyyy');

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final noEmployee = profile != null && !profile.hasEmployee;
    final async = ref.watch(expenseControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('My Expenses'),
        actions: [
          if (!noEmployee)
            IconButton(
              tooltip: 'Refresh',
              icon: Icon(Icons.refresh, color: AppColors.primary),
              onPressed: () =>
                  ref.read(expenseControllerProvider.notifier).reload(),
            ),
        ],
      ),
      body: noEmployee
          ? const EmployeeOnlyNotice(feature: 'Expenses')
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e is ApiException
                    ? e.message
                    : 'Something unexpected happened. Please try again.',
                onRetry: () =>
                    ref.read(expenseControllerProvider.notifier).reload(),
              ),
              data: (ctx) => RefreshIndicator(
                onRefresh: () =>
                    ref.read(expenseControllerProvider.notifier).reload(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.md,
                    AppDimens.screenPadding,
                    AppDimens.xl,
                  ),
                  children: [
                    _Header(
                      title: 'My Expenses',
                      subtitle: 'Submit claims and track approvals.',
                      cta: 'New Claim',
                      onPressed: () => _openSheet(context, ctx),
                    ),
                    const SizedBox(height: AppDimens.md),
                    DateRangeBar(
                      from: ctx.fromDate,
                      to: ctx.toDate,
                      onChanged: (f, t) => ref
                          .read(expenseControllerProvider.notifier)
                          .setRange(f, t),
                    ),
                    const SizedBox(height: AppDimens.md),
                    if (ctx.claims.isEmpty)
                      _EmptyCard(
                        icon: Icons.receipt_long_outlined,
                        text:
                            'No expense claims between ${_rangeFmt.format(ctx.fromDate)} and ${_rangeFmt.format(ctx.toDate)}.',
                      )
                    else ...[
                      _TotalsCard(
                        claims: ctx.claims,
                        currency: ctx.currency,
                        fromDate: ctx.fromDate,
                        toDate: ctx.toDate,
                      ),
                      const SizedBox(height: AppDimens.md),
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppDimens.md,
                                AppDimens.md,
                                AppDimens.md,
                                AppDimens.sm,
                              ),
                              child: Text(
                                'My Claims',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            for (var i = 0; i < ctx.claims.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  indent: 64,
                                  color: AppColors.outlineVariant,
                                ),
                              _ClaimRow(
                                claim: ctx.claims[i],
                                currency: ctx.currency,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _openSheet(BuildContext context, ExpenseContext ctx) async {
    if (ctx.expenseTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No expense types configured. Contact HR.'),
        ),
      );
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      builder: (_) => _NewClaimSheet(ctx: ctx),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Expense claim submitted for approval.'),
          ),
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onPressed,
  });
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppDimens.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add, size: 18),
            label: Text(cta),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondaryContainer,
              foregroundColor: AppColors.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.claims,
    required this.currency,
    required this.fromDate,
    required this.toDate,
  });
  final List<ExpenseClaim> claims;
  final String currency;
  final DateTime fromDate;
  final DateTime toDate;

  @override
  Widget build(BuildContext context) {
    double pending = 0, approved = 0, paid = 0;
    for (final c in claims) {
      switch (c.status) {
        case ClaimStatus.draft:
        case ClaimStatus.submitted:
          pending += c.totalClaimed;
        case ClaimStatus.approved:
        case ClaimStatus.unpaid:
          approved += c.totalClaimed;
        case ClaimStatus.paid:
          paid += c.totalClaimed;
        case ClaimStatus.rejected:
        case ClaimStatus.cancelled:
          break;
      }
    }
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Claims summary',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_rangeFmt.format(fromDate)} – ${_rangeFmt.format(toDate)} · ${claims.length} ${claims.length == 1 ? 'claim' : 'claims'}',
            style: TextStyle(color: AppColors.primaryFixedDim, fontSize: 12),
          ),
          const SizedBox(height: AppDimens.md),
          Row(
            children: [
              Expanded(
                child: _kv(context, 'Pending', money(pending, currency)),
              ),
              Container(
                width: 1,
                height: 28,
                color: AppColors.primaryFixedDim.withValues(alpha: 0.25),
              ),
              Expanded(
                child: _kv(context, 'Approved', money(approved, currency)),
              ),
              Container(
                width: 1,
                height: 28,
                color: AppColors.primaryFixedDim.withValues(alpha: 0.25),
              ),
              Expanded(child: _kv(context, 'Paid', money(paid, currency))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: TextStyle(color: AppColors.primaryFixedDim, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            v,
            style: TextStyle(
              color: AppColors.onPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow({required this.claim, required this.currency});
  final ExpenseClaim claim;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showClaimDetailSheet(context, claim.name),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.receipt_long_outlined,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    money(claim.totalClaimed, currency),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${claim.name} · ${_dateFmt.format(claim.postingDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  // The chip reads Pending across both waiting hops, so the stage
                  // tells the employee whether their approver has cleared it and
                  // it is now with HR.
                  if (claim.status == ClaimStatus.draft &&
                      claim.stageLabel != null &&
                      claim.stageLabel!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      claim.stageLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
            _ClaimStatusChip(status: claim.status),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

class _ClaimStatusChip extends StatelessWidget {
  const _ClaimStatusChip({required this.status});
  final ClaimStatus status;

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    late String label;
    switch (status) {
      case ClaimStatus.approved:
        bg = AppColors.tertiaryFixed;
        fg = AppColors.onTertiaryFixedVariant;
        label = 'Approved';
      case ClaimStatus.paid:
        bg = AppColors.tertiaryFixed;
        fg = AppColors.onTertiaryFixedVariant;
        label = 'Paid';
      case ClaimStatus.rejected:
        bg = AppColors.errorContainer;
        fg = AppColors.onErrorContainer;
        label = 'Rejected';
      case ClaimStatus.submitted:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = 'Submitted';
      case ClaimStatus.unpaid:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = 'Unpaid';
      case ClaimStatus.cancelled:
        bg = AppColors.surfaceContainerHigh;
        fg = AppColors.onSurfaceVariant;
        label = 'Cancelled';
      case ClaimStatus.draft:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Row(
          children: [
            Icon(icon, color: AppColors.outline),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewClaimSheet extends ConsumerStatefulWidget {
  const _NewClaimSheet({required this.ctx});
  final ExpenseContext ctx;

  @override
  ConsumerState<_NewClaimSheet> createState() => _NewClaimSheetState();
}

class _ItemDraft {
  _ItemDraft(this.type);
  String? type;
  final TextEditingController amount = TextEditingController();
  final TextEditingController description = TextEditingController();
  void dispose() {
    amount.dispose();
    description.dispose();
  }
}

class _NewClaimSheetState extends ConsumerState<_NewClaimSheet> {
  late final List<_ItemDraft> _items = [
    _ItemDraft(widget.ctx.expenseTypes.first),
  ];
  final _remark = TextEditingController();
  // Receipt / proof files to attach to the claim once it is created. Each is a
  // local file the user picked; paths go up as multipart uploads after apply.
  final List<PlatformFile> _attachments = [];
  bool _submitting = false;
  String? _error;

  Future<void> _pickAttachments() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      // Same set the server accepts for receipts.
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
    );
    if (picked == null) return;
    setState(() {
      for (final f in picked.files) {
        if (f.path != null && !_attachments.any((a) => a.path == f.path)) {
          _attachments.add(f);
        }
      }
    });
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    _remark.dispose();
    super.dispose();
  }

  double get _total => _items.fold(
    0,
    (sum, i) => sum + (double.tryParse(i.amount.text.trim()) ?? 0),
  );

  Future<void> _submit() async {
    setState(() => _error = null);
    final parsed = <ExpenseItem>[];
    for (final i in _items) {
      final amt = double.tryParse(i.amount.text.trim()) ?? 0;
      if (i.type == null || amt <= 0) {
        setState(
          () => _error = 'Each item needs a type and an amount above zero.',
        );
        return;
      }
      parsed.add(
        ExpenseItem(
          expenseType: i.type!,
          amount: amt,
          description: i.description.text.trim(),
        ),
      );
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(expenseControllerProvider.notifier)
          .apply(
            parsed,
            remark: _remark.text.trim(),
            attachments: _attachments
                .map((a) => a.path)
                .whereType<String>()
                .toList(),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not submit. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.xl,
        AppDimens.xl,
        AppDimens.xl,
        AppDimens.xl + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'New expense claim',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppDimens.xl),
            for (var idx = 0; idx < _items.length; idx++) ...[
              _itemRow(idx),
              const SizedBox(height: AppDimens.md),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(
                  () => _items.add(_ItemDraft(widget.ctx.expenseTypes.first)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    money(_total, widget.ctx.currency),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            TextField(
              controller: _remark,
              decoration: const InputDecoration(labelText: 'Remark (optional)'),
            ),
            const SizedBox(height: AppDimens.md),
            _attachmentsSection(),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppDimens.xl),
            BrandButton(
              label: 'Submit claim',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(int idx) {
    final item = _items[idx];
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: item.type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: widget.ctx.expenseTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => item.type = v),
                ),
              ),
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  onPressed: () => setState(() {
                    _items.removeAt(idx).dispose();
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          TextField(
            controller: item.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          const SizedBox(height: AppDimens.sm),
          TextField(
            controller: item.description,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
        ],
      ),
    );
  }

  /// Receipt / proof files. What is attached here rides up with the claim and
  /// shows in the ERP's Attachments sidebar for the approver and HR.
  Widget _attachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Receipts / proof (optional)',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _submitting ? null : _pickAttachments,
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('Attach'),
            ),
          ],
        ),
        if (_attachments.isEmpty)
          Text(
            'Attach a bill or receipt as proof for this claim.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          for (final f in _attachments)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.insert_drive_file_outlined,
                    size: 18,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.error,
                    ),
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _attachments.remove(f)),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: AppDimens.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
