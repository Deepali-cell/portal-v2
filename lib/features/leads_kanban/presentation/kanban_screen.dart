import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../home/presentation/app_shell.dart';
import '../../leads/application/lead_controller.dart';
import '../../leads/domain/models.dart';

/// SalesMax-style drag-drop Lead Kanban board. Each CRM Lead Status is a
/// vertical column; cards drag between columns to update the status via
/// the existing leads.update API.
class LeadKanbanScreen extends ConsumerStatefulWidget {
  const LeadKanbanScreen({super.key});
  @override
  ConsumerState<LeadKanbanScreen> createState() => _LeadKanbanScreenState();
}

class _LeadKanbanScreenState extends ConsumerState<LeadKanbanScreen> {
  // Optimistic-update overlay: lead.name -> overridden status until the API
  // confirms / fails. Failure restores the original status + snackbar.
  final Map<String, String> _optimistic = {};
  String? _dragHovering;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leadsControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Lead board'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.read(leadsControllerProvider.notifier).reload(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is ApiException
              ? e.message
              : "Couldn't load leads."),
        ),
        data: (ctx) => _buildBoard(context, ctx),
      ),
      bottomNavigationBar: const PersistentBottomNav(),
    );
  }

  Widget _buildBoard(BuildContext context, LeadsContext ctx) {
    // Apply optimistic overrides so cards visually live in their dragged column
    // even before the API confirms.
    final effective = ctx.leads.map((l) {
      final override = _optimistic[l.name];
      return override == null ? l : _withStatus(l, override);
    }).toList();

    final grouped = <String, List<Lead>>{};
    for (final s in ctx.statuses) {
      grouped[s] = [];
    }
    for (final l in effective) {
      grouped.putIfAbsent(l.status, () => []).add(l);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(leadsControllerProvider.notifier).reload(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.sm, vertical: AppDimens.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final status
                in (ctx.statuses.isEmpty ? grouped.keys.toList() : ctx.statuses))
              _Column(
                status: status,
                leads: grouped[status] ?? const [],
                hovering: _dragHovering == status,
                onWillAccept: (lead) {
                  setState(() => _dragHovering = status);
                  return lead != null && lead.status != status;
                },
                onLeave: () => setState(() => _dragHovering = null),
                onAccept: (lead) => _onDrop(lead, status),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDrop(Lead lead, String newStatus) async {
    if (lead.status == newStatus) return;
    setState(() {
      _optimistic[lead.name] = newStatus;
      _dragHovering = null;
    });
    try {
      final repo = ref.read(leadRepositoryProvider);
      await repo.update(lead.name, {'status': newStatus});
      // Reload so the data + counts refresh from source of truth
      await ref.read(leadsControllerProvider.notifier).reload();
      setState(() => _optimistic.remove(lead.name));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${lead.title} → $newStatus"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      setState(() => _optimistic.remove(lead.name));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiException
            ? "Couldn't move: ${e.message}"
            : "Couldn't move ${lead.title}. Try again."),
        backgroundColor: AppColors.errorContainer,
        behavior: SnackBarBehavior.floating,
      ));
      // Snap-back: a reload restores the truthful status.
      await ref.read(leadsControllerProvider.notifier).reload();
    }
  }

  /// Returns a copy of [Lead] with a different status.
  Lead _withStatus(Lead lead, String newStatus) =>
      lead.copyWith(status: newStatus);
}

class _Column extends StatelessWidget {
  const _Column({
    required this.status,
    required this.leads,
    required this.hovering,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
  });

  final String status;
  final List<Lead> leads;
  final bool hovering;
  final bool Function(Lead?) onWillAccept;
  final VoidCallback onLeave;
  final void Function(Lead) onAccept;

  @override
  Widget build(BuildContext context) {
    final total = leads.fold<num>(0, (sum, l) => sum + (l.annualRevenue ?? 0));
    return DragTarget<Lead>(
      onWillAcceptWithDetails: (d) => onWillAccept(d.data),
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidates, rejects) {
        return Container(
          width: 260,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: hovering
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: hovering
                  ? AppColors.primary
                  : AppColors.outlineVariant,
              width: hovering ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ColumnHeader(
                  status: status,
                  count: leads.length,
                  totalValue: total.toDouble()),
              const Divider(height: 1),
              Expanded(
                child: leads.isEmpty
                    ? _EmptySlot()
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: leads.length,
                        itemBuilder: (_, i) => _LeadCard(lead: leads[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.status,
    required this.count,
    required this.totalValue,
  });
  final String status;
  final int count;
  final double totalValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                status,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$count',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          if (totalValue > 0) ...[
            const SizedBox(height: 2),
            Text(moneyShort(totalValue),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead});
  final Lead lead;

  @override
  Widget build(BuildContext context) {
    final isStale =
        (lead.daysSinceContact ?? 0) >= 14;
    final card = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                lead.title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isStale)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  shape: BoxShape.circle,
                ),
              ),
          ]),
          if (lead.organization != null && lead.organization!.isNotEmpty)
            Text(lead.organization!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Row(children: [
            if ((lead.annualRevenue ?? 0) > 0)
              Text(moneyShort(lead.annualRevenue ?? 0),
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            const Spacer(),
            if (lead.leadOwner != null && lead.leadOwner!.isNotEmpty)
              _OwnerChip(owner: lead.leadOwner!),
          ]),
        ],
      ),
    );

    return LongPressDraggable<Lead>(
      data: lead,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 230, child: Opacity(opacity: 0.9, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(Routes.leadDetail, extra: lead.name),
        child: card,
      ),
    );
  }
}

class _OwnerChip extends StatelessWidget {
  const _OwnerChip({required this.owner});
  final String owner;

  String _initials() {
    final parts = owner.split('@').first.split(RegExp(r'[._]'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.secondaryFixed,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(_initials(),
          style: TextStyle(
              color: AppColors.onSecondaryFixed,
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No leads',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.outline),
        ),
      ),
    );
  }
}
