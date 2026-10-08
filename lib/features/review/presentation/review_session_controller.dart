import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../learning/domain/learning_summary.dart';
import '../../learning/presentation/learning_providers.dart';
import '../domain/answer_evaluator.dart';
import '../domain/exercise.dart';
import '../domain/review_item.dart';
import '../domain/review_session.dart';
import 'review_providers.dart';

/// Source of "now" for the session (queue and results). Overridden in tests so
/// nothing depends on the real clock.
final reviewSessionClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final reviewSessionControllerProvider =
    NotifierProvider.autoDispose<ReviewSessionController, ReviewSessionState>(
      ReviewSessionController.new,
    );

/// Orchestrates one review session:
///
///   queue (ReviewEngine) -> exercise (ExerciseGenerator) -> answer ->
///   deterministic evaluation -> ReviewEngine.recordReviewResult -> next
///
/// It decides none of the *what/when* (ReviewEngine) nor the *how*
/// (ExerciseGenerator), and keeps no scheduling logic: it only reports
/// success or failure. No UI, no storage, no AI. State is ephemeral.
///
/// State machine (operations in any other state are ignored):
///
///   idle|completed|error --start--> loading --> answering | completed | error
///   answering --submitAnswer--> submitting --> feedback | error
///   feedback --continueSession--> answering | completed
class ReviewSessionController extends Notifier<ReviewSessionState> {
  /// Bumped by every [start]: results of an older start are dropped.
  int _generation = 0;

  @override
  ReviewSessionState build() => const ReviewSessionState();

  /// Prepares a session: the review queue in its own order, the first [size]
  /// candidates that can produce an exercise (the others are skipped without
  /// any result being recorded). The selection is a snapshot; the queue is not
  /// read again during the session.
  ///
  /// With [onlyItems] the session is limited to those review items (the ones
  /// the daily routine chose); whatever is no longer due is simply left out.
  Future<void> start({
    int size = reviewSessionSize,
    Set<String>? onlyItems,
  }) async {
    final status = state.status;
    if (status != ReviewSessionStatus.idle &&
        status != ReviewSessionStatus.completed &&
        status != ReviewSessionStatus.error) {
      return;
    }
    final generation = ++_generation;
    state = const ReviewSessionState(status: ReviewSessionStatus.loading);

    final queue = await ref
        .read(reviewEngineProvider)
        .getReviewQueue(
          now: ref.read(reviewSessionClockProvider)(),
          limit: reviewSessionScanLimit,
        );
    if (!_current(generation)) return;
    if (queue case Failure(:final failure)) return _fail(failure);
    final items = [
      for (final item in (queue as Success<List<ReviewItem>>).value)
        if (onlyItems == null || onlyItems.contains(item.id)) item,
    ];
    if (items.isEmpty) {
      state = const ReviewSessionState(status: ReviewSessionStatus.completed);
      return;
    }

    final summary = await ref.read(learningEngineProvider).summary();
    if (!_current(generation)) return;
    if (summary case Failure(:final failure)) return _fail(failure);
    final learned = (summary as Success<LearnerLearningSummary>).value;

    final generator = ref.read(exerciseGeneratorProvider);
    final exercises = <Exercise>[];
    var skipped = 0;
    for (final item in items) {
      if (exercises.length == size) break;
      switch (generator.generate(item, learned)) {
        case Success(value: final exercise):
          exercises.add(exercise);
        case Failure(failure: ExerciseUnavailableFailure()):
          skipped++;
        case Failure(:final failure):
          return _fail(failure);
      }
    }

    state = exercises.isEmpty
        ? ReviewSessionState(
            status: ReviewSessionStatus.completed,
            summary: ReviewSessionSummary(skipped: skipped),
          )
        : ReviewSessionState(
            status: ReviewSessionStatus.answering,
            exercises: exercises,
            summary: ReviewSessionSummary(skipped: skipped),
          );
  }

  /// Evaluates [answer] for the current exercise and records the result with
  /// the ReviewEngine (success when correct, failure otherwise). Returns
  /// whether the answer was accepted: it is ignored (`false`, nothing changes
  /// or is recorded) when there is no exercise waiting for an answer, a
  /// submission is already in progress or done, or the answer is blank / not
  /// one of the options.
  Future<bool> submitAnswer(String answer) async {
    final exercise = state.status == ReviewSessionStatus.answering
        ? state.current
        : null;
    if (exercise == null || !AnswerEvaluator.isAnswerable(exercise, answer)) {
      return false;
    }
    final generation = _generation;
    // Closes the door synchronously: a second call sees `submitting`.
    state = state.copyWith(status: ReviewSessionStatus.submitting);

    final correct = AnswerEvaluator.isCorrect(exercise, answer);
    final recorded = await ref
        .read(reviewEngineProvider)
        .recordReviewResult(
          itemId: exercise.reviewItemId,
          result: correct ? ReviewResult.success : ReviewResult.failure,
          now: ref.read(reviewSessionClockProvider)(),
          exercise: exercise.type,
        );
    if (!_current(generation)) return true;
    if (recorded case Failure(:final failure)) {
      // Never pretend it was recorded.
      _fail(failure);
      return true;
    }
    // If the answer taught the learning memory something, the learning engine
    // has already moved `learningRevisionProvider`: nothing to do here.

    final summary = state.summary;
    state = state.copyWith(
      status: ReviewSessionStatus.feedback,
      summary: correct
          ? summary.copyWith(correct: summary.correct + 1)
          : summary.copyWith(incorrect: summary.incorrect + 1),
      outcome: AnswerOutcome(
        answer: answer,
        isCorrect: correct,
        correctAnswer: exercise.correctAnswer,
        explanation: exercise.explanation,
      ),
    );
    return true;
  }

  /// Moves on after feedback: to the next prepared exercise, or completes the
  /// session when there is none. Ignored outside the feedback state.
  void continueSession() {
    if (state.status != ReviewSessionStatus.feedback) return;
    if (state.isLast) {
      state = ReviewSessionState(
        status: ReviewSessionStatus.completed,
        exercises: state.exercises,
        index: state.exercises.length,
        summary: state.summary,
      );
      return;
    }
    state = state.copyWith(
      status: ReviewSessionStatus.answering,
      index: state.index + 1,
      clearOutcome: true,
    );
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  void _fail(AppFailure failure) {
    state = state.copyWith(status: ReviewSessionStatus.error, failure: failure);
  }
}
