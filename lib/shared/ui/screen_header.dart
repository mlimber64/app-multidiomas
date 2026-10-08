import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';

// NUEVO: cabecera de pantalla del diseño: título Fraunces, subtítulo opcional
// y un widget a la derecha (racha, botones de Hablar).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleStyle,
    this.subtitleStyle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: titleStyle ?? AppTextStyles.screenTitle,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: subtitleStyle ?? AppTextStyles.screenSubtitle,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}
