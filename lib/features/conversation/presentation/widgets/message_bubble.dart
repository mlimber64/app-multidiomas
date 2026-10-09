import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../../services/speech/speech_service.dart';
import '../../../../shared/models/correction.dart';
import '../../../../shared/ui/app_action_chip.dart';
import '../../../../shared/ui/icon_tile.dart';
import '../../../voice/domain/speech_text.dart';
import '../../../voice/presentation/speech_controller.dart';
import '../../../voice/presentation/widgets/listen_button.dart';
import '../../domain/conversation.dart';

/// One chat message. Assistant messages show their corrections as cards
/// under the bubble.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    this.pendingVoice = false,
    super.key,
  });

  final ConversationMessage message;

  /// A voice message whose reply (and so whose transcript) is still coming.
  final bool pendingVoice;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final width = MediaQuery.sizeOf(context).width;

    final column = Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Semantics(
          label: isUser ? context.l10n.roleYou : context.l10n.roleTeacher,
          // NUEVO: burbujas asimétricas. Las esquinas son amplias (20) y solo
          // una es casi recta (6): la que apunta a quien habla, la de arriba
          // junto al avatar en el profesor y la de abajo a la derecha en el
          // alumno.
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isUser ? AppColors.green : AppColors.surface,
              border: isUser ? null : Border.all(color: AppColors.border),
              boxShadow: isUser ? null : bubbleShadow,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isUser ? bubbleRadius : 6),
                topRight: const Radius.circular(bubbleRadius),
                bottomLeft: const Radius.circular(bubbleRadius),
                bottomRight: Radius.circular(isUser ? 6 : bubbleRadius),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _content(context, isUser),
            ),
          ),
        ),
        if (!isUser)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ListenButton(
              speechKey: speechKeyOf(message.id),
              text: message.content,
              tooltip: context.l10n.listenToMessage,
              label: context.l10n.listen,
              chip: AppActionChipVariant.mint,
            ),
          ),
        for (var i = 0; i < message.corrections.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: CorrectionCard(
              correction: message.corrections[i],
              messageId: message.id,
              index: i,
            ),
          ),
      ],
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (width * 0.85).clamp(0, AppSizes.maxContentWidth * 0.85),
        ),
        // NUEVO: el profesor lleva su avatar a la izquierda, así se distingue
        // de un vistazo de los mensajes del alumno. Las correcciones y el
        // botón de escuchar quedan alineados con la burbuja, no con el avatar.
        child: isUser
            ? column
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TeacherAvatar(),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: column),
                ],
              ),
      ),
    );
  }
}

/// Radius of the chat bubbles' wide corners.
const bubbleRadius = 20.0;

/// A barely-there shadow that lifts the teacher's white bubble off the cream.
const bubbleShadow = [
  BoxShadow(color: AppColors.wordShadow, blurRadius: 8, offset: Offset(0, 2)),
];

// NUEVO: avatar del profesor de IA: círculo menta con un icono de profesor
// (decorativo: el rol ya se anuncia en la burbuja).
class TeacherAvatar extends StatelessWidget {
  const TeacherAvatar({this.size = 32, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IconCircle(
      icon: Icons.school,
      size: size,
      iconSize: size * 0.56,
      background: AppColors.mint,
      foreground: AppColors.greenDark,
      border: AppColors.mintBorder,
    ),
  );
}

extension on MessageBubble {
  /// A typed message: its words and, for the teacher, their translation under
  /// them inside the same bubble (the words always come first).
  Widget _withTranslation(BuildContext context, bool isUser, TextStyle style) {
    final target = SelectableText(message.content, style: style);
    final translation = isUser ? null : message.translation;
    if (translation == null) return target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        target,
        const SizedBox(height: AppSpacing.sm),
        TranslationLine(text: translation, color: AppColors.muted),
      ],
    );
  }

  /// The words of the message; for a voice message, with a microphone and, while
  /// the transcript has not arrived (or was never understood), what is going
  /// on instead of an empty bubble.
  Widget _content(BuildContext context, bool isUser) {
    final style = AppTextStyles.chat.copyWith(
      color: isUser ? Colors.white : AppColors.ink,
    );
    if (!message.isVoice) {
      return _withTranslation(context, isUser, style);
    }
    final l = context.l10n;
    final waiting = message.content.isEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.mic,
          size: 18,
          color: isUser ? Colors.white : AppColors.ink,
          semanticLabel: l.voiceMessage,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: waiting
              ? Text(
                  pendingVoice ? l.voiceListening : l.voiceNotUnderstood,
                  style: style.copyWith(fontStyle: FontStyle.italic),
                )
              : SelectableText(message.content, style: style),
        ),
      ],
    );
  }
}

