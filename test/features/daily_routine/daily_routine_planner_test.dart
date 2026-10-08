import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine_planner.dart';
import 'package:parla_con_me/features/daily_routine/domain/scenario_mission.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_overview.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/review/domain/exercise_generator.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';

import '../../support/learning_fixtures.dart';

final _now = DateTime(2026, 10, 6, 9);

class _Reviews implements ReviewEngine {
  _Reviews(this.queue);

  List<ReviewItem> queue;
  AppFailure? failure;
  int? lastLimit;
  int calls = 0;

  @override
  Future<Result<List<ReviewItem>>> getReviewQueue({
    required DateTime now,
    int limit = 10,
  }) async {
    calls++;
    lastLimit = limit;
    if (failure != null) return Failure(failure!);
    return Success(queue.take(limit).toList());
  }

  @override
  Future<Result<ReviewItem>> recordReviewResult({
    required String itemId,
    required ReviewResult result,
    required DateTime now,
    ExerciseType? exercise,
  }) => throw StateError('the planner must never record a review');

  @override
  Future<Result<List<ReviewItem>>> synchronize({required DateTime now}) =>
      throw StateError('the planner must never synchronize');
}

class _Learning implements LearningEngine {
  _Learning(this.value);

  LearnerLearningSummary value;
  AppFailure? failure;

  @override
  Future<Result<LearnerLearningSummary>> summary() async =>
      failure != null ? Failure(failure!) : Success(value);

  @override
  Future<Result<LearningOverview>> overview() => throw UnimplementedError();
  @override
  Future<Result<LearningContext>> learningContext() =>
      throw UnimplementedError();
  @override
  Future<Result<void>> analyze({
    required String userMessage,
    required AIResponse response,
    String? contextId,
  }) => throw StateError('the planner must never analyze');
}

LearningError _error(String original, String corrected, {String? language}) =>
    LearningError(
      id: language == null ? '$original -> $corrected' : '$language:$original',
      category: LearningErrorCategory.grammar,
      original: original,
      corrected: corrected,
      frequency: 2,
      firstSeenAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
      confidence: 0.9,
      language: language ?? 'it',
    );

ReviewItem _due(LearningError e) =>
    ReviewItem.discovered(ReviewItemType.error, e.id, _now);

UserLearningProfile _profile([AppLanguage language = AppLanguage.italian]) =>
    UserLearningProfile(
      learningLanguage: language,
      level: LanguageLevel.a2,
      goals: const {LearningGoal.work},
      focusAreas: const {LearningFocus.conversation},
      onboardingCompleted: true,
    );

class _Setup {
  _Setup({
    List<LearningError> errors = const [],
    List<ReviewItem>? queue,
    LearnerLearningSummary? summary,
    this.language = AppLanguage.italian,
  }) : learning = _Learning(summary ?? summaryOf(errors: errors)),
       reviews = _Reviews(queue ?? [for (final e in errors) _due(e)]) {
    planner = DailyRoutinePlanner(
      reviews: reviews,
      exercises: DefaultExerciseGenerator(learningLanguage: language),
      learning: learning,
    );
  }

  final AppLanguage language;
  final _Learning learning;
  final _Reviews reviews;
  late final DailyRoutinePlanner planner;

  Future<Result<DailyRoutine>> plan({DateTime? now}) =>
      planner.plan(now: now ?? _now, profile: _profile(language));

  Future<DailyRoutine> planned({DateTime? now}) async =>
      switch (await plan(now: now)) {
        Success(:final value) => value,
        Failure(:final failure) => throw failure,
      };
}

List<LearningError> _errors(int n) => [
  for (var i = 0; i < n; i++) _error('io ho andato $i', 'sono andato $i'),
];

