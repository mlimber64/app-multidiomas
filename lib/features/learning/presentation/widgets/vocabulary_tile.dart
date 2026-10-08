import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../voice/presentation/widgets/listen_button.dart';
import '../../domain/learning_overview.dart';

/// One word. The state line only claims what the memory can show: a word is
/// "being consolidated" until there is repeated correct use, and a word in use
/// is never called "learned".
/// Rediseño: tarjeta con la palabra en Fraunces, significado (o un hueco
/// punteado), estado, tres segmentos de uso correcto y el botón de escuchar.
class VocabularyTile extends StatelessWidget {
  const VocabularyTile({required this.word, super.key});

  final VocabularyView word;

  @override
  Widget build(BuildContext context) {
    final meaning = word.meaning;
    final l = context.l10n;

    final (icon, status, background, foreground) = word.isConsolidated
        ? (
            Icons.check_circle_outline,
            l.vocabInUse,
            AppColors.mint,
            AppColors.greenDark,
          )
        : word.hasBeenUsedCorrectly
        ? (
            Icons.check,
            l.vocabUsedCorrectly,
            AppColors.feedbackBg,
            AppColors.feedbackAccent,
          )
        : (
            Icons.bookmark_border,
            l.vocabToConsolidate,
            AppColors.amberBg,
            AppColors.amberText,
          );

    return AppCard(
      radius: AppRadius.hero,
      padding: const EdgeInsets.all(20),
      shadow: AppShadows.word,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(word.word, style: AppTextStyles.word),
          const SizedBox(height: 8),
          if (meaning != null && meaning.isNotEmpty)
            Text(meaning, style: AppTextStyles.bodyStrong)
          else
            // NUEVO: la app no guarda siempre el significado: se dice con un
            // hueco punteado en lugar de inventarlo.
            DottedBox(
              child: Text(
                l.wordsNoMeaning,
                style: AppTextStyles.small.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 12),
          StatusChip(
            label: status,
            icon: icon,
            background: background,
            foreground: foreground,
          ),
          const SizedBox(height: 12),
          SegmentProgress(
            total: 3,
            filled: math.min(word.successfulUses, 3),
            semanticLabel: l.wordUsesSemantics(word.successfulUses),
          ),
          const SizedBox(height: 8),
          ListenButton(
            speechKey: 'word:${word.word}',
            text: word.word,
            label: l.listen,
            chip: AppActionChipVariant.mint,
          ),
        ],
      ),
    );
  }
}
