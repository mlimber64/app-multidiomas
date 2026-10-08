import 'grammar_topic.dart';
import 'learning_state.dart';

/// A mistake worth keeping in mind, reduced to what a teacher needs: what the
/// learner tends to write and the correct form. No ids, dates or counts.
class ContextError {
  const ContextError({required this.incorrect, required this.correct});

  final String incorrect;
  final String correct;
}

/// The small, selected slice of the learner's memory that may be handed to the
/// AI to personalize a conversation. It is a *view*, not a copy: it holds no
/// ids, timestamps, frequencies, confidences or storage details, only
/// pedagogical content, and only a handful of items (see
/// `buildLearningContext` for the limits and the selection rules).
///
/// It complements, and never replaces, what the learner declared
/// (`UserLearningProfile`).
class LearningContext {
  const LearningContext({
    this.priorityTopics = const <GrammarTopic>[],
    this.recurringErrors = const <ContextError>[],
    this.vocabularyToReinforce = const <String>[],
    this.positiveSignals = const <GrammarTopic>[],
    this.topicStrategies = const <GrammarTopic, AdaptationStrategy>{},
    this.stretchWords = const <String>[],
  });

  /// Nothing worth sending: the AI behaves exactly as without memory.
  static const empty = LearningContext();

  /// Grammar areas that still need reinforcement.
  final List<GrammarTopic> priorityTopics;

  /// Mistakes the learner has repeated.
  final List<ContextError> recurringErrors;

  /// Words that were corrected and are not mastered yet.
  final List<String> vocabularyToReinforce;

  /// Areas that were a problem and are now clearly improving: the AI should
  /// not simplify or over-correct there.
  final List<GrammarTopic> positiveSignals;

  /// How demanding the practice of each topic named here should be, by the
  /// state of that topic alone (see `LearningState`): the topics to reinforce,
  /// plus those already consolidated. The learner's overall level is not
  /// touched. In a stable order.
  final Map<GrammarTopic, AdaptationStrategy> topicStrategies;

  /// Words the learner already produces well: to be used in new contexts.
  final List<String> stretchWords;

  bool get isEmpty =>
      priorityTopics.isEmpty &&
      recurringErrors.isEmpty &&
      vocabularyToReinforce.isEmpty &&
      positiveSignals.isEmpty &&
      topicStrategies.isEmpty &&
      stretchWords.isEmpty;
}
