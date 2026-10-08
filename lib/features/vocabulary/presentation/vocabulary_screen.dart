import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/ui/ui.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/empty_state_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../learning/domain/learning_overview.dart';
import '../../learning/presentation/overview_builder.dart';
import '../../learning/presentation/widgets/vocabulary_tile.dart';

// NUEVO: las pestañas del filtro de palabras.
enum _WordsTab { toConsolidate, inUse, all }

/// "Parole": the words the learner has met while talking. Words are grouped
/// only by what the memory can show: still to consolidate, or already in use.
/// Nothing is ever called "learned" (por eso la pestaña dice "En uso" y no
/// "Dominadas").
class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  /// `null` hasta que la persona elige: entonces se abre en la primera
  /// pestaña que tenga palabras.
  _WordsTab? _chosen;

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
    final tab =
        _chosen ??
        (overview.vocabularyToConsolidate.isNotEmpty
            ? _WordsTab.toConsolidate
            : _WordsTab.inUse);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        ScreenHeader(title: l.navWords, subtitle: l.wordsIntro),
        const SizedBox(height: AppSpacing.lg),
        if (!overview.hasVocabulary)
          EmptyStateCard(
            icon: Icons.menu_book_outlined,
            title: l.wordsEmptyTitle,
            message: l.wordsEmptyBody,
          )
        else ...[
          SegmentedPills<_WordsTab>(
            selected: tab,
            onChanged: (value) => setState(() => _chosen = value),
            items: [
              (_WordsTab.toConsolidate, l.wordsTabToConsolidate),
              (_WordsTab.inUse, l.wordsTabInUse),
              (_WordsTab.all, l.wordsTabAll),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ..._list(context, overview, tab),
        ],
      ],
    );
  }

  List<Widget> _list(
    BuildContext context,
    LearningOverview overview,
    _WordsTab tab,
  ) {
    final l = context.l10n;
    final toConsolidate = overview.vocabularyToConsolidate;
    final inUse = overview.vocabularyInUse;
    final showFirst = tab != _WordsTab.inUse && toConsolidate.isNotEmpty;
    final showSecond = tab != _WordsTab.toConsolidate && inUse.isNotEmpty;
    if (!showFirst && !showSecond) {
      // Pestaña sin palabras: se dice, sin inventar nada.
      return [
        EmptyStateCard(
          icon: Icons.menu_book_outlined,
          title: l.wordsEmptyTitle,
          message: l.wordsEmptyBody,
        ),
      ];
    }
    return [
      if (showFirst) ...[
        SectionHeader(
          title: l.wordsToConsolidateTitle,
          subtitle: l.wordsToConsolidateSub,
        ),
        for (final w in toConsolidate) ...[
          VocabularyTile(word: w),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
      if (showSecond) ...[
        SectionHeader(title: l.wordsInUseTitle, subtitle: l.wordsInUseSub),
        for (final w in inUse) ...[
          VocabularyTile(word: w),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    ];
  }
}
