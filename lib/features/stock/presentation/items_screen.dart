import 'package:flutter/material.dart';
import '../../../core/router/nav_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import '../application/stock_controller.dart';
import '../domain/models.dart';

/// Items master list. Visible only when the user can read Item (nav is gated
/// by the `stock_item` capability). The "Add" button follows the ERP-native
/// create permission via `profile.canDo('stock_item','create')`.
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  @override
  void initState() {
    super.initState();
    // `screen_perms` (incl. create) is only refetched at login/app-start; if
    // that background fetch ever failed, the app keeps showing a stale
    // profile until logout/login. Re-fetch here so a permission granted
    // after login (e.g. from the Administrator screen) takes effect as soon
    // as the user opens this screen, without needing to re-login.
    Future.microtask(
      () => ref.read(authControllerProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(itemsControllerProvider);
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    final canCreate = profile?.canDo('stock_item', 'create') ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Items'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.read(itemsControllerProvider.notifier).reload(),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.stockItemCreate),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search items…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (q) =>
                  ref.read(itemsControllerProvider.notifier).setSearch(q),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: '$e',
                onRetry: () =>
                    ref.read(itemsControllerProvider.notifier).reload(),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No items found'))
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(itemsControllerProvider.notifier).reload(),
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => _ItemTile(item: items[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryContainer,
        child: Text(
          item.itemCode.isNotEmpty ? item.itemCode[0].toUpperCase() : '?',
          style: TextStyle(color: AppColors.onPrimaryContainer),
        ),
      ),
      title: Text(item.itemName.isEmpty ? item.itemCode : item.itemName),
      subtitle: Text(
        [item.itemCode, if (item.itemGroup != null) item.itemGroup]
            .whereType<String>()
            .join(' • '),
      ),
      trailing: item.disabled
          ? const Chip(label: Text('Disabled'), visualDensity: VisualDensity.compact)
          : Text(item.stockUom ?? ''),
      onTap: () => context.push(Routes.stockItemDetail, extra: item.name),
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
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: AppDimens.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.md),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
