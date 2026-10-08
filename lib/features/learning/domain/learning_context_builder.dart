import 'grammar_topic.dart';
import 'learning_context.dart';
import 'learning_error.dart';
import 'learning_state.dart';
import 'learning_summary.dart';
import 'user_vocabulary.dart';

/// Hard limits of what is shared with the AI. Deliberately small.
const maxPriorityTopics = 3;
const maxRecurringErrors = 3;
const maxVocabularyToReinforce = 5;
const maxPositiveSignals = 2;
const maxStretchTopics = 2;
const maxStretchWords = 3;

/// Anything whose priority has decayed below this is no longer worth
/// mentioning: a lone mistake stops counting after about six weeks without
/// being seen again (priority halves every 14 days, see `relevance.dart`).
const minContextPriority = 0.1;

/// A problem topic counts as *improving* once there is clear evidence of
/// correct use: at least this many successes and at least this mastery.
const improvedMinSuccesses = 3;
const improvedMinMastery = 0.6;

/// Vocabulary at or above this mastery is considered known: better candidates
/// are preferred.
const vocabularyKnownMastery = 0.7;

/// Longest learner-written fragment shared with the AI.
const maxContextTextLength = 40;

/// Selects the learner-memory slice to personalize the next AI turn.
///
/// Pure and deterministic: one summary in, one [LearningContext] out, using
/// the priorities already defined by the memory (`prioritizedErrors`,
/// `prioritizedTopics`, `prioritizedVocabulary`); there is no second scoring
/// system. Rules:
/// - **Priority topics**: topics with at least one error, not yet clearly
///   improving, still relevant at [now]; highest priority first.
/// - **Recurring errors**: only errors seen at least twice (a single sighting
///   is not a pattern), still relevant, and not in an area that is already
///   improving; highest priority first.
/// - **Vocabulary**: only words that are not known yet, most relevant first.
/// - **Positive signals**: problem topics with clear evidence of improvement,
///   strongest first.
///
/// Fragments written by the learner are only shared when they are short and
/// made of letters, spaces, apostrophes and hyphens (see [_clean]): they end
/// up inside the AI's instruction, so anything else, such as markup or text
/// that looks like an instruction, is dropped.
LearningContext buildLearningContext(
  LearnerLearningSummary summary, {
  required DateTime now,
  required String language,
}) {
  final recurringErrors = <ContextError>[];
  for (final e in selectRecurringErrors(summary, now)) {
    if (recurringErrors.length == maxRecurringErrors) break;
    final incorrect = _clean(e.original);
    final correct = _clean(e.corrected);
    if (incorrect == null || correct == null) continue;
    recurringErrors.add(ContextError(incorrect: incorrect, correct: correct));
  }

  final vocabulary = <String>[];
  for (final v in selectVocabularyToReinforce(summary, now, language)) {
    if (vocabulary.length == maxVocabularyToReinforce) break;
    final word = _clean(v.word);
    if (word == null || vocabulary.contains(word.toLowerCase())) continue;
    vocabulary.add(word.toLowerCase());
  }

  final priorityTopics = [
    for (final t in selectTopicsToReinforce(
      summary,
      now,
    ).take(maxPriorityTopics))
      t.topic,
  ];

  return LearningContext(
    priorityTopics: priorityTopics,
    topicStrategies: selectTopicStrategies(summary, priorityTopics),
    stretchWords: [
      for (final w in selectStretchWords(summary, language))
        if (_clean(w.word) case final word?
            when !vocabulary.contains(word.toLowerCase()))
          word.toLowerCase(),
    ].take(maxStretchWords).toList(),
    recurringErrors: recurringErrors,
    vocabularyToReinforce: vocabulary,
    positiveSignals: [
      for (final t in selectImprovingTopics(
        summary,
        now,
      ).take(maxPositiveSignals))
        t.topic,
    ],
  );
}

// ---------------------------------------------------------------------------
// Selection rules. They are the single definition of "what matters now" and
// are shared by everything that needs it (the AI context here, and the
// learner-facing overview), so no other layer re-implements them. Each returns
// the full, ordered candidates; callers apply their own limits.
// ---------------------------------------------------------------------------

/// A problem topic that is clearly getting better: it had errors, and now has
/// enough correct uses at a good enough rate.
bool isImprovingTopic(GrammarTopicProgress t) =>
    t.errorCount > 0 &&
    t.weightedSuccesses >= improvedMinSuccesses &&
    t.confidence >= improvedMinMastery;

