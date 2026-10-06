import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/empty_state_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../learning/domain/learning_overview.dart';
import '../../learning/presentation/overview_builder.dart';
import '../../learning/presentation/widgets/error_pair_tile.dart';
import '../../learning/presentation/widgets/topic_detail_sheet.dart';
import '../../learning/presentation/widgets/topic_tile.dart';
import '../../learning/presentation/widgets/vocabulary_tile.dart';

/// "Percorso": how the learner's Italian is evolving, in plain words. It shows
/// only what the learning memory can back up, and nothing when there is
/// nothing yet.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  /// Words previewed here; the full list lives in "Parole".
  static const _wordPreview = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navPath)),
      body: ContentWidth(child: OverviewBuilder(builder: _content)),
    );
  }

  Widget _content(BuildContext context, LearningOverview overview) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final words = [
      ...overview.vocabularyToConsolidate,
      ...overview.vocabularyInUse,
    ].take(_wordPreview).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l.journeyTitle, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(l.progressIntro, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        if (overview.isEmpty)
          EmptyStateCard(
            icon: Icons.explore_outlined,
            title: l.progressEmptyTitle,
            message: l.progressEmptyBody,
            action: FilledButton(
              onPressed: () => context.go(AppRoutes.conversation),
              child: Text(l.letsTalk),
            ),
          )
        else ...[
          if (overview.improving.isNotEmpty) ...[
            SectionHeader(title: l.noteImprovingTitle),
            for (final t in overview.improving) ..._topic(context, t),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (overview.toReinforce.isNotEmpty) ...[
            SectionHeader(title: l.progressToReinforce),
            for (final t in overview.toReinforce) ..._topic(context, t),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (overview.recurringErrors.isNotEmpty) ...[
            SectionHeader(
              title: l.recurringErrors,
              subtitle: l.progressRecurringSub,
            ),
            for (final e in overview.recurringErrors) ...[
              ErrorPairTile(error: e),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          if (words.isNotEmpty) ...[
            SectionHeader(title: l.navWords),
            for (final w in words) ...[
              VocabularyTile(word: w),
              const SizedBox(height: AppSpacing.sm),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go(AppRoutes.vocabulary),
                child: Text(l.seeAllWords),
              ),
            ),
          ],
        ],
      ],
    );
  }

  List<Widget> _topic(BuildContext context, TopicView view) => [
    TopicTile(view: view, onTap: () => showTopicDetailSheet(context, view)),
    const SizedBox(height: AppSpacing.sm),
  ];
}
