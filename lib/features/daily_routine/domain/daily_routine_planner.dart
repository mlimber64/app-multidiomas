import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../learning/domain/language_learning_rules.dart';
import '../../learning/domain/learning_context_builder.dart';
import '../../learning/domain/learning_engine.dart';
import '../../learning/domain/learning_summary.dart';
import '../../profile/domain/user_learning_profile.dart';
import '../../review/domain/exercise_generator.dart';
import '../../review/domain/review_item.dart';
import '../../review/domain/review_engine.dart';
import 'daily_routine.dart';
import 'scenario_generator.dart';

/// Builds a day's routine by asking the systems that already know:
///
/// - **Ripassa**: the `ReviewEngine` decides what is due; the
///   `ExerciseGenerator` says which of it can be practiced as an exercise.
/// - **Parla**: the `ScenarioGenerator` turns the learning memory into a
///   speaking situation.
/// - **Consolida**: the words the learning memory ranks as the ones to
///   reinforce.
///
/// It only plans: it writes nothing, creates no review item and detects no
/// error. Nothing is made up: a step with nothing real to practice is left
/// out ([RoutineStepState.unavailable]). Same day, language and learning state, same
/// routine.
class DailyRoutinePlanner {
  const DailyRoutinePlanner({
    required this.reviews,
    required this.exercises,
    required this.learning,
    this.scenarios = const ScenarioGenerator(),
  });

  final ReviewEngine reviews;
  final ExerciseGenerator exercises;
  final LearningEngine learning;
  final ScenarioGenerator scenarios;

  /// Most due review items looked at to find [ReviewStep.maxItems] that can be
  /// practiced.
  static const reviewScanLimit = 50;

  Future<Result<DailyRoutine>> plan({
    required DateTime now,
    required UserLearningProfile profile,
  }) async {
    final language = profile.learningLanguage;

    final learned = await learning.summary();
    if (learned case Failure(:final failure)) return Failure(failure);
    // Only the language being learned goes into its routine.
    final summary = (learned as Success<LearnerLearningSummary>).value
        .forLanguage(language.code);

    final reviewIds = await _reviewItems(now, summary);
    if (reviewIds case Failure(:final failure)) return Failure(failure);
    final itemIds = (reviewIds as Success<List<String>>).value;

    final mission = scenarios.generate(
      date: now,
      profile: profile,
      summary: summary,
      describeTopic: learningRulesFor(language)?.describeTopic,
    );

    final wordIds = [
      for (final w in selectVocabularyToReinforce(
        summary,
        now,
        language.code,
      ).take(VocabularyStep.maxWords))
        w.id,
    ];

    return Success(
      DailyRoutine(
        date: DailyRoutine.dateOf(now),
        learningLanguage: language,
        step1: ReviewStep(
          state: itemIds.isEmpty
              ? RoutineStepState.unavailable
              : RoutineStepState.pending,
          itemIds: itemIds,
        ),
        step2: ScenarioStep(state: RoutineStepState.pending, mission: mission),
        step3: VocabularyStep(
          state: wordIds.isEmpty
              ? RoutineStepState.unavailable
              : RoutineStepState.pending,
          vocabularyIds: wordIds,
        ),
      ),
    );
  }

  /// The review items to practice: the ReviewEngine's queue, in its own order,
  /// keeping the first ones an exercise can be made from.
  Future<Result<List<String>>> _reviewItems(
    DateTime now,
    LearnerLearningSummary summary,
  ) async {
    final queue = await reviews.getReviewQueue(
      now: now,
      limit: reviewScanLimit,
    );
    if (queue case Failure(:final failure)) return Failure(failure);
    final ids = <String>[];
    for (final item in (queue as Success<List<ReviewItem>>).value) {
      if (ids.length == ReviewStep.maxItems) break;
      switch (exercises.generate(item, summary)) {
        case Success():
          ids.add(item.id);
        case Failure(failure: ExerciseUnavailableFailure()):
          break;
        case Failure(:final failure):
          return Failure(failure);
      }
    }
    return Success(ids);
  }
}
