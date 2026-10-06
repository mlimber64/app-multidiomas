import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../learning/domain/error_pattern.dart';
import '../../learning/domain/grammar_topic.dart';
import '../../learning/domain/language_scope.dart';
import '../../learning/domain/learning_error.dart';
import '../../learning/domain/learning_summary.dart';
import '../../profile/domain/user_learning_profile.dart';
import 'exercise.dart';
import 'review_item.dart';

/// Decides HOW a review item is practiced (the `ReviewEngine` decides what and
/// when). A pure function of the item and the learning memory it points to: no
/// storage, no AI, no network, no clock, no randomness, no scheduling.
abstract interface class ExerciseGenerator {
  /// The exercise for [item], built only from what [summary] really contains.
  /// When that is not enough, the result is a [Failure] holding an
  /// [ExerciseUnavailableFailure]: nothing is invented to fill the gap.
  Result<Exercise> generate(ReviewItem item, LearnerLearningSummary summary);
}

/// What each type can safely be built from today:
///
/// - **error** -> [ExerciseType.errorCorrection] from the `LearningError`
///   (`original` -> `corrected`, with its explanation). Always possible while
///   the error exists.
/// - **grammar** -> [ExerciseType.grammarChoice] from the learner's own
///   `LearningError`s of that topic: the correct form is the most frequent
///   error's `corrected`, the options are the forms (corrected and original)
///   of that topic's errors, at most [maxOptions]. `GrammarTopicProgress` only
///   holds counters, so a topic with no recorded error of its own has nothing
///   to practice and is unavailable (no sentence bank is invented).
/// - **vocabulary** -> [ExerciseType.vocabularyContext] as a cloze built from
///   a recorded correction that contains the word plus at least one more word.
///   `UserVocabulary` stores no example sentence, and its `meaning` is not
///   filled by any flow yet, so a word without such a correction is
///   unavailable.
///
/// Vocabulary of another language than [learningLanguage] is never used.
class DefaultExerciseGenerator implements ExerciseGenerator {
  const DefaultExerciseGenerator({required this.learningLanguage});

  final AppLanguage learningLanguage;

  /// Most options a grammar choice shows.
  static const maxOptions = 4;

  @override
  Result<Exercise> generate(ReviewItem item, LearnerLearningSummary summary) {
    // Only what belongs to the learner's language can become an exercise.
    final current = summary.forLanguage(learningLanguage.code);
    return switch (item.type) {
      ReviewItemType.error => _error(item, current),
      ReviewItemType.grammar => _grammar(item, current),
      ReviewItemType.vocabulary => _vocabulary(item, current),
    };
  }

  Result<Exercise> _error(ReviewItem item, LearnerLearningSummary s) {
    final error = _errorById(s, item.sourceId);
    if (error == null) {
      return _unavailable(ExerciseUnavailableReason.sourceMissing, item);
    }
    if (!_isUsable(error)) {
      return _unavailable(ExerciseUnavailableReason.insufficientData, item);
    }
    return Success(
      Exercise(
        id: _idFor(item),
        reviewItemId: item.id,
        type: ExerciseType.errorCorrection,
        prompt: error.original,
        correctAnswer: error.corrected,
        explanation: error.explanation,
      ),
    );
  }

  Result<Exercise> _grammar(ReviewItem item, LearnerLearningSummary s) {
    GrammarTopic? topic;
    for (final t in s.grammarTopics) {
      if (scopedId(learningLanguage.code, t.topic.name) == item.sourceId) {
        topic = t.topic;
      }
    }
    if (topic == null) {
      return _unavailable(ExerciseUnavailableReason.sourceMissing, item);
    }
    final errors = _ranked([
      for (final e in s.errors)
        if (e.grammarTopic == topic && _isUsable(e)) e,
    ]);
    if (errors.isEmpty) {
      return _unavailable(ExerciseUnavailableReason.insufficientData, item);
    }
    final main = errors.first;

    // The learner's own forms only: the right one, the mistake, then the
    // forms of this topic's other errors, in a fixed order.
    final forms = <String>[];
    void add(String form) {
      if (forms.length < maxOptions && !forms.contains(form)) forms.add(form);
    }

    add(main.corrected);
    add(main.original);
    for (final e in errors.skip(1)) {
      add(e.corrected);
      add(e.original);
    }
    // A fixed, answer-independent order (alphabetical), so the position of
    // the right answer carries no information.
    final options = forms.toList()..sort();
    return Success(
      Exercise(
        id: _idFor(item),
        reviewItemId: item.id,
        type: ExerciseType.grammarChoice,
        prompt: topic.name,
        options: options,
        correctAnswer: main.corrected,
        explanation: main.explanation,
      ),
    );
  }

  Result<Exercise> _vocabulary(ReviewItem item, LearnerLearningSummary s) {
    final word = s.vocabularyItems
        .where(
          (v) => v.id == item.sourceId && v.language == learningLanguage.code,
        )
        .firstOrNull;
    if (word == null) {
      return _unavailable(ExerciseUnavailableReason.sourceMissing, item);
    }
    final wordTokens = ErrorPattern.tokensOf(word.word);
    if (wordTokens.isEmpty) {
      return _unavailable(ExerciseUnavailableReason.insufficientData, item);
    }

    for (final error in _ranked(s.errors.where(_isUsable).toList())) {
      final phrase = ErrorPattern.tokensOf(error.corrected);
      final at = _indexOfSequence(phrase, wordTokens);
      if (at < 0 || phrase.length == wordTokens.length) continue;
      final cloze = [
        ...phrase.take(at),
        Exercise.blank,
        ...phrase.skip(at + wordTokens.length),
      ];
      return Success(
        Exercise(
          id: _idFor(item),
          reviewItemId: item.id,
          type: ExerciseType.vocabularyContext,
          prompt: ErrorPattern.joinTokens(cloze),
          correctAnswer: word.word,
          explanation: error.explanation,
        ),
      );
    }
    return _unavailable(ExerciseUnavailableReason.insufficientData, item);
  }

  // --- helpers -------------------------------------------------------------

  static String _idFor(ReviewItem item) => 'exercise:${item.id}';

  static LearningError? _errorById(LearnerLearningSummary s, String id) {
    for (final e in s.errors) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Both forms present and actually different.
  static bool _isUsable(LearningError e) =>
      e.original.trim().isNotEmpty &&
      e.corrected.trim().isNotEmpty &&
      e.original.trim() != e.corrected.trim();

  /// Most frequent first, then by id: no clock involved.
  static List<LearningError> _ranked(List<LearningError> errors) =>
      errors..sort((a, b) {
        final byFrequency = b.frequency.compareTo(a.frequency);
        return byFrequency != 0 ? byFrequency : a.id.compareTo(b.id);
      });

  static int _indexOfSequence(List<String> haystack, List<String> needle) {
    if (!ErrorPattern.containsSequence(haystack, needle)) return -1;
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      var matches = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          matches = false;
          break;
        }
      }
      if (matches) return i;
    }
    return -1;
  }

  static Result<Exercise> _unavailable(
    ExerciseUnavailableReason reason,
    ReviewItem item,
  ) => Failure(
    ExerciseUnavailableFailure(
      reason,
      'No exercise for ${item.id}: ${reason.name}',
    ),
  );
}
