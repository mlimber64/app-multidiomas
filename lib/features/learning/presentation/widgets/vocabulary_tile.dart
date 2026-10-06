import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/learning_overview.dart';

/// One word. The state line only claims what the memory can show: a word is
/// "being consolidated" until there is repeated correct use, and a word in use
/// is never called "learned".
class VocabularyTile extends StatelessWidget {
  const VocabularyTile({required this.word, super.key});

  final VocabularyView word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meaning = word.meaning;
    final l = context.l10n;

    final (icon, status) = word.isConsolidated
        ? (Icons.check_circle_outline, l.vocabInUse)
        : word.hasBeenUsedCorrectly
        ? (Icons.check, l.vocabUsedCorrectly)
        : (Icons.bookmark_border, l.vocabToConsolidate);

    return Card(
      margin: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(word.word, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              if (meaning != null && meaning.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(meaning, style: theme.textTheme.bodyMedium),
                ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      status,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
