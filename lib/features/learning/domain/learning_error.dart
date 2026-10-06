import 'grammar_topic.dart';
import 'language_scope.dart';
import 'relevance.dart';

enum LearningErrorCategory {
  grammar,
  vocabulary,
  agreement,
  preposition,
  wordOrder,
  spelling,
  other,
}

/// A mistake pattern the learner makes, accumulated over time: the same
/// mistake seen again increases [frequency] instead of adding a record.
///
/// [id] is the normalized pattern key (see `ErrorPattern`), so identity and
/// de-duplication are the same thing.
class LearningError {
  const LearningError({
    required this.id,
    required this.category,
    required this.original,
    required this.corrected,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.confidence,
    this.explanation = '',
    this.grammarTopic,
    this.frequency = 1,
    this.language = legacyLanguageCode,
  });

  /// An error is "recurring" from this many occurrences.
  static const recurringThreshold = 2;

  final String id;
  final LearningErrorCategory category;
  final String original;
  final String corrected;

  /// Latest non-empty explanation seen.
  final String explanation;

  /// `null` when no reliable inference exists.
  final GrammarTopic? grammarTopic;
  final int frequency;

  /// Language the mistake was made in (ISO code); see [legacyLanguageCode].
  /// The [id] is scoped by it (see `scopedId`).
  final String language;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;

  /// How sure we are that this is a real mistake (0.0..1.0), not mastery:
  /// 0.9 = explicit correction by the AI. Kept as the highest seen.
  final double confidence;

  /// Recurring means seen at least [recurringThreshold] times (2): one
  /// sighting may be a slip, two is a pattern.
  bool get isRecurring => frequency >= recurringThreshold;

  /// How much this error deserves attention now, to rank problems. Derived,
  /// never stored: `frequency × confidence × recency`, so a mistake made five
  /// times last week outranks one made once a month ago. Comparable only
  /// between errors evaluated at the same [now].
  double priority(DateTime now) =>
      frequency * confidence * recencyWeight(lastSeenAt, now);

  /// Folds a new sighting of the same mistake (same [id]) into this record.
  /// The first-seen category and display text are kept.
  LearningError merge(LearningError occurrence) {
    assert(occurrence.id == id, 'Only the same error pattern can be merged');
    return LearningError(
      id: id,
      category: category,
      original: original,
      corrected: corrected,
      explanation: occurrence.explanation.isNotEmpty
          ? occurrence.explanation
          : explanation,
      grammarTopic: grammarTopic ?? occurrence.grammarTopic,
      language: language,
      frequency: frequency + occurrence.frequency,
      firstSeenAt: occurrence.firstSeenAt.isBefore(firstSeenAt)
          ? occurrence.firstSeenAt
          : firstSeenAt,
      lastSeenAt: occurrence.lastSeenAt.isAfter(lastSeenAt)
          ? occurrence.lastSeenAt
          : lastSeenAt,
      confidence: occurrence.confidence > confidence
          ? occurrence.confidence
          : confidence,
    );
  }
}
