import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/call_detection/application/call_detect_controller.dart';
import 'features/call_detection/application/call_event_bridge.dart';
import 'features/call_detection/presentation/deeplink_listener.dart';
import 'features/call_outcome/presentation/post_call_resume_listener.dart';
import 'features/location_tracking/application/location_auto_start.dart';
import 'features/location_tracking/application/location_bridge.dart';
import 'features/onboarding/presentation/permission_bootstrap.dart';
import 'features/tenant/application/tenant_controller.dart';
import 'features/tenant/domain/tenant.dart';

class TcbPortalApp extends ConsumerWidget {
  const TcbPortalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Apply the active tenant's palette before the rest of the tree builds.
    // The MaterialApp below reads from AppColors during its build, so updates
    // are atomic from the user's point of view: any tenant change triggers a
    // root rebuild here, which re-applies AppColors *before* MaterialApp and
    // every screen reads them.
    final tenant = ref.watch(tenantControllerProvider) ?? Tenant.tcbDefault;
    AppColors.apply(AppPalette.fromTenant(tenant));

    // Start the native↔Flutter bridge for call detection events (D.2.2).
    // The provider's body wires the MethodChannel listener; reading once is
    // enough to keep it alive for the app's lifetime.
    ref.watch(callEventBridgeProvider);

    // Restore the persistent call-detection foreground service on app start
    // (if the user had detection enabled) so calls are caught even after the
    // app was closed. The controller's build() reads the stored flag and
    // starts the native service on Android; a no-op otherwise.
    ref.watch(callDetectControllerProvider);

    // Location tracking bridge — same pattern. Sets up the MethodChannel
    // handler so the native foreground service can push ping updates to Dart.
    ref.watch(locationBridgeProvider);

    // Auto-start location tracking for sales users. Non-sales users get a
    // no-op (and any leftover native service from a previous sales session
    // is stopped). See location_auto_start.dart for the policy.
    ref.watch(locationAutoStartProvider);

    final router = ref.watch(routerProvider);
    return PermissionBootstrap(
      child: DeeplinkListener(
      child: PostCallResumeListener(
      child: MaterialApp.router(
        title: tenant.companyName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // Light-mode only: force the light theme regardless of system setting.
        darkTheme: AppTheme.light,
        themeMode: ThemeMode.light,
        routerConfig: router,
      ),
      ),
      ),
    );
  }
}
