import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/location_auto_start.dart';

/// Home-screen banner shown to a Sales user IF the app cannot currently
/// share location - permission revoked, background permission missing,
/// notifications off, etc. Hidden when everything is healthy.
///
/// There is no "turn off" button. Sharing is a policy for the sales team;
/// the only way to opt out is to revoke the OS-level permission (and even
/// then the manager sees "Permission off" on the map).
class LocationStatusBanner extends ConsumerWidget {
  const LocationStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(locationHealthProvider);
    // Hide the banner while loading; also hide if healthy or on error.
    final health =
        healthAsync.maybeWhen(data: (h) => h, orElse: () => LocationHealth.healthy);
    if (health == LocationHealth.healthy) return const SizedBox.shrink();

    final (title, subtitle, cta) = _copy(health);
    return Card(
      color: AppColors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_disabled,
                color: AppColors.onErrorContainer, size: 22),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.onErrorContainer,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onErrorContainer)),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            TextButton(
              onPressed: () async {
                await ph.openAppSettings();
                // When the user comes back, re-check health.
                ref.invalidate(locationHealthProvider);
              },
              child: Text(cta,
                  style: TextStyle(
                      color: AppColors.onErrorContainer,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  (String, String, String) _copy(LocationHealth h) => switch (h) {
        LocationHealth.noPermission => (
            'Location permission needed',
            "Your manager can't see where you are. Grant location permission in Settings.",
            'Open',
          ),
        LocationHealth.noBackground => (
            "Background access needed",
            "Set location to 'Allow all the time' so tracking works with the screen off.",
            'Fix',
          ),
        LocationHealth.noNotification => (
            'Notifications needed',
            'The tracking service requires notification permission.',
            'Grant',
          ),
        LocationHealth.serviceOff => (
            'Location services are off',
            'Turn on Location in the phone Settings to resume sharing.',
            'Open',
          ),
        LocationHealth.healthy => ('', '', ''),
      };
}
