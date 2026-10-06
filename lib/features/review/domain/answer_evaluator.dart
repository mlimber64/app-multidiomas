import 'exercise.dart';

/// Conservative normalization for typed answers: surrounding whitespace is
/// trimmed, runs of whitespace become one space, and letters are lowercased.
/// Nothing else changes: accents, apostrophes and punctuation are kept, no
/// word is dropped and nothing is grammatically transformed.
String normalizeAnswer(String answer) =>
    answer.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Deterministic evaluation of one answer. No AI, no fuzzy matching and no
/// accepting of "equivalent" answers: only the stored [Exercise.correctAnswer]
/// is correct.
abstract final class AnswerEvaluator {
  /// Whether [answer] can be evaluated at all: a blank typed answer, or a
  /// choice that is not one of the options, is not an answer.
  static bool isAnswerable(Exercise exercise, String answer) =>
      exercise.isMultipleChoice
      ? exercise.options.contains(answer)
      : answer.trim().isNotEmpty;

  /// Multiple choice: the selected option must be the correct one, exactly.
  /// Free text (error correction, vocabulary): equal after [normalizeAnswer].
  static bool isCorrect(Exercise exercise, String answer) =>
      exercise.isMultipleChoice
      ? answer == exercise.correctAnswer
      : normalizeAnswer(answer) == normalizeAnswer(exercise.correctAnswer);
}