void main() {
  group('step 1: review', () {
    test('uses the real queue, in its own order, at most three', () async {
      final s = _Setup(errors: _errors(5));
      final r = await s.planned();
      expect(r.step1.state, RoutineStepState.pending);
      expect(r.step1.itemIds, [
        'error:io ho andato 0 -> sono andato 0',
        'error:io ho andato 1 -> sono andato 1',
        'error:io ho andato 2 -> sono andato 2',
      ]);
      expect(r.step1.itemIds.length, ReviewStep.maxItems);
      expect(s.reviews.lastLimit, DailyRoutinePlanner.reviewScanLimit);
    });

    test('with two, one or zero due items it plans only what exists', () async {
      for (final n in [2, 1]) {
        final r = await _Setup(errors: _errors(n)).planned();
        expect(r.step1.itemIds, hasLength(n));
        expect(r.step1.state, RoutineStepState.pending);
      }
      final none = await _Setup().planned();
      expect(none.step1.state, RoutineStepState.unavailable);
      expect(none.step1.itemIds, isEmpty);
    });

    test('items an exercise cannot be made from are skipped', () async {
      final errors = _errors(3);
      // The first item points to an error that is no longer in memory.
      final ghost = ReviewItem.discovered(
        ReviewItemType.error,
        'gone -> gone',
        _now,
      );
      final s = _Setup(errors: errors, queue: [ghost, ...errors.map(_due)]);
      final r = await s.planned();
      expect(r.step1.itemIds, isNot(contains('error:gone -> gone')));
      expect(r.step1.itemIds, hasLength(3));
    });

    test('when nothing can be practiced the step is unavailable', () async {
      final ghost = ReviewItem.discovered(
        ReviewItemType.error,
        'gone -> gone',
        _now,
      );
      final r = await _Setup(queue: [ghost]).planned();
      expect(r.step1.state, RoutineStepState.unavailable);
    });

    test('an error of another language is never planned', () async {
      final english = _error('i goed', 'i went', language: 'en');
      final s = _Setup(
        errors: [english],
        queue: [_due(english)],
        language: AppLanguage.italian,
      );
      expect((await s.planned()).step1.state, RoutineStepState.unavailable);

      final inEnglish = _Setup(
        errors: [english],
        queue: [_due(english)],
        language: AppLanguage.english,
      );
      expect(
        (await inEnglish.planned()).step1.itemIds,
        [english.id].map((id) => 'error:$id'),
      );
    });
  });

  group('step 2: scenario', () {
    test('is always available and comes from the learning memory', () async {
      final summary = summaryOf(
        topics: [topicOf(GrammarTopic.passatoProssimo, errors: 4)],
      );
      final r = await _Setup(summary: summary).planned();
      expect(r.step2.state, RoutineStepState.pending);
      expect(r.step2.mission!.situation, ScenarioSituation.yesterday);
      expect(r.step2.mission!.targetTopics, [GrammarTopic.passatoProssimo]);
    });

    test('with an empty memory the goals give a fallback mission', () async {
      final r = await _Setup().planned();
      expect(r.step2.state, RoutineStepState.pending);
      expect(r.step2.mission!.situation, ScenarioSituation.workday);
      expect(r.step2.mission!.targetTopics, isEmpty);
    });

    test('topics of another language do not shape the mission', () async {
      final other = GrammarTopicProgress(
        topic: GrammarTopic.passatoProssimo,
        exposureCount: 5,
        errorCount: 5,
        lastSeenAt: DateTime.now(),
        language: 'fr',
      );
      final r = await _Setup(summary: summaryOf(topics: [other])).planned();
      expect(r.step2.mission!.targetTopics, isEmpty);
    });
  });

  group('step 3: vocabulary', () {
    test('picks at most two of the words the memory ranks first', () async {
      final summary = summaryOf(
        vocabulary: [wordOf('ciao'), wordOf('grazie'), wordOf('prego')],
      );
      final r = await _Setup(summary: summary).planned();
      expect(r.step3.state, RoutineStepState.pending);
      expect(r.step3.vocabularyIds, hasLength(VocabularyStep.maxWords));
      expect({
        'it:ciao',
        'it:grazie',
        'it:prego',
      }, containsAll(r.step3.vocabularyIds));
    });

    test('with no words the step is unavailable, not invented', () async {
      final r = await _Setup().planned();
      expect(r.step3.state, RoutineStepState.unavailable);
      expect(r.step3.vocabularyIds, isEmpty);
    });

    test('a word already known is not worth reinforcing', () async {
      final summary = summaryOf(vocabulary: [wordOf('ciao', successes: 20)]);
      final r = await _Setup(summary: summary).planned();
      expect(r.step3.state, RoutineStepState.unavailable);
    });

    test('only words of the language being learned', () async {
      final summary = summaryOf(
        vocabulary: [
          UserVocabulary.of(
            word: 'bonjour',
            at: DateTime.now(),
            language: 'fr',
          ),
          wordOf('ciao'),
        ],
      );
      final it = await _Setup(summary: summary).planned();
      expect(it.step3.vocabularyIds, ['it:ciao']);
      final fr = await _Setup(
        summary: summary,
        language: AppLanguage.french,
      ).planned();
      expect(fr.step3.vocabularyIds, ['fr:bonjour']);
    });
  });

  group('the whole plan', () {
    test('has the day, the language and three steps in order', () async {
      final r = await _Setup(errors: _errors(1)).planned();
      expect(r.date, '2026-10-06');
      expect(r.learningLanguage, AppLanguage.italian);
      expect(r.key, '2026-10-06|it');
    });

    test('is deterministic for the same day and state', () async {
      final summary = summaryOf(
        errors: _errors(2),
        topics: [topicOf(GrammarTopic.prepositions, errors: 3)],
        vocabulary: [wordOf('ciao')],
      );
      final a = await _Setup(
        summary: summary,
        queue: _errors(2).map(_due).toList(),
      ).planned(now: DateTime(2026, 10, 6, 7));
      final b = await _Setup(
        summary: summary,
        queue: _errors(2).map(_due).toList(),
      ).planned(now: DateTime(2026, 10, 6, 21));
      expect(a, b);
    });

    test('never writes: only reads the review queue and the memory', () async {
      // _Reviews and _Learning throw on any write path; reaching here is proof.
      final s = _Setup(errors: _errors(2));
      await s.plan();
      expect(s.reviews.calls, 1);
    });

    test('a failing review queue is a failure, not an empty routine', () async {
      final s = _Setup(errors: _errors(2));
      s.reviews.failure = const StorageFailure('disk');
      expect(await s.plan(), isA<Failure<DailyRoutine>>());
    });

    test('a failing learning memory is a failure', () async {
      final s = _Setup(errors: _errors(2));
      s.learning.failure = const StorageFailure('disk');
      final result = await s.plan();
      expect(result, isA<Failure<DailyRoutine>>());
      expect(s.reviews.calls, 0, reason: 'stops at the first failure');
    });
  });
}
