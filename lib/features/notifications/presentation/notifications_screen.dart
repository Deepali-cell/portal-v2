import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/notifications_controller.dart';
import '../domain/models.dart';
import 'notification_deep_link.dart';

final _dateFmt = DateFormat('d MMM yyyy · h:mm a');

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            icon: Icon(Icons.done_all, color: AppColors.primary),
            onPressed: () =>
                ref.read(notificationsListProvider.notifier).markAllRead(),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.read(notificationsListProvider.notifier).reload(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.xl),
            child: Text(
              e is ApiException ? e.message : 'Could not load notifications.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 44, color: AppColors.outline),
                    const SizedBox(height: AppDimens.md),
                    Text('No notifications yet.',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                        "When HR mentions you, assigns work, or fires an alert, it'll show up here.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(notificationsListProvider.notifier).reload(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.md, horizontal: AppDimens.screenPadding),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppDimens.sm),
              itemBuilder: (_, i) => _NotificationTile(item: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});
  final NotificationItem item;

  IconData _icon() {
    switch (item.type.toLowerCase()) {
      case 'mention':
        return Icons.alternate_email;
      case 'assignment':
        return Icons.assignment_ind_outlined;
      case 'energy point':
        return Icons.bolt_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _accent() {
    switch (item.type.toLowerCase()) {
      case 'mention':
        return AppColors.secondaryContainer;
      case 'assignment':
        return AppColors.secondary;
      case 'energy point':
        return AppColors.tertiaryFixedDim;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: item.read ? 0 : 1,
      color: item.read
          ? AppColors.surfaceContainerLowest
          : AppColors.secondaryFixed.withValues(alpha: 0.45),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        onTap: () {
          if (!item.read) {
            ref
                .read(notificationsListProvider.notifier)
                .markRead(item.name);
          }
          openNotificationTarget(context, ref, item);
        },
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accent().withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(_icon(), color: _accent(), size: 18),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              item.subject.isEmpty
                                  ? '(no subject)'
                                  : item.subject,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: AppColors.onSurface,
                                      fontWeight: item.read
                                          ? FontWeight.w500
                                          : FontWeight.w700)),
                        ),
                        if (!item.read) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        [
                          item.type,
                          if (item.documentType != null &&
                              item.documentName != null)
                            '${item.documentType} · ${item.documentName}',
                          _dateFmt.format(item.creation.toLocal()),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
