import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../../../shared/widgets/followup_gap_badge.dart';
import '../../../shared/widgets/quick_call_icon_button.dart';
import '../../phone_lookup/presentation/phone_lookup_sheet.dart';
import '../application/lead_controller.dart';
import '../application/leads_view_prefs.dart';
import '../domain/models.dart';
import '../../home/presentation/nav_destinations.dart';
import '../../auth/application/auth_controller.dart';

class LeadsScreen extends ConsumerWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leadsControllerProvider);
    final prefs = ref.watch(leadsViewPrefsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Leads'),
        actions: [
          if (screenOn(ref.watch(authControllerProvider).profile, 'crm.kanban'))
            IconButton(
              tooltip: 'Board view',
              icon: Icon(Icons.view_kanban_outlined, color: AppColors.primary),
              onPressed: () => context.push(Routes.leadKanban),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.read(leadsControllerProvider.notifier).reload(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPhoneLookupSheet(context),
        icon: const Icon(Icons.phone_outlined),
        label: const Text('Find by phone'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Err(
          msg: e is ApiException
              ? e.message
              : 'Something unexpected happened. Please try again.',
          onRetry: () => ref.read(leadsControllerProvider.notifier).reload(),
        ),
        data: (ctx) {
          // Bucket drill-in from the Home dashboard sets a pending status
          // filter — apply it once, then clear so subsequent visits show
          // the full list again.
          final pendingStatus = ref.watch(pendingLeadStatusFilterProvider);
          final filteredLeads = pendingStatus == null
              ? ctx.leads
              : ctx.leads
                    .where(
                      (l) =>
                          l.status.toLowerCase() == pendingStatus.toLowerCase(),
                    )
                    .toList();
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(leadsControllerProvider.notifier).reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.md,
                AppDimens.screenPadding,
                AppDimens.xl,
              ),
              children: [
                _Header(
                  title: 'Leads',
                  subtitle:
                      'Capture new prospects and move them through your pipeline.',
                  cta: 'New Lead',
                  onPressed: () => _openCreate(context, ctx),
                ),
                const SizedBox(height: AppDimens.lg),
                if (pendingStatus != null) ...[
                  _FilterChip(
                    status: pendingStatus,
                    total: filteredLeads.length,
                    onClear: () => ref
                        .read(pendingLeadStatusFilterProvider.notifier)
                        .clear(),
                  ),
                  const SizedBox(height: AppDimens.md),
                ],
                if (filteredLeads.isEmpty)
                  _EmptyCard(
                    icon: Icons.person_search_outlined,
                    text: pendingStatus == null
                        ? 'No leads yet. Tap "New Lead" to add one.'
                        : 'No leads in status "$pendingStatus".',
                  )
                else
                  Builder(
                    builder: (context) {
                      final sortedLeads = applyLeadSort(
                        filteredLeads,
                        prefs.sort,
                      );
                      return Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _LeadsToolbar(
                              count: sortedLeads.length,
                              prefs: prefs,
                            ),
                            for (var i = 0; i < sortedLeads.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  indent: prefs.density == LeadDensity.compact
                                      ? 56
                                      : 64,
                                  color: AppColors.outlineVariant,
                                ),
                              _LeadRow(
                                lead: sortedLeads[i],
                                density: prefs.density,
                                onTap: () => context.push(
                                  Routes.leadDetail,
                                  extra: sortedLeads[i].name,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, LeadsContext ctx) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      builder: (_) => _NewLeadSheet(statuses: ctx.statuses),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lead created.')));
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

class _LeadsToolbar extends ConsumerWidget {
  const _LeadsToolbar({required this.count, required this.prefs});
  final int count;
  final LeadsViewPrefs prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(leadsViewPrefsProvider.notifier);
    final compact = prefs.density == LeadDensity.compact;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.md,
        AppDimens.md,
        AppDimens.sm,
        AppDimens.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'My Leads',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          PopupMenuButton<LeadSort>(
            tooltip: 'Sort',
            initialValue: prefs.sort,
            onSelected: notifier.setSort,
            position: PopupMenuPosition.under,
            itemBuilder: (_) => [
              for (final s in LeadSort.values)
                PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Icon(
                        s == prefs.sort
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 16,
                        color: s == prefs.sort
                            ? AppColors.primary
                            : AppColors.outline,
                      ),
                      const SizedBox(width: 10),
                      Text(s.label),
                    ],
                  ),
                ),
            ],
            icon: Icon(Icons.sort, size: 20, color: AppColors.primary),
          ),
          IconButton(
            tooltip: compact ? 'Comfortable density' : 'Compact density',
            icon: Icon(
              compact ? Icons.unfold_more : Icons.unfold_less,
              size: 20,
              color: AppColors.primary,
            ),
            onPressed: () => notifier.setDensity(
              compact ? LeadDensity.comfortable : LeadDensity.compact,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _LeadRow extends StatelessWidget {
  const _LeadRow({
    required this.lead,
    required this.onTap,
    this.density = LeadDensity.comfortable,
  });
  final Lead lead;
  final VoidCallback onTap;
  final LeadDensity density;
  bool get _compact => density == LeadDensity.compact;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: _compact ? AppDimens.xs : AppDimens.md,
        ),
        child: Row(
          children: [
            Container(
              width: _compact ? 32 : 40,
              height: _compact ? 32 : 40,
              decoration: BoxDecoration(
                color: AppColors.secondaryFixed,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
              alignment: Alignment.center,
              child: Text(
                lead.initials,
                style: TextStyle(
                  color: AppColors.onSecondaryFixed,
                  fontWeight: FontWeight.w700,
                  fontSize: _compact ? 11 : 13,
                ),
              ),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!_compact &&
                      lead.organization != null &&
                      lead.organization!.isNotEmpty &&
                      lead.organization != lead.title)
                    Text(
                      lead.organization!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (!_compact &&
                      lead.daysSinceContact != null &&
                      lead.daysSinceContact! >= 1) ...[
                    const SizedBox(height: 4),
                    FollowupGapBadge(days: lead.daysSinceContact!),
                  ],
                ],
              ),
            ),
            _LeadStatusChip(status: lead.status),
            QuickCallIconButton(
              phoneNumber: lead.mobileNo ?? lead.phone,
              referenceDoctype: 'Lead',
              referenceDocname: lead.name,
              parentLabel: lead.title,
            ),
            Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

/// Small colour-coded chip showing how many days have passed since the
/// last meaningful contact with this lead. Hidden when the lead was
/// touched today (no gap to flag).
class _LeadStatusChip extends StatelessWidget {
  const _LeadStatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    final s = status.toLowerCase();
    if (s.contains('qualified') || s.contains('converted')) {
      bg = AppColors.tertiaryFixed;
      fg = AppColors.onTertiaryFixedVariant;
    } else if (s.contains('lost') || s.contains('junk')) {
      bg = AppColors.errorContainer;
      fg = AppColors.onErrorContainer;
    } else if (s.contains('open') ||
        s.contains('new') ||
        s.contains('contact') ||
        s.contains('progress')) {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
    } else {
      bg = AppColors.secondaryFixed;
      fg = AppColors.onSecondaryFixedVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

/// Header chip shown when the user landed on Leads via a dashboard
/// bucket tap. Tap the "x" to clear the filter and show the full list.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.status,
    required this.total,
    required this.onClear,
  });
  final String status;
  final int total;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Status: $status  ·  $total ${total == 1 ? "lead" : "leads"}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: AppColors.primary),
            ),
          ),
        ],
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

class _NewLeadSheet extends ConsumerStatefulWidget {
  const _NewLeadSheet({required this.statuses});
  final List<String> statuses;
  @override
  ConsumerState<_NewLeadSheet> createState() => _NewLeadSheetState();
}

class _NewLeadSheetState extends ConsumerState<_NewLeadSheet> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _org = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  late String? _status = widget.statuses.isNotEmpty
      ? widget.statuses.first
      : null;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_first, _last, _org, _email, _mobile]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_first.text.trim().isEmpty) {
      setState(() => _error = 'First name is required.');
      return;
    }
    if (_mobile.text.trim().isEmpty) {
      setState(
        () =>
            _error = 'Mobile number is required. Every lead must be reachable.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(leadsControllerProvider.notifier).create({
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        'organization': _org.text.trim(),
        'email': _email.text.trim(),
        'mobile_no': _mobile.text.trim(),
        if (_status != null) 'status': _status,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
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
                'New lead',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppDimens.xl),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _first,
                    decoration: const InputDecoration(
                      labelText: 'First name *',
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: TextField(
                    controller: _last,
                    decoration: const InputDecoration(labelText: 'Last name'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _org,
              decoration: const InputDecoration(labelText: 'Organization'),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile *'),
            ),
            const SizedBox(height: AppDimens.lg),
            DropdownButtonFormField<String>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: widget.statuses
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v),
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
              label: 'Create lead',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Err extends StatelessWidget {
  const _Err({required this.msg, required this.onRetry});
  final String msg;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppDimens.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.error),
          const SizedBox(height: AppDimens.md),
          Text(msg, textAlign: TextAlign.center),
          const SizedBox(height: AppDimens.lg),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
