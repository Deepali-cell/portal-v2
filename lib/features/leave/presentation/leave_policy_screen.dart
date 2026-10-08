import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../application/leave_controller.dart';
import '../domain/models.dart';

const _allTypes = '__all__';

/// HR configuration for leave notice-period rules. Each rule says a leave of up
/// to N days must be applied at least M days in advance. leave.apply() enforces
/// them as a hard block. Only HR/admin can open and use this (server-enforced).
class LeavePolicyScreen extends ConsumerWidget {
  const LeavePolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaveNoticeRulesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Leave Policy'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(leaveNoticeRulesProvider),
          ),
        ],
      ),
      floatingActionButton: async.maybeWhen(
        data: (d) => FloatingActionButton.extended(
          onPressed: () => _openSheet(context, ref, leaveTypes: d.leaveTypes),
          icon: const Icon(Icons.add),
          label: const Text('Add rule'),
        ),
        orElse: () => null,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(leaveNoticeRulesProvider);
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
                    e is ApiException ? e.message : 'Could not load rules.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            data: (d) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.md,
                AppDimens.screenPadding,
                96,
              ),
              children: [
                const _Intro(),
                const SizedBox(height: AppDimens.md),
                if (d.rules.isEmpty)
                  const _EmptyState()
                else
                  for (final r in d.rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.md),
                      child: _RuleCard(
                        rule: r,
                        onEdit: () => _openSheet(
                          context,
                          ref,
                          leaveTypes: d.leaveTypes,
                          existing: r,
                        ),
                        onDelete: () => _confirmDelete(context, ref, r),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref, {
    required List<String> leaveTypes,
    LeaveNoticeRule? existing,
  }) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      builder: (_) => _RuleSheet(leaveTypes: leaveTypes, existing: existing),
    );
    if (ok == true) ref.invalidate(leaveNoticeRulesProvider);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LeaveNoticeRule rule,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this rule?'),
        content: Text('"${rule.ruleName}" will no longer be enforced.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(leaveRepositoryProvider).deleteNoticeRule(rule.name);
      ref.invalidate(leaveNoticeRulesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rule deleted.')));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              'A leave of up to the given length must be applied this many days '
              'in advance, or the app blocks it. Leave the type blank to cover '
              'every leave type.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
  });
  final LeaveNoticeRule rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rule.ruleName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!rule.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Up to ${_fmt(rule.maxLeaveDays)} day(s)  →  apply '
                '${rule.minNoticeDays} day(s) in advance',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rule.leaveType == null || rule.leaveType!.isEmpty
                    ? 'All leave types'
                    : rule.leaveType!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              if (rule.description != null &&
                  rule.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  rule.description!.trim(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.xxxl),
      child: Column(
        children: [
          Icon(
            Icons.rule_folder_outlined,
            size: 40,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: AppDimens.md),
          Text(
            'No notice rules yet.',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Add a rule to require advance notice for leave. Until then, leave '
            'applies with no notice restriction.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RuleSheet extends ConsumerStatefulWidget {
  const _RuleSheet({required this.leaveTypes, this.existing});
  final List<String> leaveTypes;
  final LeaveNoticeRule? existing;

  @override
  ConsumerState<_RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends ConsumerState<_RuleSheet> {
  late final TextEditingController _name;
  late final TextEditingController _maxDays;
  late final TextEditingController _notice;
  late final TextEditingController _desc;
  late String _leaveType;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.ruleName ?? '');
    _maxDays = TextEditingController(
      text: e != null ? _fmt(e.maxLeaveDays) : '',
    );
    _notice = TextEditingController(
      text: e != null ? e.minNoticeDays.toString() : '',
    );
    _desc = TextEditingController(text: e?.description ?? '');
    _leaveType = e?.leaveType ?? _allTypes;
    _active = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _maxDays.dispose();
    _notice.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final ruleName = _name.text.trim();
    final maxDays = double.tryParse(_maxDays.text.trim());
    final notice = int.tryParse(_notice.text.trim());
    if (ruleName.isEmpty) {
      setState(() => _error = 'Give the rule a name.');
      return;
    }
    if (maxDays == null || maxDays <= 0) {
      setState(() => _error = "'Up to (days)' must be greater than 0.");
      return;
    }
    if (notice == null || notice < 0) {
      setState(() => _error = 'Enter a valid notice (0 or more days).');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(leaveRepositoryProvider)
          .saveNoticeRule(
            name: widget.existing?.name,
            ruleName: ruleName,
            maxLeaveDays: maxDays,
            minNoticeDays: notice,
            isActive: _active,
            leaveType: _leaveType == _allTypes ? null : _leaveType,
            description: _desc.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final editing = widget.existing != null;
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
                editing ? 'Edit rule' : 'Add rule',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppDimens.xl),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Rule name'),
            ),
            const SizedBox(height: AppDimens.lg),
            DropdownButtonFormField<String>(
              initialValue: _leaveType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Leave type'),
              items: [
                const DropdownMenuItem(
                  value: _allTypes,
                  child: Text('All leave types'),
                ),
                for (final t in widget.leaveTypes)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _leaveType = v ?? _allTypes),
            ),
            const SizedBox(height: AppDimens.lg),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _maxDays,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Up to (days)',
                      hintText: 'e.g. 3',
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: TextField(
                    controller: _notice,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Notice (days)',
                      hintText: 'e.g. 7',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              activeThumbColor: AppColors.secondary,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: AppDimens.sm),
            TextField(
              controller: _desc,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppDimens.xl),
            BrandButton(
              label: editing ? 'Save changes' : 'Add rule',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
