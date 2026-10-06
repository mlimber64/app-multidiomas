import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_overview.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/domain/answer_evaluator.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/exercise_generator.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/features/review/domain/review_session.dart';
import 'package:parla_con_me/features/review/presentation/review_providers.dart';
import 'package:parla_con_me/features/review/presentation/review_session_controller.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';

import '../../support/in_memory_local_storage.dart';

final _now = DateTime.utc(2026, 10, 20, 12);

// --- fakes -----------------------------------------------------------------

class _FakeReviewEngine implements ReviewEngine {
  _FakeReviewEngine(this.queue) : _all = List.of(queue);

  final List<ReviewItem> _all;

  List<ReviewItem> queue;
  AppFailure? queueFailure;
  AppFailure? recordFailure;
  Completer<void>? recordGate;
  int queueCalls = 0;
  final recorded = <(String, ReviewResult)>[];

  @override
  Future<Result<List<ReviewItem>>> getReviewQueue({
    required DateTime now,
    int limit = 10,
  }) async {
    queueCalls++;
    final failure = queueFailure;
    if (failure != null) return Failure(failure);
    return Success(queue.take(limit).toList());
  }

  @override
  Future<Result<ReviewItem>> recordReviewResult({
    required String itemId,
    required ReviewResult result,
    required DateTime now,
  }) async {
    await recordGate?.future;
    final failure = recordFailure;
    if (failure != null) return Failure(failure);
    recorded.add((itemId, result));
    return Success(_all.firstWhere((i) => i.id == itemId));
  }

  @override
  Future<Result<List<ReviewItem>>> synchronize({required DateTime now}) =>
      throw UnimplementedError();
}

class _FakeGenerator implements ExerciseGenerator {
  _FakeGenerator(this.exercises);

  /// ReviewItem id -> exercise; missing means unavailable.
  final Map<String, Exercise> exercises;
  final generated = <String>[];

  @override
  Result<Exercise> generate(ReviewItem item, LearnerLearningSummary summary) {
    generated.add(item.id);
    final e = exercises[item.id];
    return e == null
        ? Failure(
            ExerciseUnavailableFailure(
              ExerciseUnavailableReason.insufficientData,
              'none',
            ),
          )
        : Success(e);
  }
}

class _FakeLearning implements LearningEngine {
  AppFailure? failure;

  @override
  Future<Result<LearnerLearningSummary>> summary() async => failure != null
      ? Failure(failure!)
      : const Success(LearnerLearningSummary.empty);

  @override
  Future<Result<LearningOverview>> overview() => throw UnimplementedError();
  @override
  Future<Result<LearningContext>> learningContext() =>
      throw UnimplementedError();
  @override
  Future<Result<void>> analyze({
    required String userMessage,
    required AIResponse response,
  }) => throw UnimplementedError();
}

// --- helpers ----------------------------------------------------------------

ReviewItem _item(String key) =>
    ReviewItem.discovered(ReviewItemType.error, key, _now);

Exercise _exercise(
  ReviewItem item, {
  ExerciseType type = ExerciseType.errorCorrection,
  String correct = 'sono andato',
  List<String> options = const [],
  String explanation = 'Perché.',
}) => Exercise(
  id: 'exercise:${item.id}',
  reviewItemId: item.id,
  type: type,
  prompt: 'ho andato',
  correctAnswer: correct,
  options: options,
  explanation: explanation,
);

