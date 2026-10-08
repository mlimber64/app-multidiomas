import '../../../l10n/l10n.dart';
import '../../learning/presentation/learning_labels.dart';
import '../../profile/presentation/profile_labels.dart';
import '../domain/learning_guidance.dart';

/// Interface copy for guidance, in the current UI language. Kept out of the
/// domain so the domain stays free of text.
extension GuidanceKindLabel on GuidanceKind {
  /// The action's name: the same as the routine step it points at.
  String action(AppLocalizations l) => switch (this) {
    GuidanceKind.review => l.quickReview,
    GuidanceKind.talk => l.chatTitle,
    GuidanceKind.vocabulary => l.routineStep3Title,
    GuidanceKind.completed => l.guidanceCompleted,
  };
}

extension GuidanceReasonLabel on GuidanceReason {
  /// One sentence saying why. [fallback] is the text for a [GenericMission]
  /// (the mission's own description), which has no reason of its own.
  String text(AppLocalizations l, {String fallback = ''}) => switch (this) {
    ReviewsDue(:final count) => l.guidanceReasonReviews(count),
    RepeatedDifficulty(:final topic) => l.guidanceReasonTopic(topic.label(l)),
    MatchesGoal(:final goal) => l.guidanceReasonGoal(goal.label(l)),
    GenericMission() => fallback,
    WordsToReinforce(:final count) => l.guidanceReasonWords(count),
    RoutineDone() => l.routineCompletedBody,
  };
}
