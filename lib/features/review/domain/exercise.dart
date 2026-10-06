import 'package:flutter/foundation.dart' show listEquals;

/// How a review item is practiced.
enum ExerciseType {
  /// Type the corrected form of a mistake the learner made.
  errorCorrection,

  /// Pick the correct form among options (the learner's real forms).
  grammarChoice,

  /// Recall a word from the phrase it was corrected in (cloze).
  vocabularyContext,
}

/// One practice step for one review item. An ephemeral session object: it is
/// generated from existing learning data and never persisted.
///
/// The model carries no UI copy. What [prompt] means depends on [type]:
/// - [ExerciseType.errorCorrection]: the learner's incorrect text.
/// - [ExerciseType.grammarChoice]: the grammar topic's key (`GrammarTopic.name`);
///   the options are the candidate forms.
/// - [ExerciseType.vocabularyContext]: a phrase with [blank] where the word
///   goes.
///
/// Evaluation is deterministic and needs no AI: a free-text answer is correct
/// when it equals [correctAnswer] after normalization (done by the future
/// session); a choice answer is correct when it equals [correctAnswer].
class Exercise {
  Exercise({
    required this.id,
    required this.reviewItemId,
    required this.type,
    required this.prompt,
    required this.correctAnswer,
    this.options = const [],
    this.explanation = '',
  }) : assert(
         options.isEmpty || options.contains(correctAnswer),
         'The correct answer must be one of the options',
       );

  /// What stands for the missing word in a vocabulary prompt.
  static const blank = '____';

  /// Same review item, same exercise id.
  final String id;

  /// The `ReviewItem.id` this exercise practices, to report the result back.
  final String reviewItemId;
  final ExerciseType type;
  final String prompt;

  /// Empty for free-text exercises; otherwise 2 or more candidates in a fixed
  /// order.
  final List<String> options;
  final String correctAnswer;

  /// Why the answer is right, from learning memory; empty when none is known.
  final String explanation;

  bool get isMultipleChoice => options.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is Exercise &&
      other.id == id &&
      other.reviewItemId == reviewItemId &&
      other.type == type &&
      other.prompt == prompt &&
      other.correctAnswer == correctAnswer &&
      other.explanation == explanation &&
      listEquals(other.options, options);

  @override
  int get hashCode => Object.hash(
    id,
    reviewItemId,
    type,
    prompt,
    correctAnswer,
    explanation,
    Object.hashAll(options),
  );

  @override
  String toString() => 'Exercise($id, $type)';
}
