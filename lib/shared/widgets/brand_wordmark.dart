import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../features/tenant/application/tenant_controller.dart';
import '../../features/tenant/domain/tenant.dart';

/// Header brand mark for the login + lock + splash screens and the sidebar.
///
/// Shape:
///  * No tenant resolved yet (fresh install): the app's own logo.
///  * Tenant with a `logoUrl`: that image.
///  * Otherwise a tile in the tenant's colours with the company's initials
///    (e.g. "Acme Traders" → "AT", "ABC Industries" → "ABC").
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
            tenant?.companyName ?? AppConfig.brandName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ],
    );
  }
}

/// Initials for a company name: a leading 2–4 letter acronym is kept as is,
/// otherwise the first letters of the first two words. Anything in
/// brackets ("Local Dev (Laptop)") is ignored.
String companyInitials(String name) {
  final words = name
      .split('(')
      .first
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final first = words.first;
  if (first.length >= 2 &&
      first.length <= 4 &&
      first == first.toUpperCase() &&
      RegExp(r'[A-Z]').hasMatch(first)) {
    return first;
  }
  return words.take(2).map((w) => w[0]).join().toUpperCase();
}

class _Mark extends StatelessWidget {
  const _Mark({required this.size, required this.tenant});
  final double size;
  final Tenant? tenant;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.30);
    final t = tenant;

    if (t == null) {
      return _withShadow(
        radius,
        Image.asset(
          'assets/brand/app_logo.png',
          height: size,
          width: size,
          filterQuality: FilterQuality.medium,
        ),
      );
    }

    final initials = companyInitials(t.companyName);
    final tile = Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * (initials.length > 2 ? 0.28 : 0.36),
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );

    final logo = t.logoUrl;
    if (logo == null || logo.isEmpty) return _withShadow(radius, tile);

    return _withShadow(
      radius,
      ClipRRect(
        borderRadius: radius,
        child: Image.network(
          logo,
          height: size,
          width: size,
          fit: BoxFit.contain,
          // Tunnelled dev servers (ngrok) serve an HTML warning page
          // instead of the image without this header.
          headers: const {'ngrok-skip-browser-warning': '1'},
          // Initials until the first frame arrives, then the logo on white.
          frameBuilder: (context, child, frame, sync) {
            if (frame == null && !sync) return tile;
            return Container(
              height: size,
              width: size,
              color: Colors.white,
              padding: EdgeInsets.all(size * 0.08),
              child: child,
            );
          },
          // Fall back to the initials if the URL is unreachable.
          errorBuilder: (context, error, stack) => tile,
        ),
      ),
    );
  }

  Widget _withShadow(BorderRadius radius, Widget child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      );
}
