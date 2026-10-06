import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../l10n/l10n.dart';
import 'selectable_option_tile.dart';

/// A column of multiple-choice [SelectableOptionTile]s with a hint line
/// ("Scegli da 1 a 3 · 2 selezionati"). Once [max] options are selected the
/// remaining ones are disabled. The list holds no state: the owner applies the
/// selection rules in [onToggle].
class MultiSelectOptionList<T> extends StatelessWidget {
  const MultiSelectOptionList({
    required this.options,
    required this.selected,
    required this.min,
    required this.max,
    required this.onToggle,
    this.tileSpacing = AppSpacing.sm,
    super.key,
  });

  final List<(T, String)> options;
  final Set<T> selected;
  final int min;
  final int max;
  final ValueChanged<T> onToggle;
  final double tileSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atLimit = selected.length >= max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            context.l10n.selectionHint(min, max, selected.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final (value, label) in options)
          Padding(
            padding: EdgeInsets.only(bottom: tileSpacing),
            child: SelectableOptionTile(
              title: label,
              selected: selected.contains(value),
              selectionMode: OptionSelectionMode.multiple,
              // Selected tiles stay enabled so they can always be removed.
              enabled: selected.contains(value) || !atLimit,
              onTap: () => onToggle(value),
            ),
          ),
      ],
    );
  }
}
