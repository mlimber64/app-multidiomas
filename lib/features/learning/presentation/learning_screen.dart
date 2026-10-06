import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/empty_state_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../domain/learning_overview.dart';
import 'learning_labels.dart';
import 'overview_builder.dart';
import 'widgets/topic_detail_sheet.dart';
import 'widgets/topic_tile.dart';

/// "Impara": what is worth working on now. It is the entry point to the
/// learner's priorities, not an exercise: the way to work on them is the
/// conversation.
class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navLearn)),
      body: ContentWidth(child: OverviewBuilder(builder: _content)),
    );
  }

  Widget _content(BuildContext context, LearningOverview overview) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final priorities = overview.toReinforce;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (priorities.isEmpty)
          ..._withoutPriorities(context, overview)
        else ...[
          SectionHeader(title: l.learnImprove),
          _FocusCard(
            view: priorities.first,
            onTap: () => showTopicDetailSheet(context, priorities.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l.learnPriorities),
          for (var i = 0; i < priorities.length; i++) ...[
            TopicTile(
              view: priorities[i],
              rank: i + 1,
              onTap: () => showTopicDetailSheet(context, priorities[i]),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.learnHowTitle, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l.learnHowBody, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonal(
                    onPressed: () => context.go(AppRoutes.conversation),
                    child: Text(l.letsTalk),
                  ),
                ],
              ),
            ),
          ),
          if (overview.improving.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(title: l.noteImprovingTitle),
            for (final t in overview.improving) ...[
              TopicTile(view: t, onTap: () => showTopicDetailSheet(context, t)),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ],
      ],
    );
  }

  /// Nothing to reinforce: either the learner is doing well, or there is
  /// nothing to say yet. Both read as positive, never as an empty table.
  List<Widget> _withoutPriorities(
    BuildContext context,
    LearningOverview overview,
  ) {
    final l = context.l10n;
    if (overview.improving.isNotEmpty) {
      return [
        EmptyStateCard(
          icon: Icons.check_circle_outline,
          title: l.learnDoingWellTitle,
          message: l.learnDoingWellBody,
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: l.noteImprovingTitle),
        for (final t in overview.improving) ...[
          TopicTile(view: t, onTap: () => showTopicDetailSheet(context, t)),
          const SizedBox(height: AppSpacing.sm),
        ],
      ];
    }
    return [
      EmptyStateCard(
        icon: Icons.school_outlined,
        title: l.learnEmptyTitle,
        message: l.learnEmptyBody,
        action: FilledButton(
          onPressed: () => context.go(AppRoutes.conversation),
          child: Text(l.letsTalk),
        ),
      ),
    ];
  }
}

/// The single most important thing to work on, in a warm sentence.
class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.view, required this.onTap});

  final TopicView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );
    final related = view.relatedTopics;
    final l = context.l10n;
    return Material(
      color: scheme.primaryContainer,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.topic.label(l),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      view.hasProgress
                          ? l.topicProgressMade
                          : l.topicWorthFocus,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    if (related.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          l.relatedTo(
                            related.map((t) => t.label(l)).join(', '),
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
