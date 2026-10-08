import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/ui/ui.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/empty_state_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../daily_routine/presentation/practice_activity.dart';
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
        if (overview.isEmpty)
          EmptyStateCard(
            icon: Icons.explore_outlined,
            title: l.progressEmptyTitle,
            message: l.progressEmptyBody,
            action: PrimaryButton(
              label: l.letsTalk,
              onPressed: () => context.go(AppRoutes.conversation),
            ),
          )
        else ...[
          if (overview.hasTopics) ...[
            _RingHero(overview: overview),
            const SizedBox(height: 14),
          ],
          const _WeekCard(),
          const SizedBox(height: 14),
          _StatRow(overview: overview),
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

// NUEVO: la semana (lunes a domingo) con los días en que hubo práctica,
// derivados de las rutinas diarias guardadas.
class _WeekCard extends ConsumerWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(practiceActivityProvider).value;
    if (activity == null) return const SizedBox.shrink();
    final l = context.l10n;
    final initials = l.weekInitials.split(',');
    final count = activity.week.where((d) => d).length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.progressWeekTitle, style: AppTextStyles.rowTitle),
          const SizedBox(height: 12),
          Semantics(
            label: l.weekSemantics(count),
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 7; i++)
                  _DayDot(
                    initial: initials[i],
                    practiced: activity.week[i],
                    today: i == activity.todayIndex,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.initial,
    required this.practiced,
    required this.today,
  });

  final String initial;
  final bool practiced;
  final bool today;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: practiced ? AppColors.green : AppColors.divider,
            shape: BoxShape.circle,
            border: today ? Border.all(color: AppColors.green, width: 2) : null,
          ),
          child: practiced
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          initial,
          style: AppTextStyles.small.copyWith(
            fontWeight: today ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// NUEVO: tres números reales de la memoria de aprendizaje.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.overview});

  final LearningOverview overview;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final words =
        overview.vocabularyToConsolidate.length +
        overview.vocabularyInUse.length;
    final stats = [
      (words, l.statWords),
      (overview.improving.length, l.statImproving),
      (overview.toReinforce.length, l.statReinforce),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                label: '${stats[i].$2}: ${stats[i].$1}',
                excludeSemantics: true,
                child: AppCard(
                  radius: AppRadius.tile,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${stats[i].$1}', style: AppTextStyles.statNumber),
                      const SizedBox(height: 2),
                      Text(
                        stats[i].$2,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.small,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
