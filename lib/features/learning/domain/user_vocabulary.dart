import 'language_scope.dart';
import 'relevance.dart';

/// A word or expression the learner has run into that is relevant for
/// learning. Not a dictionary: only items the learning flow identified.
class UserVocabulary {
  const UserVocabulary({
    required this.id,
    required this.word,
    required this.language,
    required this.lastSeenAt,
    this.meaning,
    this.exposureCount = 1,
    this.successfulUseCount = 0,
  });

  /// Builds an item with the canonical id for ([word], [language]).
  factory UserVocabulary.of({
    required String word,
    required DateTime at,
    String language = legacyLanguageCode,
    String? meaning,
    int exposureCount = 1,
    int successfulUseCount = 0,
  }) => UserVocabulary(
    id: idFor(word, language),
    word: word.trim(),
    language: language,
    meaning: meaning,
    lastSeenAt: at,
    exposureCount: exposureCount,
    successfulUseCount: successfulUseCount,
  );

  /// Case-insensitive identity per language.
  static String idFor(String word, String language) =>
      '$language:${word.trim().toLowerCase()}';

  final String id;
  final String word;

  /// Language of [word] (ISO code, `it` for Italian).
  final String language;

  /// Translation/gloss, when known.
  final String? meaning;
  final int exposureCount;
  final int successfulUseCount;
  final DateTime lastSeenAt;

  /// Approximate mastery 0.0..1.0 = successful uses / exposures (derived, same
  /// naive estimate as `GrammarTopicProgress.confidence`).
  double get confidence => exposureCount == 0
      ? 0
      : (successfulUseCount / exposureCount).clamp(0.0, 1.0);

  /// How much this word deserves reinforcement now, in the same spirit as the
  /// other priorities: `(1 − mastery) × recency`. Derived, never stored; words
  /// already known score low. Comparable only at the same [now].
  double priority(DateTime now) =>
      (1 - confidence) * recencyWeight(lastSeenAt, now);

  /// Folds a new sighting of the same word ([occurrence].id == id).
  UserVocabulary merge(UserVocabulary occurrence) {
    assert(occurrence.id == id, 'Only the same word can be merged');
    return UserVocabulary(
      id: id,
      word: word,
      language: language,
      meaning: occurrence.meaning ?? meaning,
      exposureCount: exposureCount + occurrence.exposureCount,
      successfulUseCount: successfulUseCount + occurrence.successfulUseCount,
      lastSeenAt: occurrence.lastSeenAt.isAfter(lastSeenAt)
          ? occurrence.lastSeenAt
          : lastSeenAt,
    );
  }
}
