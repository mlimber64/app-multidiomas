import '../../learning/domain/grammar_topic.dart';
import '../../profile/domain/user_learning_profile.dart';

/// What the learner is being pointed at. `completed` means there is nothing
/// left in today's routine.
enum GuidanceKind { review, talk, vocabulary, completed }

/// Why the routine's current step is worth doing now. Language neutral: the
/// interface decides how to say it.
sealed class GuidanceReason {
  const GuidanceReason();
}

/// Step 1: exercises the routine already chose to review.
final class ReviewsDue extends GuidanceReason {
  const ReviewsDue(this.count);

  final int count;

  @override
  bool operator ==(Object other) => other is ReviewsDue && other.count == count;

  @override
  int get hashCode => Object.hash(ReviewsDue, count);
}

/// Step 2: the mission practices this topic (the first of the mission's own).
final class RepeatedDifficulty extends GuidanceReason {
  const RepeatedDifficulty(this.topic);

  final GrammarTopic topic;

  @override
  bool operator ==(Object other) =>
      other is RepeatedDifficulty && other.topic == topic;

  @override
  int get hashCode => Object.hash(RepeatedDifficulty, topic);
}

/// Step 2: the mission has no topics; it was built from the learner's goals.
final class MatchesGoal extends GuidanceReason {
  const MatchesGoal(this.goal);

  final LearningGoal goal;

  @override
  bool operator ==(Object other) => other is MatchesGoal && other.goal == goal;

  @override
  int get hashCode => Object.hash(MatchesGoal, goal);
}

/// Step 2: a mission with neither topics nor goals behind it. The interface
/// just names the situation.
final class GenericMission extends GuidanceReason {
  const GenericMission();

  @override
  bool operator ==(Object other) => other is GenericMission;

  @override
  int get hashCode => (GenericMission).hashCode;
}

/// Step 3: words the routine already chose to reinforce.
final class WordsToReinforce extends GuidanceReason {
  const WordsToReinforce(this.count);

  final int count;

  @override
  bool operator ==(Object other) =>
      other is WordsToReinforce && other.count == count;

  @override
  int get hashCode => Object.hash(WordsToReinforce, count);
}

/// The routine is finished.
final class RoutineDone extends GuidanceReason {
  const RoutineDone();

  @override
  bool operator ==(Object other) => other is RoutineDone;

  @override
  int get hashCode => (RoutineDone).hashCode;
}

/// The next thing to practice, derived from today's routine. Never stored.
class LearningGuidance {
  const LearningGuidance({required this.kind, required this.reason, this.step});

  final GuidanceKind kind;

  /// The routine step (1, 2 or 3) this points at; `null` once completed.
  final int? step;
  final GuidanceReason reason;

  @override
  bool operator ==(Object other) =>
      other is LearningGuidance &&
      other.kind == kind &&
      other.step == step &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(kind, step, reason);
}
