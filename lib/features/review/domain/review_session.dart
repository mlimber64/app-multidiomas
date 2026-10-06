import '../../../core/errors/failure.dart';
import 'exercise.dart';

/// How many exercises a review session aims for.
const reviewSessionSize = 5;

/// Most review candidates a session looks at while trying to prepare
/// [reviewSessionSize] usable exercises (candidates without an available
/// exercise are skipped).
const reviewSessionScanLimit = 50;

enum ReviewSessionStatus {
  /// Nothing started yet.
  idle,

  /// Reading the queue and preparing exercises.
  loading,

  /// An exercise is shown and waiting for an answer.
  answering,

  /// An answer is being evaluated and recorded; no input is accepted.
  submitting,

  /// The answer was recorded; its [AnswerOutcome] is available.
  feedback,

  /// No more exercises: [ReviewSessionState.summary] is final.
  completed,

  /// The session cannot go on: see [ReviewSessionState.failure].
  error,
}

/// What happened to the last submitted answer.
class AnswerOutcome {
  const AnswerOutcome({
    required this.answer,
    required this.isCorrect,
    required this.correctAnswer,
    required this.explanation,
  });

  final String answer;
  final bool isCorrect;
  final String correctAnswer;
  final String explanation;

  @override
  bool operator ==(Object other) =>
      other is AnswerOutcome &&
      other.answer == answer &&
      other.isCorrect == isCorrect &&
      other.correctAnswer == correctAnswer &&
      other.explanation == explanation;

  @override
  int get hashCode =>
      Object.hash(answer, isCorrect, correctAnswer, explanation);
}

/// Session-local counts. Never persisted, never a score.
class ReviewSessionSummary {
  const ReviewSessionSummary({
    this.correct = 0,
    this.incorrect = 0,
    this.skipped = 0,
  });

  /// Answered correctly.
  final int correct;

  /// Answered incorrectly (these items come back through the review queue).
  final int incorrect;

  /// Due items that had no exercise available. Not answered, not scheduled.
  final int skipped;

  int get attempted => correct + incorrect;

  ReviewSessionSummary copyWith({int? correct, int? incorrect, int? skipped}) =>
      ReviewSessionSummary(
        correct: correct ?? this.correct,
        incorrect: incorrect ?? this.incorrect,
        skipped: skipped ?? this.skipped,
      );

  @override
  bool operator ==(Object other) =>
      other is ReviewSessionSummary &&
      other.correct == correct &&
      other.incorrect == incorrect &&
      other.skipped == skipped;

  @override
  int get hashCode => Object.hash(correct, incorrect, skipped);
}

/// Immutable snapshot of a review session for a UI to render. Holds no UI
/// text.
class ReviewSessionState {
  const ReviewSessionState({
    this.status = ReviewSessionStatus.idle,
    this.exercises = const [],
    this.index = 0,
    this.outcome,
    this.summary = const ReviewSessionSummary(),
    this.failure,
  });

  final ReviewSessionStatus status;

  /// The exercises selected when the session started, in order. Fixed for the
  /// whole session.
  final List<Exercise> exercises;

  /// Zero-based position of the current exercise in [exercises].
  final int index;

  /// Set only in [ReviewSessionStatus.feedback].
  final AnswerOutcome? outcome;
  final ReviewSessionSummary summary;

  /// Set only in [ReviewSessionStatus.error].
  final AppFailure? failure;

  /// Exercises in this session (at most [reviewSessionSize]).
  int get total => exercises.length;

  /// One-based number of the current exercise (0 when there is none).
  int get position => current == null ? 0 : index + 1;

  /// The exercise being answered or reviewed; `null` when there is none.
  Exercise? get current =>
      (status == ReviewSessionStatus.answering ||
              status == ReviewSessionStatus.submitting ||
              status == ReviewSessionStatus.feedback) &&
          index < exercises.length
      ? exercises[index]
      : null;

  bool get hasSubmitted =>
      status == ReviewSessionStatus.feedback ||
      status == ReviewSessionStatus.submitting;
  bool get isCompleted => status == ReviewSessionStatus.completed;
  bool get isLast => index >= exercises.length - 1;

  ReviewSessionState copyWith({
    ReviewSessionStatus? status,
    List<Exercise>? exercises,
    int? index,
    AnswerOutcome? outcome,
    bool clearOutcome = false,
    ReviewSessionSummary? summary,
    AppFailure? failure,
  }) => ReviewSessionState(
    status: status ?? this.status,
    exercises: exercises ?? this.exercises,
    index: index ?? this.index,
    outcome: clearOutcome ? null : (outcome ?? this.outcome),
    summary: summary ?? this.summary,
    failure: failure ?? this.failure,
  );
}
