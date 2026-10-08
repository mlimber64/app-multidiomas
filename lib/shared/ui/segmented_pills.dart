import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

// NUEVO: control segmentado en píldoras: contenedor surfaceSoft con ítems de
// alto 40; el seleccionado es blanco con sombra y texto verde oscuro.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    required this.items,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// (valor, texto) en el orden en que se muestran.
  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onChanged;

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
                  selected: value == selected,
                  onTap: () => onChanged(value),
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
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = selected
        ? AppTextStyles.bodyStrong.copyWith(
            fontSize: 14,
            color: AppColors.greenDark,
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
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected ? AppShadows.segment : null,
          ),
          child: Text(label, textAlign: TextAlign.center, style: style),
        ),
      ),
    );
  }
}
