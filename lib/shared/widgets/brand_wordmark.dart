import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../features/tenant/application/tenant_controller.dart';
import '../../features/tenant/domain/tenant.dart';

/// Header brand mark for the login + lock + splash screens.
///
/// Shape:
///  * If the active tenant has a `logoUrl`, render that image.
///  * Else render a coloured tile with the tenant's company-ID monogram
///    (e.g. "DEMO" → "DEM"). Falls back to "TCB" when no tenant is yet
///    resolved (cold start, fresh install).
///
/// The tile colours come from the active theme so each tenant's mark sits
/// in their own brand colour.
class BrandWordmark extends ConsumerWidget {
  const BrandWordmark({super.key, this.size = 64, this.showLabel = true});

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantControllerProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Mark(size: size, tenant: tenant),
        if (showLabel) ...[
          const SizedBox(height: AppDimens.md),
          Text(
            'Employee Portal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.size, required this.tenant});
  final double size;
  final Tenant? tenant;

  String _monogram() {
    final id = tenant?.companyId.trim();
    if (id == null || id.isEmpty) return 'TCB';
    final clean = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (clean.isEmpty) return 'TCB';
    return clean.substring(0, clean.length >= 3 ? 3 : clean.length).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final logo = tenant?.logoUrl;
    final radius = BorderRadius.circular(size * 0.30);
    final tile = Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _monogram(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.28,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );

    if (logo == null || logo.isEmpty) return tile;

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        logo,
        height: size,
        width: size,
        fit: BoxFit.cover,
        // Show the monogram while the image is downloading.
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return tile;
        },
        // Fall back to the monogram if the URL is unreachable.
        errorBuilder: (context, error, stack) => tile,
      ),
    );
  }
}
