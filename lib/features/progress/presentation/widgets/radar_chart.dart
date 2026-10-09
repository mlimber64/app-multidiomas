import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_tokens.dart';

/// A radar (spider) chart: one axis per entry of [labels], the polygon drawn
/// out to [values] (0..1). It needs at least three axes to be a polygon; with
/// fewer, [RadarChart] draws nothing and the caller shows something else.
///
/// It adapts to its width: the chart is as tall as it is wide (up to
/// [maxSize]) and the labels sit outside the rings, kept inside the box, so
/// nothing is cut on a small phone. A value of 0 still shows as a small dot
/// near the center, so the axis is never invisible.
class RadarChart extends StatelessWidget {
  const RadarChart({
    required this.values,
    required this.labels,
    this.maxSize = 260,
    super.key,
  });

  final List<double> values;
  final List<String> labels;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    assert(values.length == labels.length, 'one label per value');
    if (values.length < 3) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, maxSize);
        return Center(
          // Decorative: the figures are in the list under it, in words.
          child: ExcludeSemantics(
            child: CustomPaint(
              size: Size(side, side * 0.9),
              painter: _RadarPainter(
                values: values,
                labels: labels,
                textScaler: MediaQuery.textScalerOf(context),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.values,
    required this.labels,
    required this.textScaler,
  });

  final List<double> values;
  final List<String> labels;
  final TextScaler textScaler;

  static const _rings = 3;
  static const _floor = 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    final labelStyle = AppTextStyles.small.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.greenDark,
    );
    final painters = [
      for (final label in labels)
        TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: size.width * 0.4),
    ];
    final labelHeight = painters.map((p) => p.height).reduce(math.max);
    final labelWidth = painters.map((p) => p.width).reduce(math.max);

    // Room for the labels around the rings.
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(
      16.0,
      math.min(
        size.width / 2 - labelWidth - 6,
        size.height / 2 - labelHeight - 6,
      ),
    );

    Offset point(int i, double r) {
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      return center + Offset(math.cos(angle), math.sin(angle)) * r;
    }

    Path polygon(double Function(int) r) {
      final path = Path()..moveTo(point(0, r(0)).dx, point(0, r(0)).dy);
      for (var i = 1; i < n; i++) {
        final p = point(i, r(i));
        path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.track;
    for (var ring = 1; ring <= _rings; ring++) {
      canvas.drawPath(polygon((_) => radius * ring / _rings), grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, point(i, radius), grid);
    }

    double reach(int i) =>
        radius * (_floor + (1 - _floor) * values[i].clamp(0.0, 1.0));
    final shape = polygon(reach);
    canvas
      ..drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.fill
          ..color = AppColors.green.withValues(alpha: 0.22),
      )
      ..drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.green,
      );
    final dot = Paint()..color = AppColors.green;
    final dotRing = Paint()..color = Colors.white;
    for (var i = 0; i < n; i++) {
      canvas
        ..drawCircle(point(i, reach(i)), 5.5, dotRing)
        ..drawCircle(point(i, reach(i)), 4, dot);
    }

    // Labels just outside each axis, pushed away from the center by half their
    // own size and kept inside the box.
    for (var i = 0; i < n; i++) {
      final tp = painters[i];
      final dir = point(i, 1) - center;
      final anchor = point(i, radius + 8);
      var dx = anchor.dx - tp.width / 2 + dir.dx * tp.width / 2;
      var dy = anchor.dy - tp.height / 2 + dir.dy * tp.height / 2;
      dx = dx.clamp(0.0, math.max(0.0, size.width - tp.width));
      dy = dy.clamp(0.0, math.max(0.0, size.height - tp.height));
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.values != values ||
      old.labels != labels ||
      old.textScaler != textScaler;
}
