import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../../services/speech/speech_service.dart';
import '../../../../shared/models/correction.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == MessageRole.user;
    final width = MediaQuery.sizeOf(context).width;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (width * 0.85).clamp(0, AppSizes.maxContentWidth * 0.85),
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Semantics(
              label: isUser ? context.l10n.roleYou : context.l10n.roleTeacher,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isUser ? scheme.primary : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadius.lg),
                    topRight: const Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(isUser ? AppRadius.lg : 6),
                    bottomRight: Radius.circular(isUser ? 6 : AppRadius.lg),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  child: _content(context, isUser, scheme),
                ),
              ),
            ),
            if (!isUser)
              ListenButton(
                speechKey: speechKeyOf(message.id),
                text: message.content,
                tooltip: context.l10n.listenToMessage,
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
        ),
      ),
    );
  }
}

extension on MessageBubble {
  /// The words of the message; for a voice message, with a microphone and, while
  /// the transcript has not arrived (or was never understood), what is going
  /// on instead of an empty bubble.
  Widget _content(BuildContext context, bool isUser, ColorScheme scheme) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: isUser ? scheme.onPrimary : scheme.onSurface,
    );
    if (!message.isVoice) return SelectableText(message.content, style: style);
    final l = context.l10n;
    final waiting = message.content.isEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.mic,
          size: 18,
          color: isUser ? scheme.onPrimary : scheme.onSurface,
          semanticLabel: l.voiceMessage,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: waiting
              ? Text(
                  pendingVoice ? l.voiceListening : l.voiceNotUnderstood,
                  style: style?.copyWith(fontStyle: FontStyle.italic),
                )
              : SelectableText(message.content, style: style),
        ),
      ],
    );
  }
}

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final alternative = correction.naturalAlternative;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note,
                  size: 20,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _categoryLabel(context.l10n, correction.category),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onTertiaryContainer,
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
                  TextSpan(text: context.l10n.youWrote),
                  TextSpan(
                    text: correction.original,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: context.l10n.better),
                  TextSpan(
                    text: correction.corrected,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
            if (correction.explanation.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                correction.explanation,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ],
            if (alternative != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.l10n.moreNatural(alternative),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.hearItRight,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
            TextButtonTheme(
              data: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onTertiaryContainer,
                ),
              ),
              child: Wrap(
                spacing: AppSpacing.xs,
                children: [
                  ListenButton(
                    speechKey: correctionSpeechKey(messageId, index, 'normal'),
                    text: correction.corrected,
                    label: context.l10n.listen,
                  ),
                  ListenButton(
                    speechKey: correctionSpeechKey(messageId, index, 'slow'),
                    text: correction.corrected,
                    label: context.l10n.listenSlowly,
                    icon: Icons.slow_motion_video,
                    pace: SpeechPace.slow,
                  ),
                  ListenButton(
                    speechKey: correctionSpeechKey(messageId, index, 'spell'),
                    text: spellOut(correction.corrected),
                    label: context.l10n.spellIt,
                    icon: Icons.spellcheck,
                    pace: SpeechPace.slow,
                  ),
                ],
              ),
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
