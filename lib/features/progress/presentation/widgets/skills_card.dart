import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../domain/skill_metrics.dart';
import 'radar_chart.dart';

/// "Tus áreas": the learner's strengths and weak spots at a glance. With three
/// or more areas there is a radar chart; always, a list under it says each one
/// in words (`3 de 8 palabras en uso`), because the chart is only a picture
/// and the app shows counts, never percentages.
class SkillsCard extends StatelessWidget {
  const SkillsCard({required this.metrics, super.key});

  final List<SkillMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (metrics.isEmpty) return const SizedBox.shrink();
    return AppCard(
      shadow: AppShadows.word,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.progressSkillsTitle, style: AppTextStyles.rowTitle),
          const SizedBox(height: 2),
          Text(l.progressSkillsSub, style: AppTextStyles.small),
          if (metrics.length >= 3) ...[
            const SizedBox(height: AppSpacing.sm),
            RadarChart(
              values: [for (final m in metrics) m.value],
              labels: [for (final m in metrics) m.area.label(l)],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          for (final m in metrics) _SkillRow(metric: m),
          if (metrics.length < 3) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.progressSkillsMore,
              style: AppTextStyles.small.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.metric});

  final SkillMetric metric;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (icon, background, foreground) = metric.area.look;
    final detail = metric.area.detail(l, metric.done, metric.total);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Semantics(
        label: '${metric.area.label(l)}: $detail',
        excludeSemantics: true,
        child: Row(
          children: [
            IconCircle(
              icon: icon,
              size: 34,
              iconSize: 18,
              background: background,
              foreground: foreground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metric.area.label(l), style: AppTextStyles.rowTitle),
                  const SizedBox(height: 2),
                  Text(detail, style: AppTextStyles.small),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: metric.value,
                      minHeight: 6,
                      backgroundColor: AppColors.track,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How each area is called and drawn.
extension SkillAreaLabel on SkillArea {
  String label(AppLocalizations l) => switch (this) {
    SkillArea.vocabulary => l.skillVocabulary,
    SkillArea.grammar => l.skillGrammar,
    SkillArea.consistency => l.skillConsistency,
  };

  String detail(AppLocalizations l, int done, int total) => switch (this) {
    SkillArea.vocabulary => l.skillVocabularyDetail(done, total),
    SkillArea.grammar => l.skillGrammarDetail(done, total),
    SkillArea.consistency => l.skillConsistencyDetail(done, total),
  };

  (IconData, Color, Color) get look => switch (this) {
    SkillArea.vocabulary => (
      Icons.menu_book_outlined,
      AppColors.feedbackBg,
      AppColors.feedbackAccent,
    ),
    SkillArea.grammar => (
      Icons.spellcheck,
      AppColors.mint,
      AppColors.greenDark,
    ),
    SkillArea.consistency => (
      Icons.local_fire_department,
      AppColors.amberBg,
      AppColors.amberText,
    ),
  };
}
