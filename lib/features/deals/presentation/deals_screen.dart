import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/quick_call_icon_button.dart';
import '../application/deal_controller.dart';
import '../domain/models.dart';
import 'probability_pill.dart';

class DealsScreen extends ConsumerWidget {
  const DealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dealsControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Opportunities'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.read(dealsControllerProvider.notifier).reload(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Err(
          msg: e is ApiException ? e.message : 'Something unexpected happened. Please try again.',
          onRetry: () => ref.read(dealsControllerProvider.notifier).reload(),
        ),
        data: (ctx) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(dealsControllerProvider.notifier).reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.md,
                  AppDimens.screenPadding,
                  AppDimens.xl),
              children: [
                _Header(
                  title: 'Opportunities',
                  subtitle:
                      'Track active opportunities and pipeline value.',
                ),
                const SizedBox(height: AppDimens.lg),
                if (ctx.deals.isEmpty)
                  const _EmptyCard(
                    icon: Icons.handshake_outlined,
                    text:
                        'No opportunities yet. Convert a lead to start one.',
                  )
                else ...[
                  _PipelineCard(deals: ctx.deals),
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
                              AppDimens.sm),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('All Opportunities',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600)),
                              ),
                              Text('${ctx.deals.length}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                          color:
                                              AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        for (var i = 0; i < ctx.deals.length; i++) ...[
                          if (i > 0)
                            Divider(
                                height: 1,
                                indent: 64,
                                color: AppColors.outlineVariant),
                          _DealRow(
                            deal: ctx.deals[i],
                            onTap: () => context.push(Routes.dealDetail,
                                extra: ctx.deals[i].name),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.deals});
  final List<Deal> deals;

  @override
  Widget build(BuildContext context) {
    final currency = deals.first.currency;
    final total = deals.fold<double>(
        0,
        (s, d) =>
            s + (d.dealValue > 0 ? d.dealValue : d.annualRevenue));
    final weighted = deals.fold<double>(0, (s, d) {
      final v = d.dealValue > 0 ? d.dealValue : d.annualRevenue;
      final p = (d.probability ?? 0) / 100;
      return s + v * p;
    });
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pipeline',
              style: TextStyle(
                  color: AppColors.primaryFixedDim, fontSize: 12)),
          const SizedBox(height: 4),
          Text(money(total, currency),
              style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: AppDimens.md),
          Row(children: [
            Expanded(
                child: _kv(context, 'Active deals', '${deals.length}')),
            Container(
                width: 1,
                height: 28,
                color: AppColors.primaryFixedDim.withValues(alpha: 0.25)),
            Expanded(
                child: _kv(context, 'Weighted', money(weighted, currency))),
          ]),
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
          Text(k,
              style:
                  TextStyle(color: AppColors.primaryFixedDim, fontSize: 11)),
          const SizedBox(height: 2),
          Text(v,
              style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DealRow extends StatelessWidget {
  const _DealRow({required this.deal, required this.onTap});
  final Deal deal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = deal.dealValue > 0 ? deal.dealValue : deal.annualRevenue;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondaryFixed,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.handshake_outlined,
                  color: AppColors.onSecondaryFixed, size: 20),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deal.title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (value > 0) ...[
                    const SizedBox(height: 2),
                    Text(money(value, deal.currency),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DealStatusChip(status: deal.status),
                if (deal.probability != null) ...[
                  const SizedBox(height: 4),
                  ProbabilityPill(percent: deal.probability),
                ],
              ],
            ),
            QuickCallIconButton(
              phoneNumber: deal.mobileNo ?? deal.phone,
              referenceDoctype: 'Opportunity',
              referenceDocname: deal.name,
              parentLabel: deal.title,
            ),
            Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

class _DealStatusChip extends StatelessWidget {
  const _DealStatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    final s = status.toLowerCase();
    if (s.contains('won')) {
      bg = AppColors.tertiaryFixed;
      fg = AppColors.onTertiaryFixedVariant;
    } else if (s.contains('lost')) {
      bg = AppColors.errorContainer;
      fg = AppColors.onErrorContainer;
    } else if (s.contains('qualif') || s.contains('demo') || s.contains('proposal')) {
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
      child: Text(status,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w600, fontSize: 11)),
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
                child: Text(text,
                    style: Theme.of(context).textTheme.bodyMedium)),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: AppDimens.md),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}
