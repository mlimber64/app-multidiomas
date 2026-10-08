import '../../daily_routine/domain/daily_routine.dart';
import '../../profile/domain/user_learning_profile.dart';
import 'learning_guidance.dart';

/// Explains the routine's next step. A pure view over an already-made
/// [DailyRoutine]: it ranks nothing, reads no storage or engine and writes
/// nothing. The routine decides *what*; this only says *why*.
class LearningGuidanceResolver {
  const LearningGuidanceResolver();

  /// `null` when the routine has nothing to practice.
  ///
  /// [goals] is only used to explain a mission that has no topics: the planner
  /// then built it from the learner's goals, taking the first in
  /// [LearningGoal] declaration order, and this repeats that same stable
  /// choice to name it.
  LearningGuidance? resolve(
    DailyRoutine routine, {
    Set<LearningGoal> goals = const {},
  }) {
    if (routine.isEmpty) return null;
    final step = routine.currentStep;
    if (step == null) {
      return const LearningGuidance(
        kind: GuidanceKind.completed,
        reason: RoutineDone(),
      );
    }
    return switch (step) {
      1 => LearningGuidance(
        kind: GuidanceKind.review,
        step: 1,
        reason: ReviewsDue(routine.step1.itemIds.length),
      ),
      2 => LearningGuidance(
        kind: GuidanceKind.talk,
        step: 2,
        reason: _missionReason(routine.step2, goals),
      ),
      _ => LearningGuidance(
        kind: GuidanceKind.vocabulary,
        step: 3,
        reason: WordsToReinforce(routine.step3.vocabularyIds.length),
      ),
    };
  }

  GuidanceReason _missionReason(ScenarioStep step, Set<LearningGoal> goals) {
    final topics = step.mission?.targetTopics ?? const [];
    if (topics.isNotEmpty) return RepeatedDifficulty(topics.first);
    for (final goal in LearningGoal.values) {
      if (goals.contains(goal)) return MatchesGoal(goal);
    }
    return const GenericMission();
  }
}
