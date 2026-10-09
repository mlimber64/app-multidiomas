import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';
import 'app_card.dart';
import 'icon_tile.dart';

// NUEVO: fila de ajustes del perfil: etiqueta pequeña, valor destacado y
// chevron. Toda la fila es el botón de edición.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.iconBackground = AppColors.mint,
    this.iconForeground = AppColors.greenDark,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  /// NUEVO: icono sutil al inicio de la fila, en un círculo de color.
  final IconData? icon;
  final Color iconBackground;
  final Color iconForeground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                if (icon != null) ...[
                  IconCircle(
                    icon: icon!,
                    size: 38,
                    iconSize: 20,
                    background: iconBackground,
                    foreground: iconForeground,
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.small.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(value, style: AppTextStyles.bodyStrong),
                    ],
                  ),
                ),
                // NUEVO: la flecha va en un círculo suave: se lee como "se abre".
                const SizedBox(width: 8),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 28,
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// NUEVO: lista de ajustes en una sola tarjeta, con divisores de 1 px.
class SettingsList extends StatelessWidget {
  const SettingsList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: AppRadius.panel,
    padding: EdgeInsets.zero,
    // NUEVO: tarjeta elevada, con la misma sombra suave que las demás.
    shadow: AppShadows.word,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          children[i],
        ],
      ],
    ),
  );
}
