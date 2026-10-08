import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

// NUEVO: anillo de progreso (CustomPainter) con un texto al centro. [value]
// va de 0 a 1.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.value,
    required this.centerText,
    this.size = 96,
    this.stroke = 10,
    this.color = AppColors.blue,
    this.trackColor = AppColors.ringTrack,
    this.semanticLabel,
    super.key,
  });

  final double value;
  final String centerText;
  final double size;
  final double stroke;
  final Color color;
  final Color trackColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ring = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          stroke: stroke,
          color: color,
          trackColor: trackColor,
        ),
        child: Center(
          child: Text(
            centerText,
            style: AppTextStyles.statNumber.copyWith(
              fontSize: size * 0.28,
              color: AppColors.navy,
            ),
          ),
        ),
      ),
    );
    final label = semanticLabel;
    return label == null
        ? ring
        : Semantics(label: label, excludeSemantics: true, child: ring);
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double stroke;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base..color = trackColor);
    if (value > 0) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        base..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.stroke != stroke ||
      old.color != color ||
      old.trackColor != trackColor;
}
