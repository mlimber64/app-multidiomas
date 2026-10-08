import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

// NUEVO: variantes del chip de acción (mint = Escuchar/Despacio, feedback =
// botones dentro de la corrección, neutral = Corrígeme / Dame una pista).
enum AppActionChipVariant { mint, feedback, neutral }

// NUEVO: chip de acción del diseño. El chip visual mide 34–36, pero el área
// táctil es de al menos 44 × 44.
class AppActionChip extends StatelessWidget {
  const AppActionChip({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppActionChipVariant.mint,
    this.height = 34,
    this.selected = false,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppActionChipVariant variant;
  final double height;

  /// Para chips que se activan y desactivan (p. ej. Corrígeme).
  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground) = switch (variant) {
      AppActionChipVariant.mint => (
        AppColors.mintSoft,
        AppColors.mintBorder,
        AppColors.greenDark,
      ),
      AppActionChipVariant.feedback => (
        AppColors.surface,
        AppColors.feedbackChipBorder,
        AppColors.feedbackAccent,
      ),
      AppActionChipVariant.neutral => (
        AppColors.surface,
        AppColors.inputBorderIdle,
        AppColors.ink,
      ),
    };
    final fill = selected ? AppColors.mint : background;
    final line = selected ? AppColors.green : border;
    final ink = selected ? AppColors.greenDark : foreground;
    final radius = height / 2;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          // Toda la zona de 44 × 44 responde al toque, no solo el chip.
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppSizes.tapTarget / 2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.tapTarget,
                minWidth: AppSizes.tapTarget,
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  height: height,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: line, width: selected ? 1.5 : 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: ink),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          style: AppTextStyles.chip.copyWith(color: ink),
                        ),
                      ),
                    ],
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
