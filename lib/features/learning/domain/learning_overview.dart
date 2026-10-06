import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'language_learning_rules.dart';
import 'learning_context_builder.dart';
import 'learning_error.dart';
import 'learning_summary.dart';
import 'user_vocabulary.dart';

/// How many items each learner-facing list shows at most. The memory can hold
/// more; the screens never dump it.
const overviewMaxTopics = 5;
const overviewMaxRecurringErrors = 5;
const overviewMaxRelatedErrors = 3;
const overviewMaxVocabularyPerSection = 50;

enum TopicStanding {
  /// Was a problem and now shows clear evidence of improvement.
  improving,

  /// Still needs reinforcement.
  toReinforce,
}

/// A mistake as the learner should see it: what they tend to write, the
/// correct form, and where it belongs. No ids, dates or counts.
class ErrorView {
  const ErrorView({
    required this.incorrect,
    required this.correct,
    required this.isRecurring,
    this.topic,
  });

  final String incorrect;
  final String correct;

  /// Seen more than once (see `LearningError.recurringThreshold`).
  final bool isRecurring;
  final GrammarTopic? topic;
}

/// A grammar topic as the learner should see it.
class TopicView {
  const TopicView({
    required this.topic,
    required this.standing,
    required this.successfulUses,
    required this.appearances,
    this.relatedErrors = const <ErrorView>[],
    this.relatedTopics = const <GrammarTopic>[],
  });

  final GrammarTopic topic;
  final TopicStanding standing;

  /// Times the learner was seen using it correctly / times it came up in what
  /// they wrote (correct or not). Real evidence only: both come straight from
  /// the memory.
  final int successfulUses;
  final int appearances;

  /// Mistakes that belong to this topic, most relevant first.
  final List<ErrorView> relatedErrors;

  /// Other topics that share those mistakes (for example the passato prossimo
  /// and the choice of essere or avere).
  final List<GrammarTopic> relatedTopics;

  /// At least one correct use has been seen.
  bool get hasProgress => successfulUses > 0;

  /// Share of appearances that were correct, 0.0..1.0 (the one honest number
  /// behind a progress bar: "4 correct out of 8").
  double get correctShare =>
      appearances == 0 ? 0 : (successfulUses / appearances).clamp(0.0, 1.0);
}

/// A word as the learner should see it.
class VocabularyView {
  const VocabularyView({
    required this.word,
    required this.language,
    required this.successfulUses,
    required this.isConsolidated,
    this.meaning,
  });

  final String word;
  final String language;
  final String? meaning;
  final int successfulUses;

  /// Used correctly often enough to count as in use (same threshold the AI
  /// context uses to stop reinforcing a word). Never "learned": the evidence
  /// is conservative and cannot prove that.
  final bool isConsolidated;

  bool get hasBeenUsedCorrectly => successfulUses > 0;
}

/// Everything the learner-facing screens need about their learning, derived
/// from the memory by [buildLearningOverview]. Display data only: it holds no
/// storage concerns and no rules of its own.
class LearningOverview {
  const LearningOverview({
    this.improving = const <TopicView>[],
    this.toReinforce = const <TopicView>[],
    this.recurringErrors = const <ErrorView>[],
    this.vocabularyToConsolidate = const <VocabularyView>[],
    this.vocabularyInUse = const <VocabularyView>[],
  });

  /// Nothing to show yet (memory empty, or only data that is not relevant).
  static const empty = LearningOverview();

  final List<TopicView> improving;
  final List<TopicView> toReinforce;
  final List<ErrorView> recurringErrors;
  final List<VocabularyView> vocabularyToConsolidate;
  final List<VocabularyView> vocabularyInUse;

  bool get hasTopics => improving.isNotEmpty || toReinforce.isNotEmpty;
  bool get hasVocabulary =>
      vocabularyToConsolidate.isNotEmpty || vocabularyInUse.isNotEmpty;

  bool get isEmpty => !hasTopics && recurringErrors.isEmpty && !hasVocabulary;
}

/// Builds what the screens show from the memory, reusing the selection rules
/// that also feed the AI context (`selectImprovingTopics`,
/// `selectTopicsToReinforce`, `selectRecurringErrors`) so there is a single
/// definition of what matters now. Pure and deterministic.
LearningOverview buildLearningOverview(
  LearnerLearningSummary summary, {
  required DateTime now,
  required LanguageLearningRules rules,
}) {
  // Errors with the topics they belong to, once, most relevant first.
  final errors = [
    for (final e in summary.prioritizedErrors(now)) (e, _topicsOf(e, rules)),
  ];

  TopicView viewOf(GrammarTopicProgress p, TopicStanding standing) {
    final related = [
      for (final (e, topics) in errors)
        if (topics.contains(p.topic)) e,
    ];
    final relatedTopics = <GrammarTopic>[];
    for (final (e, topics) in errors) {
      if (!related.contains(e)) continue;
      for (final t in topics) {
        if (t != p.topic && !relatedTopics.contains(t)) relatedTopics.add(t);
      }
    }
    return TopicView(
      topic: p.topic,
      standing: standing,
      successfulUses: p.successfulUseCount,
      appearances: p.exposureCount,
      relatedErrors: [
        for (final e in related.take(overviewMaxRelatedErrors)) _errorView(e),
      ],
      relatedTopics: relatedTopics,
    );
  }

  final vocabulary = summary.prioritizedVocabulary(now);
  VocabularyView wordView(UserVocabulary v) => VocabularyView(
    word: v.word,
    language: v.language,
    meaning: v.meaning,
    successfulUses: v.successfulUseCount,
    isConsolidated: v.confidence >= vocabularyKnownMastery,
  );

  return LearningOverview(
    improving: [
      for (final p in selectImprovingTopics(
        summary,
        now,
      ).take(overviewMaxTopics))
        viewOf(p, TopicStanding.improving),
    ],
    toReinforce: [
      for (final p in selectTopicsToReinforce(
        summary,
        now,
      ).take(overviewMaxTopics))
        viewOf(p, TopicStanding.toReinforce),
    ],
    recurringErrors: [
      for (final e in selectRecurringErrors(
        summary,
        now,
      ).take(overviewMaxRecurringErrors))
        _errorView(e),
    ],
    vocabularyToConsolidate: [
      for (final v in vocabulary)
        if (v.confidence < vocabularyKnownMastery) wordView(v),
    ].take(overviewMaxVocabularyPerSection).toList(),
    vocabularyInUse:
        ([
              for (final v in vocabulary)
                if (v.confidence >= vocabularyKnownMastery) v,
            ]..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt)))
            .map(wordView)
            .take(overviewMaxVocabularyPerSection)
            .toList(),
  );
}

ErrorView _errorView(LearningError e) => ErrorView(
  incorrect: e.original,
  correct: e.corrected,
  isRecurring: e.isRecurring,
  topic: e.grammarTopic,
);

/// The topics a stored mistake belongs to: its recorded topic plus whatever
/// the deterministic inference finds for its wording (one pattern can touch
/// several topics, e.g. essere/avere and the passato prossimo).
Set<GrammarTopic> _topicsOf(LearningError e, LanguageLearningRules rules) {
  final topics = <GrammarTopic>{?e.grammarTopic};
  final pattern = ErrorPattern.from(e.original, e.corrected);
  final inferred = pattern == null ? null : rules.inferGrammarTopics(pattern);
  if (inferred != null) topics.addAll(inferred.topics);
  return topics;
}
