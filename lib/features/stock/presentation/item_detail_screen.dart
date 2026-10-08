import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/ui/app_message_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../../records/data/records_repository.dart';
import '../application/stock_controller.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(itemDetailProvider(name));
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    final canEdit = profile?.canDo('stock_item', 'write') ?? false;
    final canDelete = profile?.canDo('stock_item', 'delete') ?? false;
    final loadedItem = async.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Item'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(itemDetailProvider(name)),
          ),
          if (canEdit && loadedItem != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push(Routes.stockItemEdit, extra: loadedItem),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.lg),
            child: Text(friendlyMessageFor(e).message,
              textAlign: TextAlign.center),
          ),
        ),
        data: (item) => ListView(
          padding: const EdgeInsets.all(AppDimens.md),
          children: [
            Text(item.itemName.isEmpty ? item.itemCode : item.itemName,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppDimens.xs),
            Text(item.itemCode,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppDimens.lg),
            _row('Item Group', item.itemGroup),
            _row('Stock UOM', item.stockUom),
            _row('Stock Item', item.isStockItem ? 'Yes' : 'No'),
            _row('Sales Item', item.isSalesItem ? 'Yes' : 'No'),
            _row('Purchase Item', item.isPurchaseItem ? 'Yes' : 'No'),
            _row('Valuation Rate', item.valuationRate?.toString()),
            _row('Standard Rate', item.standardRate?.toString()),
            _row('HSN Code', item.gstHsnCode),
            if ((item.description ?? '').isNotEmpty) ...[
              const SizedBox(height: AppDimens.md),
              Text('Description',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppDimens.xs),
              Text(item.description!),
            ],
            if (canDelete) ...[
              const SizedBox(height: AppDimens.lg),
              OutlinedButton.icon(
                onPressed: () => _confirmAndDelete(context, ref),
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                label: Text('Delete',
                    style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this item?'),
        content: const Text(
            'This item will be permanently deleted. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete it'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(recordsRepositoryProvider).deleteDoc('Item', name);
      messenger.showSnackBar(
          const SnackBar(content: Text('Deleted successfully.')));
      router.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(friendlyMessageFor(e).message,
            maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
