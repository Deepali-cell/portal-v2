import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../features/call_outcome/application/post_call_pending.dart';

/// Small phone-icon button shown on Lead/Deal list rows. Tap → opens device
/// dialer with the resolved number; also registers a "post-call intent" so
/// the post-call outcome sheet auto-opens when the user returns to the app
/// within [kPostCallWindow] (Runo R.1).
///
/// Renders `SizedBox.shrink()` when [phoneNumber] is null/empty so callers
/// can include it unconditionally and let it self-hide.
class QuickCallIconButton extends ConsumerStatefulWidget {
  const QuickCallIconButton({
    super.key,
    required this.phoneNumber,
    required this.referenceDoctype,
    required this.referenceDocname,
    required this.parentLabel,
  });

  final String? phoneNumber;
  final String referenceDoctype;
  final String referenceDocname;
  final String parentLabel;

  @override
  ConsumerState<QuickCallIconButton> createState() =>
      _QuickCallIconButtonState();
}

class _QuickCallIconButtonState extends ConsumerState<QuickCallIconButton> {
  // Guards against rapid double-taps launching two dialer trips.
  bool _launching = false;

  Future<void> _onTap() async {
    if (_launching) return;
    final raw = widget.phoneNumber?.trim();
    if (raw == null || raw.isEmpty) return;
    _launching = true;
    try {
      final uri = Uri(scheme: 'tel', path: raw);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Couldn't open the dialer on this device."),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      // Stash the intent so the lifecycle observer can re-open the sheet.
      ref.read(postCallPendingProvider.notifier).register(
            referenceDoctype: widget.referenceDoctype,
            referenceDocname: widget.referenceDocname,
            parentLabel: widget.parentLabel,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Couldn't start the call."),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      // Small debounce so the button doesn't re-fire while the dialer launches.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _launching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.phoneNumber?.trim();
    if (raw == null || raw.isEmpty) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Call',
      icon: Icon(Icons.call_outlined, color: AppColors.primary, size: 20),
      onPressed: _onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}
