import 'language_scope.dart';
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
  });

  final GrammarTopic topic;

  /// Language this progress belongs to (ISO code); see [legacyLanguageCode].
  final String language;
  final int exposureCount;
  final int errorCount;
  final int successfulUseCount;
  final DateTime? lastSeenAt;

  /// Approximate mastery in 0.0..1.0 = successful uses / exposures, and 0.0
  /// while nothing has been observed. Intentionally naive: 8 exposures with 4
  /// successes = 0.5; one error then two correct uses = 2/3. Clamped, so even
  /// inconsistent stored counts stay in range. It is derived (not stored), so
  /// it can be replaced by a better estimator without migrating data.
  double get confidence => exposureCount == 0
      ? 0
      : (successfulUseCount / exposureCount).clamp(0.0, 1.0);

  /// How much this topic deserves practice now, to rank problems. Derived:
  /// `errors × (1 − mastery) × recency`. Topics with many errors and few
  /// successes rank high; every detected success lowers it; topics with no
  /// errors, or never seen, are 0. Comparable only at the same [now].
  double priority(DateTime now) {
    final seen = lastSeenAt;
    if (seen == null) return 0;
    return errorCount * (1 - confidence) * recencyWeight(seen, now);
  }

  GrammarTopicProgress recordExposure({
    required DateTime at,
    bool wasError = false,
  }) => GrammarTopicProgress(
    topic: topic,
    language: language,
    exposureCount: exposureCount + 1,
    errorCount: errorCount + (wasError ? 1 : 0),
    successfulUseCount: successfulUseCount,
    lastSeenAt: _latest(lastSeenAt, at),
  );

  GrammarTopicProgress recordSuccess({required DateTime at}) =>
      GrammarTopicProgress(
        topic: topic,
        language: language,
        exposureCount: exposureCount + 1,
        errorCount: errorCount,
        successfulUseCount: successfulUseCount + 1,
        lastSeenAt: _latest(lastSeenAt, at),
      );

  static DateTime _latest(DateTime? a, DateTime b) =>
      a != null && a.isAfter(b) ? a : b;
}
