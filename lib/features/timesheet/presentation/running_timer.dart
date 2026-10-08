import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/timesheet_controller.dart';
import '../domain/models.dart';
import 'timer_sheets.dart';

String formatElapsed(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// 1-second ticker mixin — drives the live elapsed display.
mixin _TickerMixin<T extends StatefulWidget> on State<T> {
  Timer? _tick;
  void startTicking() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void stopTicking() {
    _tick?.cancel();
    _tick = null;
  }
}

/// Large card shown at the top of the Timesheet screen when a timer runs.
class RunningTimerCard extends ConsumerStatefulWidget {
  const RunningTimerCard({super.key, required this.timer});
  final ActiveTimer timer;
  @override
  ConsumerState<RunningTimerCard> createState() => _RunningTimerCardState();
}

class _RunningTimerCardState extends ConsumerState<RunningTimerCard>
    with _TickerMixin {
  @override
  void initState() {
    super.initState();
    startTicking();
  }

  @override
  void dispose() {
    stopTicking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.timer.elapsedNow();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        onTap: () => showStopTimerSheet(context, widget.timer),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.bolt,
                    color: AppColors.onSecondaryContainer, size: 24),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.timer.task,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        '${widget.timer.activityType} · ${widget.timer.project}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.primaryFixedDim, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(formatElapsed(elapsed),
                        style: TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Icon(Icons.stop_circle,
                  color: AppColors.tertiaryFixedDim, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin one-line strip shown above the bottom nav on every other screen.
class RunningTimerStrip extends ConsumerStatefulWidget {
  const RunningTimerStrip({super.key});
  @override
  ConsumerState<RunningTimerStrip> createState() => _RunningTimerStripState();
}

class _RunningTimerStripState extends ConsumerState<RunningTimerStrip>
    with _TickerMixin {
  @override
  void initState() {
    super.initState();
    startTicking();
  }

  @override
  void dispose() {
    stopTicking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeTimerProvider);
    return async.maybeWhen(
      data: (timer) {
        if (timer == null) return const SizedBox.shrink();
        final elapsed = timer.elapsedNow();
        return Material(
          color: AppColors.primaryContainer,
          child: InkWell(
            onTap: () => showStopTimerSheet(context, timer),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.bolt,
                        size: 16, color: AppColors.tertiaryFixedDim),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${timer.task} · ${formatElapsed(elapsed)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Text('Stop',
                        style: TextStyle(
                            color: AppColors.tertiaryFixedDim,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
