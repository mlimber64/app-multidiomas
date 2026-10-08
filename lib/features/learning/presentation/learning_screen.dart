import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/ui/ui.dart';
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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ContentWidth(child: OverviewBuilder(builder: _content)),
      ),
    );
  }

  Widget _content(BuildContext context, LearningOverview overview) {
    final l = context.l10n;
    final priorities = overview.toReinforce;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        ScreenHeader(title: l.navLearn, subtitle: l.learnSubtitle),
        const SizedBox(height: AppSpacing.lg),
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
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.learnHowTitle, style: AppTextStyles.rowTitle),
                const SizedBox(height: AppSpacing.sm),
                Text(l.learnHowBody, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: l.letsTalk,
                  onPressed: () => context.go(AppRoutes.conversation),
                ),
              ],
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
        action: PrimaryButton(
          label: l.letsTalk,
          onPressed: () => context.go(AppRoutes.conversation),
        ),
      ),
    ];
  }
}

/// The single most important thing to work on, in a warm sentence.
/// Rediseño: tarjeta hero celeste.
class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.view, required this.onTap});

  final TopicView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final related = view.relatedTopics;
    final l = context.l10n;
    return CelesteHeroCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(view.topic.label(l), style: AppTextStyles.heroTitle),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  view.hasProgress ? l.topicProgressMade : l.topicWorthFocus,
                  style: AppTextStyles.screenSubtitle.copyWith(
                    color: AppColors.blueText,
                  ),
                ),
                if (related.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      l.relatedTo(related.map((t) => t.label(l)).join(', ')),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.blueText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right, color: AppColors.navy),
        ],
      ),
    );
  }
}
