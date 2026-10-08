import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/router/nav_history.dart';
import '../domain/module_flow.dart';

/// An interactive, vertical flow diagram for a module dashboard.
///
/// Each [FlowStage] renders as a tappable node showing a live count and an
/// optional value; consecutive nodes are joined by a connector arrow so the
/// whole thing reads as a process (e.g. Lead → Opportunity → Customer).
/// Tapping a node with a `route` deep-links to that stage's list screen.
class FlowDiagram extends StatelessWidget {
  const FlowDiagram({super.key, required this.stages});

  final List<FlowStage> stages;

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) return const SizedBox.shrink();
    final children = <Widget>[];
    for (var i = 0; i < stages.length; i++) {
      children.add(_FlowNode(stage: stages[i], index: i, total: stages.length));
      if (i != stages.length - 1) {
        children.add(_FlowConnector(hint: stages[i].hint));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _FlowNode extends StatelessWidget {
  const _FlowNode({
    required this.stage,
    required this.index,
    required this.total,
  });
  final FlowStage stage;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tappable = stage.route != null;
    final color = stage.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        onTap: tappable ? () => AppNav.go(context, stage.route!) : null,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Coloured accent + step number stripe.
              Container(
                width: 6,
                height: 66,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withValues(alpha: 0.55)],
                  ),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppDimens.radiusXl),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.md - 2),
              _IconChip(icon: stage.icon, color: color),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stage.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      stage.value > 0
                          ? moneyShort(stage.value)
                          : 'Step ${index + 1} of $total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              _CountPill(count: stage.count, color: color),
              if (tappable)
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: AppDimens.sm),
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.onSurfaceVariant,
                  ),
                )
              else
                const SizedBox(width: AppDimens.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 999 ? '999+' : '$count',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }
}

/// The arrow that joins two stages, with an optional conversion hint.
class _FlowConnector extends StatelessWidget {
  const _FlowConnector({this.hint});
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 30),
          Column(
            children: [
              Container(width: 2, height: 10, color: AppColors.outlineVariant),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(width: AppDimens.sm),
            Text(
              hint!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Maps the backend's icon-name strings to Material icons for the Sales cycle.
IconData flowIconFor(String key) {
  switch (key) {
    case 'storefront':
      return Icons.storefront_outlined;
    case 'description':
      return Icons.description_outlined;
    case 'point_of_sale':
      return Icons.point_of_sale_outlined;
    case 'local_shipping':
      return Icons.local_shipping_outlined;
    case 'playlist_add':
      return Icons.playlist_add_outlined;
    case 'request_quote':
      return Icons.request_quote_outlined;
    case 'shopping_cart':
      return Icons.shopping_cart_outlined;
    case 'payments':
      return Icons.payments_outlined;
    case 'receipt':
      return Icons.receipt_long_outlined;
    case 'person_search':
      return Icons.person_search_outlined;
    case 'handshake':
      return Icons.handshake_outlined;
    default:
      return Icons.circle_outlined;
  }
}

/// Parses a "#RRGGBB" backend colour into a Flutter [Color].
Color flowColorFor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  final n = int.tryParse(cleaned, radix: 16);
  if (n == null) return AppColors.primary;
  return Color(cleaned.length == 6 ? (0xFF000000 | n) : n);
}