/// Topics that were a problem and are now improving, strongest first.
List<GrammarTopicProgress> selectImprovingTopics(
  LearnerLearningSummary summary,
  DateTime now,
) => summary.grammarTopics.where(isImprovingTopic).toList()
  ..sort((a, b) {
    final bySuccesses = b.weightedSuccesses.compareTo(a.weightedSuccesses);
    return bySuccesses != 0
        ? bySuccesses
        : (b.lastSeenAt ?? now).compareTo(a.lastSeenAt ?? now);
  });

/// Topics that still need reinforcement: at least one error, not improving
/// yet, still relevant at [now]; highest priority first.
List<GrammarTopicProgress> selectTopicsToReinforce(
  LearnerLearningSummary summary,
  DateTime now,
) => [
  for (final t in summary.prioritizedTopics(now))
    if (!isImprovingTopic(t) && t.priority(now) >= minContextPriority) t,
];

/// Mistakes seen at least twice, still relevant, and not in an area that is
/// already improving; highest priority first.
List<LearningError> selectRecurringErrors(
  LearnerLearningSummary summary,
  DateTime now,
) {
  final improving = {
    for (final t in summary.grammarTopics)
      if (isImprovingTopic(t)) t.topic,
  };
  return [
    for (final e in summary.prioritizedErrors(now))
      if (e.isRecurring &&
          e.priority(now) >= minContextPriority &&
          !improving.contains(e.grammarTopic))
        e,
  ];
}

/// How demanding the practice of each topic should be: the strategy of the
/// state of each of [priorityTopics] (as they come), then the topics already
/// consolidated (at most [maxStretchTopics], the best proven first), which are
/// ready for more. Derived from the topic's own evidence; the declared level
/// plays no part. Stable: same memory, same order.
Map<GrammarTopic, AdaptationStrategy> selectTopicStrategies(
  LearnerLearningSummary summary,
  List<GrammarTopic> priorityTopics,
) {
  final byTopic = {for (final t in summary.grammarTopics) t.topic: t};
  final strategies = <GrammarTopic, AdaptationStrategy>{};
  for (final topic in priorityTopics) {
    final progress = byTopic[topic];
    if (progress != null) {
      strategies[topic] = progress.learningState.strategy;
    }
  }
  final consolidated =
      [
        for (final t in summary.grammarTopics)
          if (t.learningState == LearningState.consolidated &&
              !strategies.containsKey(t.topic))
            t,
      ]..sort((a, b) {
        final byProof = b.proof.productionSuccesses.compareTo(
          a.proof.productionSuccesses,
        );
        return byProof != 0 ? byProof : a.topic.name.compareTo(b.topic.name);
      });
  for (final t in consolidated.take(maxStretchTopics)) {
    strategies[t.topic] = t.learningState.strategy;
  }
  return strategies;
}

/// Words of the learning [language] the learner already produces well
/// (consolidated), best proven first.
List<UserVocabulary> selectStretchWords(
  LearnerLearningSummary summary,
  String language,
) =>
    [
      for (final v in summary.vocabularyItems)
        if (v.language == language &&
            v.learningState == LearningState.consolidated)
          v,
    ]..sort((a, b) {
      final byProof = b.proof.productionSuccesses.compareTo(
        a.proof.productionSuccesses,
      );
      return byProof != 0 ? byProof : a.id.compareTo(b.id);
    });

/// Words of the learning [language] (ISO code) not known yet and still
/// relevant, most relevant first.
List<UserVocabulary> selectVocabularyToReinforce(
  LearnerLearningSummary summary,
  DateTime now,
  String language,
) => [
  for (final v in summary.prioritizedVocabulary(now))
    if (v.language == language &&
        v.confidence < vocabularyKnownMastery &&
        v.priority(now) >= minContextPriority)
      v,
];

final _safeFragment = RegExp(r"^[\p{L}][\p{L}\s'’-]*$", unicode: true);

/// A learner-written fragment made safe to place in the AI's instruction, or
/// `null` to drop it: it must be short and consist only of letters, spaces,
/// apostrophes and hyphens (no digits, quotes or markup). Control characters
/// such as line breaks are rejected rather than normalized: real patterns are
/// built from words joined by single spaces and never contain them.
///
/// Residual limit: plain words cannot be told apart from a genuine mistake, so
/// a learner can in principle shape their own tutor's instruction with a
/// short phrase. That only affects their own local session.
String? _clean(String text) {
  if (text.contains(RegExp(r'[\u0000-\u001F\u007F  ]'))) return null;
  final trimmed = text.trim().replaceAll(RegExp(r' +'), ' ');
  if (trimmed.isEmpty || trimmed.length > maxContextTextLength) return null;
  return _safeFragment.hasMatch(trimmed) ? trimmed : null;
}
