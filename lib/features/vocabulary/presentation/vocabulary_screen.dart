import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/ui/ui.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/empty_illustration.dart';
import '../../../shared/widgets/section_header.dart';
import '../../learning/domain/learning_overview.dart';
import '../../learning/domain/user_vocabulary.dart';
import '../../learning/presentation/favorite_words.dart';
import '../../learning/presentation/overview_builder.dart';
import '../../learning/presentation/widgets/vocabulary_tile.dart';

// NUEVO: las pestañas del filtro de palabras.
enum _WordsTab { toConsolidate, inUse, all }

/// "Parole": the words the learner has met while talking. Words are grouped
/// only by what the memory can show: still to consolidate, or already in use.
/// Nothing is ever called "learned" (por eso la pestaña dice "En uso" y no
/// "Dominadas").
class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({super.key});

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen> {
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
    final favorites = ref.watch(favoriteWordsProvider);
    final rows = overview.hasVocabulary
        ? _rows(context, overview, tab, favorites)
        : const <Widget>[];

    // NUEVO: la lista se construye bajo demanda (ListView.builder): con muchas
    // palabras solo se crean las tarjetas que se ven.
    final header = <Widget>[
      ScreenHeader(title: l.navWords, subtitle: l.wordsIntro),
      const SizedBox(height: AppSpacing.lg),
      if (!overview.hasVocabulary)
        _WordsEmpty(title: l.wordsEmptyTitle, message: l.wordsEmptyBody)
      else ...[
        SegmentedPills<_WordsTab>(
          emphasized: true,
          selected: tab,
          onChanged: (value) => setState(() => _chosen = value),
          items: [
            (_WordsTab.toConsolidate, l.wordsTabToConsolidate),
            (_WordsTab.inUse, l.wordsTabInUse),
            (_WordsTab.all, l.wordsTabAll),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    ];
    final items = [...header, ...rows];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  /// The words (and their headings) of [tab], as rows of the list. Words the
  /// learner starred go first in their group.
  List<Widget> _rows(
    BuildContext context,
    LearningOverview overview,
    _WordsTab tab,
    Set<String> favorites,
  ) {
    final l = context.l10n;
    final toConsolidate = _starredFirst(
      overview.vocabularyToConsolidate,
      favorites,
    );
    final inUse = _starredFirst(overview.vocabularyInUse, favorites);
    final showFirst = tab != _WordsTab.inUse && toConsolidate.isNotEmpty;
    final showSecond = tab != _WordsTab.toConsolidate && inUse.isNotEmpty;
    if (!showFirst && !showSecond) {
      // NUEVO: una pestaña sin palabras dice por qué y qué hacer, según cuál
      // sea; nunca inventa nada.
      return [
        switch (tab) {
          _WordsTab.toConsolidate => _WordsEmpty(
            title: l.wordsEmptyConsolidateTitle,
            message: l.wordsEmptyConsolidateBody,
          ),
          _WordsTab.inUse => _WordsEmpty(
            title: l.wordsEmptyInUseTitle,
            message: l.wordsEmptyInUseBody,
          ),
          _WordsTab.all => _WordsEmpty(
            title: l.wordsEmptyTitle,
            message: l.wordsEmptyBody,
          ),
        },
      ];
    }
    return [
      if (showFirst) ...[
        SectionHeader(
          title: l.wordsToConsolidateTitle,
          subtitle: l.wordsToConsolidateSub,
        ),
        for (final w in toConsolidate) ..._tile(w),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (showSecond) ...[
        SectionHeader(title: l.wordsInUseTitle, subtitle: l.wordsInUseSub),
        for (final w in inUse) ..._tile(w),
      ],
    ];
  }

  List<Widget> _tile(VocabularyView word) => [
    VocabularyTile(word: word),
    const SizedBox(height: AppSpacing.md),
  ];

  /// Starred words first; the rest keep the order the memory gave them.
  static List<VocabularyView> _starredFirst(
    List<VocabularyView> words,
    Set<String> favorites,
  ) {
    bool starred(VocabularyView w) =>
        favorites.contains(UserVocabulary.idFor(w.word, w.language));
    return [...words.where(starred), ...words.where((w) => !starred(w))];
  }
}

// NUEVO: estado vacío de Palabras: una pequeña ilustración hecha con iconos
// (libro con chispas y un globo de charla), un texto que invita a seguir
// conversando y el botón para ir a hablar. Sin números ni ceros.
class _WordsEmpty extends StatelessWidget {
  const _WordsEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            const EmptyIllustration(icon: Icons.menu_book_outlined),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l.letsTalk,
              variant: PrimaryButtonVariant.green,
              trailingIcon: Icons.chat_bubble_outline,
              onPressed: () => context.go(AppRoutes.conversation),
            ),
          ],
        ),
      ),
    );
  }
}
