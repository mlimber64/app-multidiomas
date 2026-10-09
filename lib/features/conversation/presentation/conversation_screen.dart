import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/ui/ui.dart';
import '../../../shared/widgets/content_width.dart';
import '../../daily_routine/presentation/widgets/scenario_banner.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/conversation.dart';
import 'ai_failure_messages.dart';
import 'conversation_controller.dart';
import 'widgets/composer.dart';
import 'widgets/message_bubble.dart';
import 'widgets/typing_indicator.dart';

/// "Parla": a text conversation with the AI teacher. All behavior lives in
/// [ConversationController]; this widget only renders state and forwards
/// user actions.
class ConversationScreen extends ConsumerWidget {
  const ConversationScreen({super.key});

  /// Each suggestion is sent as the learner's first message.
  static List<String> suggestions(AppLocalizations l) => [
    l.suggestionDay,
    l.suggestionWork,
    l.suggestionRestaurant,
    l.suggestionPractice,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationControllerProvider);
    final controller = ref.read(conversationControllerProvider.notifier);
    final speakReplies = ref.watch(
      userLearningProfileProvider.select((p) => p.speakReplies),
    );
    final canStartNew =
        !state.conversation.isEmpty &&
        state.status != ConversationStatus.sending &&
        state.status != ConversationStatus.loading;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            children: [
              // NUEVO: cabecera del diseño: título Fraunces, subtítulo y dos
              // botones redondos (leer en voz alta / nueva conversación).
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: ScreenHeader(
                  title: context.l10n.chatTitle,
                  subtitle: context.l10n.heroSubtitle,
                  titleStyle: AppTextStyles.chatTitle,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeaderButton(
                        tooltip: context.l10n.speakRepliesLabel,
                        selected: speakReplies,
                        icon: speakReplies
                            ? Icons.volume_up
                            : Icons.volume_off_outlined,
                        onPressed: () {
                          final profile = ref.read(userLearningProfileProvider);
                          ref
                              .read(userLearningProfileProvider.notifier)
                              .save(
                                profile.copyWith(
                                  speakReplies: !profile.speakReplies,
                                ),
                              );
                        },
                      ),
                      const SizedBox(width: 8),
                      _HeaderButton(
                        tooltip: context.l10n.newConversation,
                        icon: Icons.add_comment_outlined,
                        onPressed: canStartNew
                            ? controller.startNewConversation
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const ScenarioBanner(),
              Expanded(
                child: switch (state.status) {
                  ConversationStatus.loading => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  _ when state.conversation.isEmpty => _Welcome(
                    onSuggestion: controller.send,
                  ),
                  _ => _MessageList(state: state, onRetry: controller.retry),
                },
              ),
              if (state.status != ConversationStatus.loading)
                Composer(
                  canSend: state.canSend,
                  sending: state.status == ConversationStatus.sending,
                  correctionMode: state.correctionMode,
                  onSend: controller.send,
                  onSendVoice: controller.sendVoice,
                  // Quick replies make sense once the teacher has said
                  // something to ask about.
                  onQuickReply:
                      state.conversation.messages.any(
                        (m) => m.role == MessageRole.assistant,
                      )
                      ? controller.send
                      : null,
                  onCorrectionModeChanged: (v) =>
                      controller.setCorrectionMode(enabled: v),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// NUEVO: botón redondo de la cabecera de Hablar (44 × 44 de zona táctil).
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        selected: selected,
        label: tooltip,
        excludeSemantics: true,
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.45 : 1,
          child: InkResponse(
            onTap: onPressed,
            radius: 26,
            child: IconCircle(
              icon: icon,
              size: AppSizes.tapTarget,
              iconSize: 22,
              background: selected ? AppColors.mint : AppColors.surface,
              border: selected ? AppColors.green : AppColors.border,
            ),
          ),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(l.chatWelcomeTitle, style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        Text(l.chatWelcomeSubtitle, style: AppTextStyles.screenSubtitle),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final s in ConversationScreen.suggestions(l))
              AppActionChip(label: s, onPressed: () => onSuggestion(s)),
          ],
        ),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.state, required this.onRetry});

  final ConversationState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final messages = state.conversation.messages
        .where((m) => m.role != MessageRole.system)
        .toList();
    final sending = state.status == ConversationStatus.sending;
    final failed = state.status == ConversationStatus.error;
    // The list is reversed so the newest item stays anchored at the bottom
    // and the view follows new messages without manual scrolling. Index 0 is
    // the bottom: transient status first, then messages newest-to-oldest.
    final extra = (sending || failed) ? 1 : 0;

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: messages.length + extra,
      itemBuilder: (context, index) {
        if (extra == 1 && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: sending
                ? const TypingIndicator()
                : _ErrorCard(state: state, onRetry: onRetry),
          );
        }
        final message = messages[messages.length - 1 - (index - extra)];
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: MessageBubble(
            key: ValueKey(message.id),
            message: message,
            pendingVoice: sending && message == messages.last,
          ),
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.state, required this.onRetry});

  final ConversationState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = state.failure;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.terraBg,
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              failure?.userMessage(context.l10n) ??
                  context.l10n.chatErrorGeneric,
              style: AppTextStyles.body.copyWith(color: AppColors.terraText),
            ),
            if (state.canRetry) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.terraText,
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.tryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
