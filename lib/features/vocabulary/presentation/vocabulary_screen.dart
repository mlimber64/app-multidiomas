import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/empty_state_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../learning/domain/learning_overview.dart';
import '../../learning/presentation/overview_builder.dart';
import '../../learning/presentation/widgets/vocabulary_tile.dart';

/// "Parole": the words the learner has met while talking. Words are grouped
/// only by what the memory can show: still to consolidate, or already in use.
/// Nothing is ever called "learned".
class VocabularyScreen extends StatelessWidget {
  const VocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navWords)),
      body: ContentWidth(child: OverviewBuilder(builder: _content)),
    );
  }

  Widget _content(BuildContext context, LearningOverview overview) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l.wordsHeadline, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(l.wordsIntro, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        if (!overview.hasVocabulary)
          EmptyStateCard(
            icon: Icons.menu_book_outlined,
            title: l.wordsEmptyTitle,
            message: l.wordsEmptyBody,
          )
        else ...[
          if (overview.vocabularyToConsolidate.isNotEmpty) ...[
            SectionHeader(
              title: l.wordsToConsolidateTitle,
              subtitle: l.wordsToConsolidateSub,
            ),
            for (final w in overview.vocabularyToConsolidate) ...[
              VocabularyTile(word: w),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          if (overview.vocabularyInUse.isNotEmpty) ...[
            SectionHeader(title: l.wordsInUseTitle, subtitle: l.wordsInUseSub),
            for (final w in overview.vocabularyInUse) ...[
              VocabularyTile(word: w),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ],
      ],
    );
  }
}
