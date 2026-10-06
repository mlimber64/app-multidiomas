import '../../../core/result/result.dart';
import 'grammar_topic.dart';
import 'language_scope.dart';
import 'learning_error.dart';
import 'learning_summary.dart';
import 'user_vocabulary.dart';

/// Persistence boundary for the learner's learning memory. Holds data, not
/// pedagogy: deciding *what* to record is the engine's job; this only stores
/// and merges. Implementations may be local JSON today and a database or
/// backend later.
abstract interface class LearningRepository {
  /// The aggregated memory; empty (not an error) when nothing is stored.
  Future<Result<LearnerLearningSummary>> getLearningSummary();

  /// Records one sighting of a mistake. If a record with the same
  /// [LearningError.id] exists, the sighting is merged into it (frequency
  /// increases); otherwise a record is created.
  Future<Result<void>> recordError(LearningError occurrence);

  /// Records one sighting of a word, merged by [UserVocabulary.id].
  Future<Result<void>> recordVocabulary(UserVocabulary occurrence);

  /// The topic was involved in the learner's writing ([wasError] if wrongly).
  /// Progress is kept per [language] (ISO code; data written before several
  /// languages existed is the legacy language, see `language_scope.dart`).
  Future<Result<void>> recordGrammarTopicExposure(
    GrammarTopic topic, {
    required DateTime at,
    bool wasError = false,
    String language = legacyLanguageCode,
  });

  /// The topic was used correctly.
  Future<Result<void>> recordSuccessfulGrammarUse(
    GrammarTopic topic, {
    required DateTime at,
    String language = legacyLanguageCode,
  });

  /// Erases all learning memory (conversations are untouched).
  Future<Result<void>> clearLearningData();
}
