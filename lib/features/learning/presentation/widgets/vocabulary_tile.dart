import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../voice/presentation/widgets/listen_button.dart';
import '../../domain/learning_overview.dart';
import '../../domain/user_vocabulary.dart';
import '../favorite_words.dart';

/// One word. The state line only claims what the memory can show: a word is
/// "being consolidated" until there is repeated correct use, and a word in use
/// is never called "learned".
/// Rediseño: tarjeta tipo flashcard con la palabra en Fraunces, acciones
/// rápidas arriba (favorita y escuchar), significado (o un hueco punteado),
/// estado y el medidor de dominio.
class VocabularyTile extends ConsumerWidget {
  const VocabularyTile({required this.word, super.key});

  final VocabularyView word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final id = UserVocabulary.idFor(word.word, word.language);
    final favorite = ref.watch(
      favoriteWordsProvider.select((favorites) => favorites.contains(id)),
    );

    return AppCard(
      radius: AppRadius.hero,
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 18),
      shadow: AppShadows.word,
      // NUEVO: la tarjeta se enmarca con un filete del color de su estado,
      // como el canto de una tarjeta coleccionable.
      borderColor: foreground.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NUEVO: palabra y acciones rápidas (favorita y escuchar), a mano en
          // la propia tarjeta.
          Row(
            children: [
              Expanded(child: Text(word.word, style: AppTextStyles.word)),
              IconButton(
                tooltip: favorite ? l.wordsFavoriteRemove : l.wordsFavoriteAdd,
                isSelected: favorite,
                onPressed: () => ref
                    .read(favoriteWordsProvider.notifier)
                    .toggle(word.word, word.language),
                icon: const Icon(Icons.favorite_border),
                selectedIcon: const Icon(Icons.favorite),
                style: IconButton.styleFrom(
                  foregroundColor: favorite
                      ? AppColors.terraText
                      : AppColors.muted,
                ),
              ),
              ListenButton(
                speechKey: 'word:${word.word}',
                text: word.word,
                tooltip: l.listen,
                icon: Icons.volume_up,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: (meaning != null && meaning.isNotEmpty)
                ? Text(meaning, style: AppTextStyles.bodyStrong)
                // NUEVO: la app no guarda siempre el significado: se dice con
                // un hueco punteado en lugar de inventarlo.
                : DottedBox(
                    child: Text(
                      l.wordsNoMeaning,
                      style: AppTextStyles.small.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
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
          _MasteryMeter(
            uses: word.successfulUses,
            color: foreground,
            consolidated: word.isConsolidated,
          ),
        ],
      ),
    );
  }
}

// NUEVO: medidor de dominio: tres puntos que se llenan con cada uso correcto
// (con el color del estado de la palabra) y el recuento escrito al lado, para
// que no dependa solo del color. Con tres usos la palabra pasa a "en uso".
class _MasteryMeter extends StatelessWidget {
  const _MasteryMeter({
    required this.uses,
    required this.color,
    required this.consolidated,
  });

  final int uses;
  final Color color;
  final bool consolidated;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filled = math.min(uses, 3);
    return Semantics(
      label: l.wordUsesSemantics(uses),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: AppMotion.medium,
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? color : Colors.transparent,
                border: Border.all(
                  color: i < filled ? color : AppColors.track,
                  width: 2,
                ),
              ),
              child: i < filled
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ],
          const SizedBox(width: 10),
          Text(
            l.wordMasteryCaption(filled),
            style: AppTextStyles.small.copyWith(
              color: consolidated ? color : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
