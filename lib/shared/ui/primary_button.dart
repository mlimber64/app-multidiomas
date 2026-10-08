import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

// NUEVO: variantes del botón primario (azul sobre celeste, verde, contorno).
enum PrimaryButtonVariant { blue, green, outlinedGreen }

// NUEVO: botón primario del diseño: alto 52, radio 26, texto 16/800.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.variant = PrimaryButtonVariant.green,
    this.trailingIcon,
    this.leadingIcon,
    this.height = AppSizes.control,
    super.key,
  });

  final String label;

  /// `null` lo deshabilita.
  final VoidCallback? onPressed;
  final PrimaryButtonVariant variant;
  final IconData? trailingIcon;
  final IconData? leadingIcon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (variant) {
      PrimaryButtonVariant.blue => (AppColors.blue, Colors.white, null),
      PrimaryButtonVariant.green => (AppColors.green, Colors.white, null),
      PrimaryButtonVariant.outlinedGreen => (
        AppColors.surface,
        AppColors.greenDark,
        const BorderSide(color: AppColors.green, width: 1.5),
      ),
    };
    final enabled = onPressed != null;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
      side: border ?? BorderSide.none,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: background,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            splashColor: foreground.withValues(alpha: 0.12),
            highlightColor: foreground.withValues(alpha: 0.06),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leadingIcon != null) ...[
                        Icon(leadingIcon, size: 20, color: foreground),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.button.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 8),
                        Icon(trailingIcon, size: 20, color: foreground),
                      ],
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
