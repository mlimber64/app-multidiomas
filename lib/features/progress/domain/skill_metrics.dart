import '../../daily_routine/presentation/practice_activity.dart';
import '../../learning/domain/learning_overview.dart';

/// The areas of the language the app can really measure today. Fluency and
/// pronunciation are not here: the app has no measure of either, and a chart
/// that invented them would be a chart of nothing.
enum SkillArea { vocabulary, grammar, consistency }

/// How the learner stands in one [SkillArea], as `done` of `total` real
/// things (never a percentage: the app shows counts).
class SkillMetric {
  const SkillMetric({
    required this.area,
    required this.done,
    required this.total,
  });

  final SkillArea area;
  final int done;
  final int total;

  /// `done / total` in 0..1; 0 when there is nothing to count.
  double get value => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);
}

/// The metrics there is evidence for, in a fixed order:
/// - vocabulary: words in use out of every word met;
/// - grammar: areas improving out of the areas with data;
/// - consistency: days practiced out of the days of this week so far.
/// An area with nothing behind it (no words yet, no area with data) is left
/// out, so what is drawn is always something the memory can back up.
List<SkillMetric> buildSkillMetrics(
  LearningOverview overview,
  PracticeActivity? activity,
) {
  final words =
      overview.vocabularyToConsolidate.length + overview.vocabularyInUse.length;
  final topics = overview.improving.length + overview.toReinforce.length;
  return [
    if (words > 0)
      SkillMetric(
        area: SkillArea.vocabulary,
        done: overview.vocabularyInUse.length,
        total: words,
      ),
    if (topics > 0)
      SkillMetric(
        area: SkillArea.grammar,
        done: overview.improving.length,
        total: topics,
      ),
    if (activity != null)
      SkillMetric(
        area: SkillArea.consistency,
        done: activity.week
            .take(activity.todayIndex + 1)
            .where((practiced) => practiced)
            .length,
        total: activity.todayIndex + 1,
      ),
  ];
}
