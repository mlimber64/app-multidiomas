import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

// NUEVO: control segmentado en píldoras: contenedor surfaceSoft con ítems de
// alto 40; el seleccionado es blanco con sombra y texto verde oscuro.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    required this.items,
    required this.selected,
    required this.onChanged,
    this.emphasized = false,
    this.iconOf,
    super.key,
  });

  /// (valor, texto) en el orden en que se muestran.
  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onChanged;

  /// NUEVO: el ítem activo se rellena de verde con texto blanco (y vibra al
  /// cambiar), un cambio de estado mucho más claro que el blanco con sombra.
  final bool emphasized;

  /// NUEVO: icono opcional delante del texto de cada ítem.
  final IconData? Function(T value)? iconOf;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final (value, label) in items)
              Expanded(
                child: _Segment(
                  label: label,
                  icon: iconOf?.call(value),
                  selected: value == selected,
                  emphasized: emphasized,
                  onTap: () {
                    if (emphasized && value != selected) {
                      HapticFeedback.selectionClick();
                    }
                    onChanged(value);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.emphasized,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = selected
        ? AppTextStyles.bodyStrong.copyWith(
            fontSize: 14,
            color: emphasized ? Colors.white : AppColors.greenDark,
          )
        : AppTextStyles.bodyStrong.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? (emphasized ? AppColors.green : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected ? AppShadows.segment : null,
          ),
          child: icon == null
              ? Text(label, textAlign: TextAlign.center, style: style)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: Icon(icon, size: 18, color: style.color),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: style,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
