import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../role_dashboards/data/role_dashboards_repository.dart';
import '../../role_dashboards/domain/models.dart';
import 'module_dashboard_scaffold.dart';

/// Finance module dashboard — a whole-business money overview: revenue vs cost
/// (profit / loss), cash in vs out, what's owed to and by the company, and the
/// most overdue invoices. Reuses the accounts summary endpoint.
class FinanceDashboardScreen extends ConsumerWidget {
  const FinanceDashboardScreen({super.key});

  static const _green = Color(0xFF15803D);
  static const _red = Color(0xFFB42318);
  static const _blue = Color(0xFF2563EB);
  static const _amber = Color(0xFFB54708);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(accountsPeriodProvider);
    final async = ref.watch(accountsSummaryProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Finance'),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(accountsSummaryProvider);
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
              const ModuleDashboardHeader(
                title: 'Finance',
                subtitle: 'Money in, money out & profit at a glance',
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: AppDimens.md),
              _PeriodChips(active: period),
              const SizedBox(height: AppDimens.md),
              async.when(
                loading: () => const FlowSkeleton(rows: 4),
                error: (e, _) => FlowLoadError(
                  message: e is ApiException
                      ? e.message
                      : "Couldn't load finance. Try again.",
                ),
                data: (s) => _Body(summary: s),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodChips extends ConsumerWidget {
  const _PeriodChips({required this.active});
  final RolePeriod active;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        for (final p in RolePeriod.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(accountsPeriodProvider.notifier).set(p),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p == active
                      ? AppColors.primary
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p == active
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary});
  final AccountsSummary summary;

  @override
  Widget build(BuildContext context) {
    final cur = summary.currency;
    final profit = summary.netProfit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Profit / Loss headline.
        Card(
          color: AppColors.primary,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profit >= 0 ? 'Net profit' : 'Net loss',
                  style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      profit >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: AppColors.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        money(profit.abs(), cur),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.md),
                Row(
                  children: [
                    Expanded(
                      child: _InlineStat(
                        label: 'Income',
                        value: moneyShort(
                          summary.incomeInPeriod,
                          currencyCode: cur,
                        ),
                        onDark: true,
                      ),
                    ),
                    Expanded(
                      child: _InlineStat(
                        label: 'Expense',
                        value: moneyShort(
                          summary.expenseInPeriod,
                          currencyCode: cur,
                        ),
                        onDark: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        const DashboardSectionTitle(
          'Cash flow',
          subtitle: 'Actual money moved this period',
        ),
        const SizedBox(height: AppDimens.sm),
        Row(
          children: [
            Expanded(
              child: _MoneyCard(
                label: 'Money in',
                value: moneyShort(summary.receiptsInPeriod, currencyCode: cur),
                icon: Icons.south_west,
                color: FinanceDashboardScreen._green,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _MoneyCard(
                label: 'Money out',
                value: moneyShort(summary.paymentsInPeriod, currencyCode: cur),
                icon: Icons.north_east,
                color: FinanceDashboardScreen._red,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _MoneyCard(
                label: 'Net cash',
                value: moneyShort(summary.netCash, currencyCode: cur),
                icon: Icons.account_balance,
                color: summary.netCash >= 0
                    ? FinanceDashboardScreen._green
                    : FinanceDashboardScreen._red,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.lg),
        const DashboardSectionTitle(
          'Outstanding',
          subtitle: 'What is owed to and by the company',
        ),
        const SizedBox(height: AppDimens.sm),
        Row(
          children: [
            Expanded(
              child: _MoneyCard(
                label: 'Receivable',
                value: moneyShort(
                  summary.receivableOutstanding,
                  currencyCode: cur,
                ),
                icon: Icons.call_received,
                color: FinanceDashboardScreen._blue,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _MoneyCard(
                label: 'Payable',
                value: moneyShort(
                  summary.payableOutstanding,
                  currencyCode: cur,
                ),
                icon: Icons.call_made,
                color: FinanceDashboardScreen._amber,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _MoneyCard(
                label: 'Overdue',
                value: '${summary.overdueInvoices}',
                icon: Icons.warning_amber_rounded,
                color: FinanceDashboardScreen._red,
              ),
            ),
          ],
        ),
        if (summary.topOverdue.isNotEmpty) ...[
          const SizedBox(height: AppDimens.lg),
          const DashboardSectionTitle('Most overdue'),
          const SizedBox(height: AppDimens.sm),
          for (final o in summary.topOverdue)
            _OverdueRow(item: o, currency: cur),
        ],
      ],
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.label,
    required this.value,
    this.onDark = false,
  });
  final String label;
  final String value;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final fg = onDark ? AppColors.onPrimary : AppColors.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: fg,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onDark
                ? AppColors.onPrimary.withValues(alpha: 0.8)
                : AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _OverdueRow extends StatelessWidget {
  const _OverdueRow({required this.item, required this.currency});
  final AccountsOverdue item;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final tint = item.isSales
        ? FinanceDashboardScreen._blue
        : FinanceDashboardScreen._amber;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: tint.withValues(alpha: 0.12),
              child: Icon(
                item.isSales ? Icons.person_outline : Icons.store_outlined,
                size: 18,
                color: tint,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.party.isEmpty ? item.name : item.party,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${item.isSales ? "Receivable" : "Payable"} · '
                    '${item.daysOverdue}d overdue',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              moneyShort(item.outstanding, currencyCode: currency),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: FinanceDashboardScreen._red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
