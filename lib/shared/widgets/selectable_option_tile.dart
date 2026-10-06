import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Option row, single or multiple choice. Selection is shown by border, fill
/// AND an icon (never color alone) and exposed to screen readers as selected.
/// Single choice uses a radio-style icon, multiple choice a checkbox-style one.
/// A disabled tile (for example an unselected option once the maximum is
/// reached) is dimmed and ignores taps.
enum OptionSelectionMode { single, multiple }

class SelectableOptionTile extends StatelessWidget {
  const SelectableOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.selectionMode = OptionSelectionMode.single,
    this.enabled = true,
    super.key,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final OptionSelectionMode selectionMode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outlineVariant,
        width: selected ? 2 : 1,
      ),
    );
    final multiple = selectionMode == OptionSelectionMode.multiple;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: !multiple,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: selected ? scheme.primaryContainer : scheme.surface,
          shape: shape,
          animationDuration: AppMotion.fast,
          child: InkWell(
            customBorder: shape,
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      multiple
                          ? (selected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank)
                          : (selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked),
                      color: selected ? scheme.primary : scheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
