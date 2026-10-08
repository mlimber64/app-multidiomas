import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

// NUEVO: barra de progreso por segmentos (gap 6). Se usa en la práctica de
// hoy (3 segmentos, alto 6) y en "Úsala en una frase" (3, alto 8).
class SegmentProgress extends StatelessWidget {
  const SegmentProgress({
    required this.total,
    required this.filled,
    this.height = 8,
    this.filledColor = AppColors.green,
    this.emptyColor = AppColors.track,
    this.semanticLabel,
    super.key,
  });

  final int total;
  final int filled;
  final double height;
  final Color filledColor;
  final Color emptyColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bar = Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.medium,
              height: height,
              decoration: BoxDecoration(
                color: i < filled ? filledColor : emptyColor,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ],
      ],
    );
    final label = semanticLabel;
    return label == null
        ? bar
        : Semantics(label: label, excludeSemantics: true, child: bar);
  }
}
