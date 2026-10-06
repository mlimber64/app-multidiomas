import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/content_width.dart';
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
      appBar: AppBar(
        title: Text(context.l10n.chatTitle),
        actions: [
          // Replies read aloud: on/off, kept in the profile.
          IconButton(
            tooltip: context.l10n.speakRepliesLabel,
            isSelected: speakReplies,
            onPressed: () {
              final profile = ref.read(userLearningProfileProvider);
              ref
                  .read(userLearningProfileProvider.notifier)
                  .save(profile.copyWith(speakReplies: !profile.speakReplies));
            },
            icon: Icon(
              speakReplies ? Icons.volume_up : Icons.volume_off_outlined,
            ),
          ),
          IconButton(
            tooltip: context.l10n.newConversation,
            onPressed: canStartNew ? controller.startNewConversation : null,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: ContentWidth(
        child: Column(
          children: [
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
                onCorrectionModeChanged: (v) =>
                    controller.setCorrectionMode(enabled: v),
              ),
          ],
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
    final theme = Theme.of(context);
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(l.chatWelcomeTitle, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(l.chatWelcomeSubtitle, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in ConversationScreen.suggestions(l))
              ActionChip(label: Text(s), onPressed: () => onSuggestion(s)),
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
    final scheme = Theme.of(context).colorScheme;
    final failure = state.failure;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              failure?.userMessage(context.l10n) ??
                  context.l10n.chatErrorGeneric,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
            ),
            if (state.canRetry) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
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
