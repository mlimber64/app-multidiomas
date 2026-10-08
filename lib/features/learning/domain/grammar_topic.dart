import 'language_scope.dart';
import 'learning_state.dart';
import 'practice_evidence.dart';
import 'relevance.dart';

/// Grammar areas the memory can track. Deliberately small; add values as
/// inference and exercises need them (stored by name, so adding is safe).
enum GrammarTopic {
  passatoProssimo,
  essereVsAvere,
  prepositions,
  articles,
  gender,
  plural,
  agreement,
  pronouns,
  verbConjugation,
  wordOrder,

  // English (a topic belongs to the language whose rules produce it; the
  // generic ones above, like articles, are shared by name and kept apart per
  // language by the memory).
  toBe,
  presentContinuous,
  pastSimple,
  presentPerfect,
  thirdPersonSingular,

  // French.
  etreVsAvoir,
  passeCompose,

  // Portuguese.
  serVsEstar, // Spanish too.
  // German.
  habenVsSein,
  perfekt,
  cases,

  // Spanish.
  porVsPara,

  // Mandarin Chinese.
  measureWords,
  structuralParticles,
  aspectParticles,
  negation,
}

/// How the learner is doing on one [GrammarTopic].
///
/// All counts are occurrences observed in the learner's own writing, one per
/// message at most:
/// - [exposureCount]: times the topic was involved. A correction received
///   counts as an exposure (and an error); a detected correct use counts as an
///   exposure (and a success). So `exposure >= errors + successes`.
/// - [errorCount]: of those, times it was used wrongly.
/// - [successfulUseCount]: of those, times it was used correctly.
class GrammarTopicProgress {
  const GrammarTopicProgress({
    required this.topic,
    this.language = legacyLanguageCode,
    this.exposureCount = 0,
    this.errorCount = 0,
    this.successfulUseCount = 0,
    this.lastSeenAt,
    double? weightedExposure,
    double? weightedErrors,
    double? weightedSuccesses,
    this.proof = PracticeProof.empty,
  }) : _weightedExposure = weightedExposure,
       _weightedErrors = weightedErrors,
       _weightedSuccesses = weightedSuccesses;

  final double? _weightedExposure;
  final double? _weightedErrors;
  final double? _weightedSuccesses;

  /// The counts above weighted by how strong each piece of evidence was (see
  /// `EvidenceStrength`). A message in conversation counts 1, so for a topic
  /// only ever seen in conversation (and for every record written before
  /// practice evidence existed) they equal the plain counts.
  double get weightedExposure => _weightedExposure ?? exposureCount.toDouble();
  double get weightedErrors => _weightedErrors ?? errorCount.toDouble();
  double get weightedSuccesses =>
      _weightedSuccesses ?? successfulUseCount.toDouble();

  bool get hasWeightedCounts =>
      _weightedExposure != null ||
      _weightedErrors != null ||
      _weightedSuccesses != null;

  final GrammarTopic topic;

  /// What the learner has demonstrated on this topic, apart from recognition
  /// and production (see `PracticeProof`). Empty for a topic that only has
  /// history from before it existed.
  final PracticeProof proof;

  /// Where the learner stands on this topic: derived, never stored. A mistake
  /// they made in conversation counts as a difficulty even without a ledger.
  LearningState get learningState =>
      proof.stateOf(hadDifficulty: errorCount > 0);

  /// Language this progress belongs to (ISO code); see [legacyLanguageCode].
  final String language;
  final int exposureCount;
  final int errorCount;
  final int successfulUseCount;
  final DateTime? lastSeenAt;

  /// Approximate mastery in 0.0..1.0 = weighted successes / weighted
  /// exposures, and 0.0 while nothing has been observed. Intentionally naive:
  /// 8 exposures with 4 successes = 0.5; one error then two correct uses =
  /// 2/3; a typed answer in review counts less than a message in conversation
  /// and a picked option less than a typed answer. Clamped, so even
  /// inconsistent stored counts stay in range. It is derived (not stored), so
  /// it can be replaced by a better estimator without migrating data.
  double get confidence => weightedExposure <= 0
      ? 0
      : (weightedSuccesses / weightedExposure).clamp(0.0, 1.0);

  /// How much this topic deserves practice now, to rank problems. Derived:
  /// `errors × (1 − mastery) × recency`. Topics with many errors and few
  /// successes rank high; every detected success lowers it, a little or a lot
  /// depending on how strong the evidence was; topics with no errors, or never
  /// seen, are 0. Comparable only at the same [now].
  double priority(DateTime now) {
    final seen = lastSeenAt;
    if (seen == null) return 0;
    return weightedErrors * (1 - confidence) * recencyWeight(seen, now);
  }

  GrammarTopicProgress recordExposure({
    required DateTime at,
    bool wasError = false,
  }) => practice(
    at: at,
    success: false,
    exposureOnly: !wasError,
    occurrence: true,
  );

  GrammarTopicProgress recordSuccess({required DateTime at}) =>
      practice(at: at, success: true, occurrence: true);

  /// Takes one piece of practice into the progress, [weight] times as much as
  /// a full occurrence in conversation.
  ///
  /// An [occurrence] is something the learner wrote (it moves the plain counts
  /// and the last time seen); practice that is not (a review) only moves the
  /// weighted counts. [exposureOnly] adds to the exposures alone.
  GrammarTopicProgress practice({
    required DateTime at,
    required bool success,
    double weight = 1,
    bool occurrence = false,
    bool exposureOnly = false,
    PracticeEvidenceType? evidenceType,
    String? context,
  }) {
    final failed = !success && !exposureOnly;
    return GrammarTopicProgress(
      topic: topic,
      language: language,
      exposureCount: exposureCount + (occurrence ? 1 : 0),
      errorCount: errorCount + (occurrence && failed ? 1 : 0),
      successfulUseCount: successfulUseCount + (occurrence && success ? 1 : 0),
      lastSeenAt: occurrence ? _latest(lastSeenAt, at) : lastSeenAt,
      weightedExposure: weightedExposure + weight,
      weightedErrors: weightedErrors + (failed ? weight : 0),
      weightedSuccesses: weightedSuccesses + (success ? weight : 0),
      // Only practice that says what the learner had to do reaches the ledger.
      proof: evidenceType == null
          ? proof
          : proof.record(
              type: evidenceType,
              success: success,
              context: context,
            ),
    );
  }

  static DateTime _latest(DateTime? a, DateTime b) =>
      a != null && a.isAfter(b) ? a : b;
}
