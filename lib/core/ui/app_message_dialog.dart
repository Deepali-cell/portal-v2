import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// Tone of a user-facing message dialog. Drives the icon and accent colour.
enum AppMessageKind { success, info, warning, error }

/// A single friendly message: what to show the user, in plain language.
class AppMessage {
  const AppMessage(this.kind, this.title, this.message);
  final AppMessageKind kind;
  final String title;
  final String message;
}

/// Shows a centered, attractive message dialog instead of a raw black
/// SnackBar. Use for anything the user must read and acknowledge - success
/// confirmations and, especially, blocking errors like "complete the job
/// cards first".
///
/// Prefer [showFriendlyError] for caught exceptions: it translates ERPNext's
/// technical wording into a simple, actionable message first.
Future<void> showAppMessage(
  BuildContext context, {
  required AppMessageKind kind,
  required String title,
  required String message,
  String buttonLabel = 'Got it',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _AppMessageDialog(
      kind: kind,
      title: title,
      message: message,
      buttonLabel: buttonLabel,
    ),
  );
}

/// Convenience: translate a caught error into a friendly dialog and show it.
Future<void> showFriendlyError(BuildContext context, Object error) {
  final m = friendlyMessageFor(error);
  return showAppMessage(context,
      kind: m.kind, title: m.title, message: m.message);
}

/// Maps a raw error (usually an [ApiException] whose `toString()` is the
/// server text) to a short, human message. Falls back to the raw text so we
/// never hide information, just present it better.
AppMessage friendlyMessageFor(Object error) {
  final raw = error.toString();
  final t = raw.toLowerCase();

  // Manufacture attempted before job-card operations are done.
  if (t.contains('operation') &&
          (t.contains('not complete') || t.contains('incomplete')) ||
      t.contains('operationsnotcomplete') ||
      (t.contains('job card') && t.contains('complete'))) {
    return const AppMessage(
      AppMessageKind.warning,
      'Finish the job cards first',
      'This work order still has operations to do. Open each job card, '
          'complete its work, and submit it. Once all job cards are done, '
          'you can record the Manufacture entry.',
    );
  }

  // Job card submitted before the completed quantity was recorded.
  if (t.contains('qty to manufacture') ||
      (t.contains('completed qty') && t.contains('add up')) ||
      (t.contains('pending qty') && t.contains('manufacture'))) {
    return const AppMessage(
      AppMessageKind.warning,
      'Record the work first',
      'Tap Stop to record the completed quantity, then submit the job '
          'card.',
    );
  }

  // Nothing left to transfer.
  if (t.contains('already') && t.contains('transferred')) {
    return const AppMessage(
      AppMessageKind.info,
      'Already transferred',
      'The materials for this work order have already been moved to the '
          'work-in-progress warehouse. You can go ahead and manufacture.',
    );
  }

  // Not enough stock on hand.
  if (t.contains('negative stock') ||
      t.contains('insufficient stock') ||
      (t.contains('stock') && t.contains('not enough')) ||
      t.contains('is required') && t.contains('available')) {
    return const AppMessage(
      AppMessageKind.warning,
      'Not enough stock',
      'There is not enough raw material in stock for this step. Create a '
          'Material Request to bring in the shortfall, then try again.',
    );
  }

  // Permission problems.
  if (t.contains('permission') || t.contains('not permitted')) {
    return const AppMessage(
      AppMessageKind.warning,
      'Not allowed',
      "You don't have permission to do this. Ask an administrator if you "
          'think you should.',
    );
  }

  // Session expired.
  if (t.contains('authentication') || t.contains('sign in again')) {
    return const AppMessage(
      AppMessageKind.warning,
      'Session expired',
      'Your session has ended. Please sign in again and retry.',
    );
  }

  // Fallback: show the cleaned server text as-is.
  return AppMessage(AppMessageKind.error, "Couldn't complete", raw);
}

class _AppMessageDialog extends StatelessWidget {
  const _AppMessageDialog({
    required this.kind,
    required this.title,
    required this.message,
    required this.buttonLabel,
  });

  final AppMessageKind kind;
  final String title;
  final String message;
  final String buttonLabel;

  ({Color color, IconData icon}) get _style {
    switch (kind) {
      case AppMessageKind.success:
        return (color: AppColors.success, icon: Icons.check_circle_rounded);
      case AppMessageKind.info:
        return (color: AppColors.primary, icon: Icons.info_rounded);
      case AppMessageKind.warning:
        return (
          color: AppColors.warning,
          icon: Icons.warning_amber_rounded
        );
      case AppMessageKind.error:
        return (color: AppColors.error, icon: Icons.error_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppDimens.lg, AppDimens.lg, AppDimens.lg, AppDimens.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(s.icon, color: s.color, size: 36),
            ),
            const SizedBox(height: AppDimens.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: AppDimens.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: s.color),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
