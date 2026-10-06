import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/learning_overview.dart';
import '../learning_labels.dart';
import 'error_pair_tile.dart';

/// Detail of one topic, built only from what the memory knows: the related
/// topics, the mistakes behind it and the evidence of progress. It explains
/// nothing about grammar and offers no exercise; the way to work on it is to
/// keep using it in conversation.
Future<void> showTopicDetailSheet(BuildContext context, TopicView view) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TopicDetail(view: view),
  );
}

class _TopicDetail extends StatelessWidget {
  const _TopicDetail({required this.view});

  final TopicView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final improving = view.standing == TopicStanding.improving;
    final l = context.l10n;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Text(view.topic.label(l), style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            improving
                ? l.topicImprovingDetail
                : view.hasProgress
                ? l.topicProgressWorth
                : l.topicWorthFocus,
            style: theme.textTheme.bodyLarge,
          ),
          if (view.hasProgress) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: view.correctShare,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.correctOutOf(view.successfulUses, view.appearances),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (view.relatedTopics.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(l.workingOn, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            for (final t in view.relatedTopics)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '• ${t.label(l)}',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
          ],
          if (view.relatedErrors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              view.relatedErrors.any((e) => e.isRecurring)
                  ? l.recurringErrors
                  : l.mistakes,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final e in view.relatedErrors)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ErrorPairTile(error: e, showTopic: false),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(l.keepUsingIt, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.conversation);
            },
            child: Text(l.letsTalk),
          ),
        ],
      ),
    );
  }
}
