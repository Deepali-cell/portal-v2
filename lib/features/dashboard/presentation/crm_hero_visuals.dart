import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';

// ---------------------------------------------------------------------------
// Shared data shapes
// ---------------------------------------------------------------------------

/// One concentric ring in [CrmActivityRings]. [value] is a 0..1 progress.
class RingData {
  const RingData({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });
  final String label;
  final double value; // 0..1
  final String detail; // e.g. "8/12 · 67%"
  final Color color;
}

/// One tappable band in [CrmFunnel].
class FunnelStage {
  const FunnelStage({
    required this.label,
    required this.count,
    required this.color,
    this.route,
  });
  final String label;
  final int count;
  final Color color;
  final String? route;
}

// ---------------------------------------------------------------------------
// Apple-Watch style activity rings
// ---------------------------------------------------------------------------

/// Three concentric animated progress rings with a legend. Pure CustomPaint —
/// no chart dependency.
class CrmActivityRings extends StatefulWidget {
  const CrmActivityRings({super.key, required this.rings, this.centerLabel});
  final List<RingData> rings;
  final String? centerLabel;

  @override
  State<CrmActivityRings> createState() => _CrmActivityRingsState();
}

class _CrmActivityRingsState extends State<CrmActivityRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Row(
          children: [
            SizedBox(
              width: 116,
              height: 116,
              child: AnimatedBuilder(
                animation: _t,
                builder: (_, _) => CustomPaint(
                  painter: _RingsPainter(
                    rings: widget.rings,
                    t: _t.value,
                    trackColor: AppColors.outlineVariant,
                    centerLabel: widget.centerLabel,
                    centerStyle: theme.textTheme.titleLarge,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final r in widget.rings) ...[
                    _LegendRow(ring: r),
                    if (r != widget.rings.last)
                      const SizedBox(height: AppDimens.md),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.ring});
  final RingData ring;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: ring.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppDimens.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ring.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ring.detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.rings,
    required this.t,
    required this.trackColor,
    required this.centerLabel,
    required this.centerStyle,
  });
  final List<RingData> rings;
  final double t;
  final Color trackColor;
  final String? centerLabel;
  final TextStyle? centerStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 12.0;
    const gap = 5.0;
    final outer = size.width / 2 - stroke / 2;

    for (var i = 0; i < rings.length; i++) {
      final radius = outer - i * (stroke + gap);
      if (radius <= 0) continue;
      final rect = Rect.fromCircle(center: center, radius: radius);

      // Track.
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = trackColor.withValues(alpha: 0.5);
      canvas.drawArc(rect, 0, 2 * math.pi, false, track);

      // Progress sweep (from top, clockwise), animated.
      final sweep = (rings[i].value.clamp(0.0, 1.0)) * 2 * math.pi * t;
      final fg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: [rings[i].color.withValues(alpha: 0.65), rings[i].color],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect);
      canvas.drawArc(rect, -math.pi / 2, sweep, false, fg);
    }

    if (centerLabel != null) {
      final tp = TextPainter(
        text: TextSpan(text: centerLabel, style: centerStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.t != t || old.rings != rings;
}

// ---------------------------------------------------------------------------
// Animated tapered funnel
// ---------------------------------------------------------------------------

/// A real funnel: bands narrowing top→bottom, width ∝ count, with the
/// conversion % between consecutive stages. Tapping a band fires [onTapStage].
class CrmFunnel extends StatefulWidget {
  const CrmFunnel({super.key, required this.stages, required this.onTapStage});
  final List<FunnelStage> stages;
  final void Function(FunnelStage stage) onTapStage;

  static const double _bandHeight = 56;
  static const double _gap = 10;

  @override
  State<CrmFunnel> createState() => _CrmFunnelState();
}

class _CrmFunnelState extends State<CrmFunnel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  double get _height =>
      widget.stages.length * CrmFunnel._bandHeight +
      (widget.stages.length - 1) * CrmFunnel._gap;

  int _bandAt(double dy) {
    const unit = CrmFunnel._bandHeight + CrmFunnel._gap;
    final i = (dy / unit).floor();
    return i.clamp(0, widget.stages.length - 1);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.lg,
        ),
        child: SizedBox(
          height: _height,
          width: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) =>
                widget.onTapStage(widget.stages[_bandAt(d.localPosition.dy)]),
            child: AnimatedBuilder(
              animation: _t,
              builder: (_, _) => CustomPaint(
                painter: _FunnelPainter(
                  stages: widget.stages,
                  t: _t.value,
                  bandHeight: CrmFunnel._bandHeight,
                  gap: CrmFunnel._gap,
                  labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  convStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FunnelPainter extends CustomPainter {
  _FunnelPainter({
    required this.stages,
    required this.t,
    required this.bandHeight,
    required this.gap,
    required this.labelStyle,
    required this.convStyle,
  });
  final List<FunnelStage> stages;
  final double t;
  final double bandHeight;
  final double gap;
  final TextStyle? labelStyle;
  final TextStyle? convStyle;

  static const double _minFactor = 0.14; // tiny stages stay tappable/visible

  @override
  void paint(Canvas canvas, Size size) {
    if (stages.isEmpty) return;
    final maxCount = stages
        .map((s) => s.count)
        .fold(0, (a, b) => a > b ? a : b);
    final cx = size.width / 2;

    double widthOf(int i) {
      final base = maxCount == 0 ? 0.0 : stages[i].count / maxCount;
      final factor = _minFactor + (1 - _minFactor) * base;
      return size.width * factor * t;
    }

    for (var i = 0; i < stages.length; i++) {
      final top = i * (bandHeight + gap);
      final bottom = top + bandHeight;
      final topW = widthOf(i);
      final botW = i < stages.length - 1 ? widthOf(i + 1) : topW * 0.82;

      final path = Path()
        ..moveTo(cx - topW / 2, top)
        ..lineTo(cx + topW / 2, top)
        ..lineTo(cx + botW / 2, bottom)
        ..lineTo(cx - botW / 2, bottom)
        ..close();

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            stages[i].color,
            Color.lerp(stages[i].color, Colors.black, 0.16)!,
          ],
        ).createShader(Rect.fromLTWH(0, top, size.width, bandHeight));
      canvas.drawRRect(
        RRect.fromRectAndRadius(path.getBounds(), const Radius.circular(6)),
        paint,
      );
      canvas.drawPath(path, paint);

      // Stage label + count, centered on the band.
      _text(
        canvas,
        '${stages[i].label}   ${stages[i].count}',
        labelStyle,
        Offset(cx, top + bandHeight / 2),
        center: true,
      );

      // Conversion % pill on the gap below this band.
      if (i < stages.length - 1 && stages[i].count > 0) {
        final conv = (stages[i + 1].count / stages[i].count * 100).round();
        _text(
          canvas,
          '↓ $conv%',
          convStyle,
          Offset(size.width - 4, bottom + gap / 2),
          center: false,
          rightAlign: true,
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String s,
    TextStyle? style,
    Offset at, {
    bool center = true,
    bool rightAlign = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (center) {
      dx -= tp.width / 2;
    } else if (rightAlign) {
      dx -= tp.width;
    }
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_FunnelPainter old) => old.t != t || old.stages != stages;
}
