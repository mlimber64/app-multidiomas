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
import '../../daily_routine/presentation/practice_activity.dart';
import '../../learning/domain/learning_overview.dart';
import '../../learning/presentation/overview_builder.dart';
import '../../learning/presentation/widgets/error_pair_tile.dart';
import '../../learning/presentation/widgets/topic_detail_sheet.dart';
import '../../learning/presentation/widgets/topic_tile.dart';
import '../../learning/presentation/widgets/vocabulary_tile.dart';
import '../domain/skill_metrics.dart';
import 'widgets/skills_card.dart';
import 'widgets/week_card.dart';

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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ContentWidth(child: OverviewBuilder(builder: _content)),
      ),
    );
  }

  Widget _content(BuildContext context, LearningOverview overview) {
    final l = context.l10n;
    final words = [
      ...overview.vocabularyToConsolidate,
      ...overview.vocabularyInUse,
    ].take(_wordPreview).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        ScreenHeader(title: l.navPath, subtitle: l.progressIntro),
        const SizedBox(height: AppSpacing.lg),
        if (overview.isEmpty) ...[
          const _ProgressEmpty(),
          // The week is there from the start: a day of practice is something
          // to see even before the memory has anything to say.
          const SizedBox(height: 14),
          const WeekCard(),
        ] else ...[
          if (overview.hasTopics) ...[
            _RingHero(overview: overview),
            const SizedBox(height: 14),
          ],
          const WeekCard(),
          const SizedBox(height: 14),
          _StatGrid(overview: overview),
          const SizedBox(height: 14),
          _Skills(overview: overview),
          const SizedBox(height: AppSpacing.lg),
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
              const SizedBox(height: AppSpacing.md),
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

// NUEVO: "Tus áreas": la gráfica de habilidades con lo que la memoria puede
// respaldar (vocabulario, gramática y constancia).
class _Skills extends ConsumerWidget {
  const _Skills({required this.overview});

  final LearningOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(practiceActivityProvider).value;
    return SkillsCard(metrics: buildSkillMetrics(overview, activity));
  }
}

// NUEVO: estado vacío motivador: una ilustración, un mensaje que invita a
// empezar y dos caminos: hablar, o hacer la práctica de hoy.
class _ProgressEmpty extends StatelessWidget {
  const _ProgressEmpty();

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
            const EmptyIllustration(
              icon: Icons.explore_outlined,
              badge: Icons.trending_up,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.progressEmptyTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.progressEmptyBody,
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
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: l.progressEmptyPractice,
              variant: PrimaryButtonVariant.outlinedGreen,
              onPressed: () => context.push(AppRoutes.dailyRoutine),
            ),
          ],
        ),
      ),
    );
  }
}

// NUEVO: hero con el anillo. No hay un "porcentaje de progreso" en la app: el
// anillo muestra qué parte de las áreas con datos está mejorando (mejorando /
// mejorando + por reforzar).
class _RingHero extends StatelessWidget {
  const _RingHero({required this.overview});

  final LearningOverview overview;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final improving = overview.improving.length;
    final total = improving + overview.toReinforce.length;
    final share = total == 0 ? 0.0 : improving / total;
    return CelesteHeroCard(
      child: Row(
        children: [
          ProgressRing(
            value: share,
            // Sin porcentajes: la app no los muestra, solo cuentas reales.
            centerText: '$improving/$total',
            semanticLabel: l.progressRingCaption(improving, total),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.journeyTitle.toUpperCase(),
                  style: AppTextStyles.eyebrow.copyWith(
                    color: AppColors.blueText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.progressRingCaption(improving, total),
                  style: AppTextStyles.heroTitleLevel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// NUEVO: las cifras reales de la memoria de aprendizaje, en tarjetas elevadas
// con un icono de color. Un logro (áreas mejorando, racha) lleva un filete del
// color de su acento. La racha solo aparece cuando la hay: nunca un "0 días".
class _StatGrid extends ConsumerWidget {
  const _StatGrid({required this.overview});

  final LearningOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final streak = ref.watch(practiceActivityProvider).value?.streak ?? 0;
    final words =
        overview.vocabularyToConsolidate.length +
        overview.vocabularyInUse.length;
    final improving = overview.improving.length;
    final cards = [
      _StatCard(
        value: words,
        label: l.statWords,
        icon: Icons.menu_book_outlined,
        background: AppColors.feedbackBg,
        accent: AppColors.feedbackAccent,
      ),
      _StatCard(
        value: improving,
        label: l.statImproving,
        icon: Icons.trending_up,
        background: AppColors.mint,
        accent: AppColors.greenDark,
        achievement: improving > 0,
      ),
      _StatCard(
        value: overview.toReinforce.length,
        label: l.statReinforce,
        icon: Icons.track_changes,
        background: AppColors.amberBg,
        accent: AppColors.amberText,
      ),
      if (streak > 0)
        _StatCard(
          value: streak,
          label: l.statStreak,
          icon: Icons.local_fire_department,
          background: AppColors.terraBg,
          accent: AppColors.terraText,
          achievement: true,
        ),
    ];
    // Two per row; an odd one out takes the whole row.
    Widget row(int start) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: cards[start]),
          if (start + 1 < cards.length) ...[
            const SizedBox(width: 12),
            Expanded(child: cards[start + 1]),
          ],
        ],
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          row(i),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.background,
    required this.accent,
    this.achievement = false,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color background;
  final Color accent;

  /// A goal reached: the card gets a thin edge in its accent color.
  final bool achievement;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: AppCard(
        radius: AppRadius.tile,
        padding: const EdgeInsets.all(14),
        shadow: AppShadows.word,
        borderColor: achievement
            ? accent.withValues(alpha: 0.35)
            : AppColors.border,
        child: Row(
          children: [
            IconCircle(
              icon: icon,
              size: 42,
              iconSize: 22,
              background: background,
              foreground: accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: AppTextStyles.statNumber.copyWith(color: accent),
                  ),
                  Text(label, style: AppTextStyles.small),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
