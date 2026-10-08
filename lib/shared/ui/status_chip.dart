import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

// NUEVO: píldora de estado (texto + icono opcional) con colores configurables.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    this.icon,
    this.background = AppColors.mint,
    this.foreground = AppColors.greenDark,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    this.iconSize = 14,
    this.textStyle,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final style = (textStyle ?? AppTextStyles.status).copyWith(
      color: foreground,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: Icon(icon, size: iconSize, color: foreground),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(child: Text(label, style: style)),
          ],
        ),
      ),
    );
  }
}