/// The same sentence in the learner's support language, as a quiet second line
/// of the one message (or card): clearly secondary, never a message of its own.
class TranslationLine extends StatelessWidget {
  const TranslationLine({required this.text, required this.color, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.body.copyWith(
      color: color,
      fontStyle: FontStyle.italic,
    );
    return Semantics(
      label: context.l10n.translationLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ExcludeSemantics(
              child: Icon(Icons.translate, size: 16, color: color),
            ),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Flexible(child: SelectableText(text, style: style)),
        ],
      ),
    );
  }
}

// NUEVO: tarjeta de corrección del diseño: fondo celeste de feedback, borde
// suave, categoría con icono, "Escribiste / Mejor" y chips para escuchar.
class CorrectionCard extends StatelessWidget {
  const CorrectionCard({
    required this.correction,
    required this.messageId,
    required this.index,
    super.key,
  });

  final Correction correction;

  /// With [index], tells the card's listening buttons from the others'.
  final String messageId;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final alternative = correction.naturalAlternative;
    final body = AppTextStyles.body.copyWith(color: AppColors.feedbackText);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.feedbackBg,
        border: Border.all(color: AppColors.feedbackBorder),
        borderRadius: BorderRadius.circular(bubbleRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // NUEVO: varita mágica en un círculo, para que la corrección
                // de la IA destaque con jerarquía propia dentro del chat.
                const ExcludeSemantics(
                  child: IconCircle(
                    icon: Icons.auto_fix_high,
                    size: 30,
                    iconSize: 18,
                    background: AppColors.surface,
                    foreground: AppColors.feedbackAccent,
                    border: AppColors.feedbackChipBorder,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    _categoryLabel(l, correction.category),
                    style: AppTextStyles.rowTitle.copyWith(
                      color: AppColors.feedbackAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Both lines are labeled so the change is clear without relying
            // on color or strikethrough alone.
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: l.youWrote),
                  TextSpan(
                    text: correction.original,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      decorationColor: AppColors.errorStrike,
                    ),
                  ),
                ],
              ),
              style: body.copyWith(color: AppColors.feedbackSub),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: l.better),
                  TextSpan(
                    text: correction.corrected,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              style: body.copyWith(fontSize: 16),
            ),
            if (correction.correctedTranslation case final translation?) ...[
              const SizedBox(height: AppSpacing.xs),
              TranslationLine(text: translation, color: AppColors.feedbackSub),
            ],
            if (correction.explanation.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(correction.explanation, style: body),
            ],
            if (alternative != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.moreNatural(alternative),
                style: body.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.hearItRight,
              style: AppTextStyles.small.copyWith(color: AppColors.feedbackSub),
            ),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                ListenButton(
                  speechKey: correctionSpeechKey(messageId, index, 'normal'),
                  text: correction.corrected,
                  label: l.listen,
                  chip: AppActionChipVariant.feedback,
                ),
                ListenButton(
                  speechKey: correctionSpeechKey(messageId, index, 'slow'),
                  text: correction.corrected,
                  label: l.listenSlowly,
                  icon: Icons.slow_motion_video,
                  pace: SpeechPace.slow,
                  chip: AppActionChipVariant.feedback,
                ),
                ListenButton(
                  speechKey: correctionSpeechKey(messageId, index, 'spell'),
                  text: spellOut(correction.corrected),
                  label: l.spellIt,
                  icon: Icons.spellcheck,
                  pace: SpeechPace.slow,
                  chip: AppActionChipVariant.feedback,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _categoryLabel(
    AppLocalizations l,
    CorrectionCategory category,
  ) => switch (category) {
    CorrectionCategory.grammar => l.categoryGrammar,
    CorrectionCategory.vocabulary => l.categoryVocabulary,
    CorrectionCategory.pronunciation => l.categoryPronunciation,
    CorrectionCategory.naturalExpression => l.categoryNaturalExpression,
    CorrectionCategory.spelling => l.categorySpelling,
    CorrectionCategory.other => l.categoryOther,
  };
}
