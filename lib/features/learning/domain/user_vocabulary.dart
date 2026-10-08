import 'language_scope.dart';
import 'learning_state.dart';
import 'practice_evidence.dart';
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
    double? weightedExposure,
    double? weightedSuccesses,
    this.proof = PracticeProof.empty,
  }) : _weightedExposure = weightedExposure,
       _weightedSuccesses = weightedSuccesses;

  final double? _weightedExposure;
  final double? _weightedSuccesses;

  /// The counts weighted by how strong each piece of evidence was (see
  /// `EvidenceStrength`); equal to the plain counts for a word only ever met
  /// in conversation, and for every record written before practice evidence.
  double get weightedExposure => _weightedExposure ?? exposureCount.toDouble();
  double get weightedSuccesses =>
      _weightedSuccesses ?? successfulUseCount.toDouble();

  bool get hasWeightedCounts =>
      _weightedExposure != null || _weightedSuccesses != null;

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

  /// What the learner has demonstrated with this word (see `PracticeProof`).
  final PracticeProof proof;

  /// Where the learner stands on this word: derived, never stored. A word is
  /// only in the memory because the learner struggled with it.
  LearningState get learningState => proof.stateOf(hadDifficulty: true);

  /// Language of [word] (ISO code, `it` for Italian).
  final String language;

  /// Translation/gloss, when known.
  final String? meaning;
  final int exposureCount;
  final int successfulUseCount;
  final DateTime lastSeenAt;

  /// Approximate mastery 0.0..1.0 = successful uses / exposures (derived, same
  /// naive estimate as `GrammarTopicProgress.confidence`).
  double get confidence => weightedExposure <= 0
      ? 0
      : (weightedSuccesses / weightedExposure).clamp(0.0, 1.0);

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
      weightedExposure: weightedExposure + occurrence.weightedExposure,
      weightedSuccesses: weightedSuccesses + occurrence.weightedSuccesses,
      proof: proof,
    );
  }

  /// Takes one piece of practice into the word, [weight] times as much as a
  /// full occurrence in conversation. An [occurrence] is the word met in the
  /// learner's own writing (it moves the plain counts and the last time
  /// seen); practice that is not (a review) only moves the weighted counts.
  UserVocabulary practice({
    required DateTime at,
    required bool success,
    double weight = 1,
    bool occurrence = false,
    PracticeEvidenceType? evidenceType,
    String? context,
  }) => UserVocabulary(
    id: id,
    word: word,
    language: language,
    meaning: meaning,
    exposureCount: exposureCount + (occurrence ? 1 : 0),
    successfulUseCount: successfulUseCount + (occurrence && success ? 1 : 0),
    lastSeenAt: occurrence && at.isAfter(lastSeenAt) ? at : lastSeenAt,
    weightedExposure: weightedExposure + weight,
    weightedSuccesses: weightedSuccesses + (success ? weight : 0),
    proof: evidenceType == null
        ? proof
        : proof.record(type: evidenceType, success: success, context: context),
  );
}
