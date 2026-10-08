import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

// NUEVO: caja con borde punteado (CustomPainter, sin dependencias) para los
// huecos del diseño, como el significado que aún no existe.
class DottedBox extends StatelessWidget {
  const DottedBox({
    required this.child,
    this.color = AppColors.inputBorderIdle,
    this.radius = AppRadius.sm + 6,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    super.key,
  });

  final Widget child;
  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DottedPainter(color: color, radius: radius),
    child: Padding(padding: padding, child: child),
  );
}

class _DottedPainter extends CustomPainter {
  const _DottedPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.75),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DottedPainter old) =>
      old.color != color || old.radius != radius;
}