class _Setup {
  _Setup(int items, {Set<int> unavailable = const {}}) {
    queue = [for (var i = 0; i < items; i++) _item('e$i')];
    engine = _FakeReviewEngine(queue);
    generator = _FakeGenerator({
      for (var i = 0; i < items; i++)
        if (!unavailable.contains(i)) queue[i].id: _exercise(queue[i]),
    });
    container = ProviderContainer(
      overrides: [
        reviewEngineProvider.overrideWithValue(engine),
        exerciseGeneratorProvider.overrideWithValue(generator),
        learningEngineProvider.overrideWithValue(learning),
        reviewSessionClockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(container.dispose);
    container.listen(reviewSessionControllerProvider, (_, _) {});
  }

  late final List<ReviewItem> queue;
  late final _FakeReviewEngine engine;
  late final _FakeGenerator generator;
  final learning = _FakeLearning();
  late final ProviderContainer container;

  ReviewSessionState get state =>
      container.read(reviewSessionControllerProvider);
  ReviewSessionController get controller =>
      container.read(reviewSessionControllerProvider.notifier);

  Future<void> start() => controller.start();
}

Future<void> _answerAll(_Setup s, String answer) async {
  while (s.state.status == ReviewSessionStatus.answering) {
    await s.controller.submitAnswer(answer);
    s.controller.continueSession();
  }
}

void main() {
  group('session preparation', () {
    test('an empty queue completes immediately', () async {
      final s = _Setup(0);
      await s.start();
      expect(s.state.status, ReviewSessionStatus.completed);
      expect(s.state.total, 0);
      expect(s.state.current, isNull);
      expect(s.engine.recorded, isEmpty);
    });

    test('one usable exercise', () async {
      final s = _Setup(1);
      await s.start();
      expect(s.state.status, ReviewSessionStatus.answering);
      expect(s.state.total, 1);
      expect(s.state.position, 1);
      expect(s.state.current, s.generator.exercises['error:e0']);
    });

    test('the target is five and a named constant', () async {
      expect(reviewSessionSize, 5);
      final s = _Setup(5);
      await s.start();
      expect(s.state.total, 5);
    });

    test('more than five candidates: only five are prepared', () async {
      final s = _Setup(9);
      await s.start();
      expect(s.state.total, 5);
      expect(s.state.exercises.map((e) => e.reviewItemId), [
        'error:e0',
        'error:e1',
        'error:e2',
        'error:e3',
        'error:e4',
      ]);
      expect(
        s.generator.generated,
        hasLength(5),
        reason: 'nothing generated beyond what is needed',
      );
    });

    test('an unavailable exercise is skipped, not recorded', () async {
      final s = _Setup(3, unavailable: {1});
      await s.start();
      expect(s.state.exercises.map((e) => e.reviewItemId), [
        'error:e0',
        'error:e2',
      ]);
      expect(s.state.summary.skipped, 1);
      expect(s.engine.recorded, isEmpty);
      await _answerAll(s, 'sono andato');
      expect(s.engine.recorded.map((r) => r.$1), ['error:e0', 'error:e2']);
      expect(s.state.summary.skipped, 1);
    });

    test('unavailable candidates are replaced by later ones', () async {
      final s = _Setup(8, unavailable: {0, 1, 2});
      await s.start();
      expect(s.state.total, 5);
      expect(s.state.exercises.first.reviewItemId, 'error:e3');
      expect(s.state.summary.skipped, 3);
    });

    test(
      'only unavailable candidates: finite, completed, nothing recorded',
      () async {
        final s = _Setup(4, unavailable: {0, 1, 2, 3});
        await s.start();
        expect(s.state.status, ReviewSessionStatus.completed);
        expect(s.state.total, 0);
        expect(s.state.summary.skipped, 4);
        expect(s.engine.recorded, isEmpty);
        expect(s.generator.generated, hasLength(4), reason: 'each tried once');
      },
    );

    test('the queue is read once: the session is a snapshot', () async {
      final s = _Setup(3);
      await s.start();
      await s.controller.submitAnswer('wrong');
      s.engine.queue = []; // the queue changes while the session runs
      s.controller.continueSession();
      expect(s.state.current?.reviewItemId, 'error:e1');
      await _answerAll(s, 'sono andato');
      expect(s.engine.queueCalls, 1);
      expect(s.state.isCompleted, isTrue);
    });

    test('same inputs, same session', () async {
      final a = _Setup(7, unavailable: {2});
      final b = _Setup(7, unavailable: {2});
      await a.start();
      await b.start();
      expect(
        a.state.exercises.map((e) => e.id),
        b.state.exercises.map((e) => e.id),
      );
    });

    test('start is ignored while a session is in progress', () async {
      final s = _Setup(2);
      await s.start();
      await s.controller.submitAnswer('x');
      await s.start();
      expect(s.engine.queueCalls, 1);
      expect(s.state.status, ReviewSessionStatus.feedback);
    });

    test('a new session can start after completion', () async {
      final s = _Setup(1);
      await s.start();
      await _answerAll(s, 'sono andato');
      expect(s.state.isCompleted, isTrue);
      await s.start();
      expect(s.state.status, ReviewSessionStatus.answering);
      expect(s.state.summary.attempted, 0);
    });
  });

  group('evaluation', () {
    Exercise choice() => Exercise(
      id: 'x',
      reviewItemId: 'grammar:essereVsAvere',
      type: ExerciseType.grammarChoice,
      prompt: 'essereVsAvere',
      options: const ['ho andato', 'sono andato'],
      correctAnswer: 'sono andato',
    );
    Exercise typed(ExerciseType type) => Exercise(
      id: 'y',
      reviewItemId: 'k',
      type: type,
      prompt: 'p',
      correctAnswer: 'sono andato',
    );

    test('grammar choice: exact option', () {
      expect(AnswerEvaluator.isCorrect(choice(), 'sono andato'), isTrue);
      expect(AnswerEvaluator.isCorrect(choice(), 'ho andato'), isFalse);
      // Choices are exact, not normalized.
      expect(AnswerEvaluator.isCorrect(choice(), 'Sono andato'), isFalse);
    });

    test('vocabulary: whitespace and case are ignored', () {
      final e = typed(ExerciseType.vocabularyContext);
      expect(AnswerEvaluator.isCorrect(e, '  Sono   ANDATO '), isTrue);
      expect(AnswerEvaluator.isCorrect(e, 'sono partito'), isFalse);
    });

    test('error correction: same rule', () {
      final e = typed(ExerciseType.errorCorrection);
      expect(AnswerEvaluator.isCorrect(e, ' Sono Andato '), isTrue);
      expect(AnswerEvaluator.isCorrect(e, 'ho andato'), isFalse);
    });

    test('normalization is conservative and never fuzzy', () {
      expect(normalizeAnswer(' Sono Andato '), 'sono andato');
      expect(normalizeAnswer('è\tqui'), 'è qui');
      final e = Exercise(
        id: 'z',
        reviewItemId: 'k',
        type: ExerciseType.errorCorrection,
        prompt: 'p',
        correctAnswer: 'è andato',
      );
      for (final wrong in [
        'e andato', // accents are kept
        'andato', // no word is dropped
        'è andat', // no typo tolerance
        'è andato.', // punctuation is kept
        'è  andato!',
        'e\' andato',
      ]) {
        expect(AnswerEvaluator.isCorrect(e, wrong), isFalse, reason: wrong);
      }
    });

    test('blank answers and unknown options are not answers', () {
      expect(
        AnswerEvaluator.isAnswerable(typed(ExerciseType.errorCorrection), '  '),
        isFalse,
      );
      expect(AnswerEvaluator.isAnswerable(choice(), 'hai andato'), isFalse);
      expect(AnswerEvaluator.isAnswerable(choice(), 'ho andato'), isTrue);
    });
  });

  group('state machine', () {
    test('submit moves to feedback with the outcome', () async {
      final s = _Setup(2);
      await s.start();
      expect(await s.controller.submitAnswer(' Sono Andato '), isTrue);
      expect(s.state.status, ReviewSessionStatus.feedback);
      expect(s.state.hasSubmitted, isTrue);
      expect(
        s.state.outcome,
        const AnswerOutcome(
          answer: ' Sono Andato ',
          isCorrect: true,
          correctAnswer: 'sono andato',
          explanation: 'Perché.',
        ),
      );
      expect(s.state.current, isNotNull);
      expect(s.state.position, 1);
    });

    test('a duplicate submit is ignored', () async {
      final s = _Setup(2);
      await s.start();
      expect(await s.controller.submitAnswer('sono andato'), isTrue);
      expect(await s.controller.submitAnswer('wrong'), isFalse);
      expect(s.engine.recorded, hasLength(1));
      expect(s.state.summary.correct, 1);
      expect(s.state.summary.incorrect, 0);
    });

    test('two submits at the same time record once', () async {
      final s = _Setup(2);
      await s.start();
      s.engine.recordGate = Completer<void>();
      final first = s.controller.submitAnswer('sono andato');
      expect(s.state.status, ReviewSessionStatus.submitting);
      expect(await s.controller.submitAnswer('sono andato'), isFalse);
      s.controller.continueSession(); // ignored while submitting
      expect(s.state.index, 0);
      s.engine.recordGate!.complete();
      await first;
      expect(s.engine.recorded, hasLength(1));
      expect(s.state.status, ReviewSessionStatus.feedback);
    });

    test('blank or invalid answers change nothing', () async {
      final s = _Setup(1);
      await s.start();
      expect(await s.controller.submitAnswer('   '), isFalse);
      expect(s.state.status, ReviewSessionStatus.answering);
      expect(s.engine.recorded, isEmpty);
    });

    test('continue moves to the next exercise', () async {
      final s = _Setup(3);
      await s.start();
      await s.controller.submitAnswer('x');
      s.controller.continueSession();
      expect(s.state.status, ReviewSessionStatus.answering);
      expect(s.state.position, 2);
      expect(s.state.outcome, isNull);
      expect(s.engine.recorded, hasLength(1), reason: 'continue marks nothing');
    });

    test('continue after the last exercise completes', () async {
      final s = _Setup(2);
      await s.start();
      await _answerAll(s, 'sono andato');
      expect(s.state.status, ReviewSessionStatus.completed);
      expect(s.state.current, isNull);
      expect(s.state.summary.attempted, 2);
    });

    test('submit after completion is ignored', () async {
      final s = _Setup(1);
      await s.start();
      await _answerAll(s, 'sono andato');
      expect(await s.controller.submitAnswer('sono andato'), isFalse);
      expect(s.engine.recorded, hasLength(1));
      s.controller.continueSession();
      expect(s.state.status, ReviewSessionStatus.completed);
    });

    test('continue before feedback is ignored', () async {
      final s = _Setup(3);
      await s.start();
      s.controller.continueSession();
      expect(s.state.index, 0);
      expect(s.state.status, ReviewSessionStatus.answering);
    });

    test('nothing is accepted before start or while loading', () async {
      final s = _Setup(2);
      expect(await s.controller.submitAnswer('x'), isFalse);
      s.controller.continueSession();
      expect(s.state.status, ReviewSessionStatus.idle);
    });
  });

  group('ReviewEngine integration', () {
    test('a correct answer records success, a wrong one failure', () async {
      final s = _Setup(2);
      await s.start();
      await s.controller.submitAnswer('sono andato');
      s.controller.continueSession();
      await s.controller.submitAnswer('ho andato');
      expect(s.engine.recorded, [
        ('error:e0', ReviewResult.success),
        ('error:e1', ReviewResult.failure),
      ]);
    });

    test('it is recorded immediately, before the next exercise', () async {
      final s = _Setup(2);
      await s.start();
      await s.controller.submitAnswer('sono andato');
      expect(s.engine.recorded, hasLength(1));
      expect(s.state.status, ReviewSessionStatus.feedback);
    });

    test(
      'a ReviewEngine failure is a session error, never a success',
      () async {
        final s = _Setup(2);
        await s.start();
        s.engine.recordFailure = const StorageFailure('disk');
        await s.controller.submitAnswer('sono andato');
        expect(s.state.status, ReviewSessionStatus.error);
        expect(s.state.failure, isA<StorageFailure>());
        expect(s.state.summary.attempted, 0);
        expect(s.state.outcome, isNull);
        expect(s.engine.recorded, isEmpty);
      },
    );

    test('queue and learning-memory failures are session errors', () async {
      final a = _Setup(2);
      a.engine.queueFailure = const StorageFailure('queue');
      await a.start();
      expect(a.state.status, ReviewSessionStatus.error);

      final b = _Setup(2);
      b.learning.failure = const StorageFailure('memory');
      await b.start();
      expect(b.state.status, ReviewSessionStatus.error);
      expect(b.state.failure, isA<StorageFailure>());

      // A failed session can be started again.
      b.learning.failure = null;
      await b.start();
      expect(b.state.status, ReviewSessionStatus.answering);
    });

    test('the controller holds no scheduling logic', () {
      final text = File(
        'lib/features/review/presentation/review_session_controller.dart',
      ).readAsStringSync();
      for (final banned in [
        'Duration(',
        'nextReviewAt',
        'ReviewPolicy',
        'interval',
        'DateTime.now(',
        'Random',
      ]) {
        expect(text, isNot(contains(banned)), reason: banned);
      }
    });
  });

  group('session result', () {
    test('attempted, correct, incorrect and skipped', () async {
      final s = _Setup(6, unavailable: {1, 4});
      await s.start();
      expect(s.state.total, 4);
      final answers = ['sono andato', 'no', 'SONO ANDATO', 'no'];
      for (final a in answers) {
        await s.controller.submitAnswer(a);
        s.controller.continueSession();
      }
      expect(s.state.isCompleted, isTrue);
      expect(s.state.summary.attempted, 4);
      expect(s.state.summary.correct, 2);
      expect(s.state.summary.incorrect, 2);
      expect(s.state.summary.skipped, 2);
    });
  });

  group('persistence (real engine and repositories)', () {
    late InMemoryLocalStorage storage;
    late ProviderContainer container;

    setUp(() async {
      storage = InMemoryLocalStorage();
      final learning = LocalLearningRepository(storage);
      final error = LearningError(
        id: 'ho andato -> sono andato',
        category: LearningErrorCategory.grammar,
        original: 'ho andato',
        corrected: 'sono andato',
        firstSeenAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
        confidence: 0.9,
        grammarTopic: GrammarTopic.essereVsAvere,
      );
      await learning.recordError(error);
      await learning.recordError(error);
      container = ProviderContainer(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(storage),
          reviewSessionClockProvider.overrideWithValue(DateTime.now),
        ],
      );
      addTearDown(container.dispose);
      container.listen(reviewSessionControllerProvider, (_, _) {});
    });

    test(
      'review_memory changes only through the engine; learning_memory never',
      () async {
        final learningBefore = storage.data['learning_memory'];
        final controller = container.read(
          reviewSessionControllerProvider.notifier,
        );

        await controller.start();
        final state = container.read(reviewSessionControllerProvider);
        expect(state.status, ReviewSessionStatus.answering);
        expect(state.current?.correctAnswer, 'sono andato');

        // Items are created by the engine's own synchronization, which is part
        // of ReviewEngine.getReviewQueue; nothing else wrote anything yet.
        final reviewed = (await LocalReviewRepository(storage).getItems()).when(
          success: (i) => i,
          failure: (f) => fail('unexpected $f'),
        );
        expect(reviewed.every((i) => i.lastReviewedAt == null), isTrue);

        await controller.submitAnswer('sono andato');
        final after = (await LocalReviewRepository(storage).getItem(
          state.current!.reviewItemId,
        )).when(success: (i) => i, failure: (f) => fail('unexpected $f'));
        expect(after?.successfulReviews, 1);
        expect(after?.status, ReviewStatus.learning);

        expect(storage.data['learning_memory'], learningBefore);
        expect(storage.data.keys.toSet(), {'learning_memory', 'review_memory'});
      },
    );

    test('a wrong answer is recorded as a failure by the engine', () async {
      final controller = container.read(
        reviewSessionControllerProvider.notifier,
      );
      await controller.start();
      final id = container
          .read(reviewSessionControllerProvider)
          .current!
          .reviewItemId;
      await controller.submitAnswer('ho andato');
      final item = (await LocalReviewRepository(storage).getItem(
        id,
      )).when(success: (i) => i, failure: (f) => fail('unexpected $f'));
      expect(item?.failedReviews, 1);
      expect(item?.successfulReviews, 0);
    });

    test('skipped items leave review_memory untouched', () async {
      // A review item whose learning source is a topic without any error.
      final storage2 = InMemoryLocalStorage();
      final learning = LocalLearningRepository(storage2);
      await learning.recordGrammarTopicExposure(
        GrammarTopic.plural,
        at: DateTime.now(),
        wasError: true,
      );
      final c = ProviderContainer(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(storage2),
          reviewSessionClockProvider.overrideWithValue(DateTime.now),
        ],
      );
      addTearDown(c.dispose);
      c.listen(reviewSessionControllerProvider, (_, _) {});
      await c.read(reviewSessionControllerProvider.notifier).start();
      final state = c.read(reviewSessionControllerProvider);
      expect(state.status, ReviewSessionStatus.completed);
      expect(state.summary.skipped, 1);
      final items = (await LocalReviewRepository(storage2).getItems()).when(
        success: (i) => i,
        failure: (f) => fail('unexpected $f'),
      );
      expect(
        items.every((i) => i.lastReviewedAt == null && i.failedReviews == 0),
        isTrue,
      );
    });
  });
}
