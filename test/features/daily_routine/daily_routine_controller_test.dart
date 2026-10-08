import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/daily_routine/data/local_daily_routine_repository.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine_repository.dart';
import 'package:parla_con_me/features/daily_routine/presentation/daily_routine_controller.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_overview.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_controller.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/features/review/presentation/review_providers.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/learning_fixtures.dart';

DateTime _clock = DateTime(2026, 10, 6, 9);

class _Reviews implements ReviewEngine {
  _Reviews(this.queue);
  List<ReviewItem> queue;
  AppFailure? failure;
  int calls = 0;

  @override
  Future<Result<List<ReviewItem>>> getReviewQueue({
    required DateTime now,
    int limit = 10,
  }) async {
    calls++;
    return failure != null ? Failure(failure!) : Success(queue);
  }

  @override
  Future<Result<ReviewItem>> recordReviewResult({
    required String itemId,
    required ReviewResult result,
    required DateTime now,
    ExerciseType? exercise,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<ReviewItem>>> synchronize({required DateTime now}) =>
      throw UnimplementedError();
}

class _Learning implements LearningEngine {
  _Learning(this.value);
  LearnerLearningSummary value;

  @override
  Future<Result<LearnerLearningSummary>> summary() async => Success(value);
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
  }) => throw UnimplementedError();
}

/// Wraps the real repository to hold or fail a save.
class _SlowRepository implements DailyRoutineRepository {
  _SlowRepository(this.inner);
  final DailyRoutineRepository inner;
  Completer<void>? saveGate;
  bool failSaves = false;
  int saves = 0;

  @override
  Future<Result<DailyRoutine?>> load(String date, AppLanguage language) =>
      inner.load(date, language);

  @override
  Future<Result<void>> save(DailyRoutine routine) async {
    saves++;
    await saveGate?.future;
    if (failSaves) return const Failure(StorageFailure('disk'));
    return inner.save(routine);
  }
}

LearningError _error(int i) => LearningError(
  id: 'io ho andato $i -> sono andato $i',
  category: LearningErrorCategory.grammar,
  original: 'io ho andato $i',
  corrected: 'sono andato $i',
  frequency: 2,
  firstSeenAt: DateTime.now(),
  lastSeenAt: DateTime.now(),
  confidence: 0.9,
);

const _italian = UserLearningProfile(
  level: LanguageLevel.a2,
  goals: {LearningGoal.work},
  focusAreas: {LearningFocus.conversation},
  onboardingCompleted: true,
);

class _Harness {
  _Harness({List<LearningError>? errors}) {
    final list = errors ?? [for (var i = 0; i < 3; i++) _error(i)];
    reviews = _Reviews([
      for (final e in list)
        ReviewItem.discovered(ReviewItemType.error, e.id, _clock),
    ]);
    learning = _Learning(summaryOf(errors: list, vocabulary: [wordOf('ciao')]));
    repository = _SlowRepository(LocalDailyRoutineRepository(storage));
    container = ProviderContainer(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(storage),
        userLearningProfileProvider.overrideWith(
          () => PreloadedUserLearningProfileController(_italian),
        ),
        reviewEngineProvider.overrideWithValue(reviews),
        learningEngineProvider.overrideWithValue(learning),
        dailyRoutineRepositoryProvider.overrideWithValue(repository),
        dailyRoutineClockProvider.overrideWithValue(() => _clock),
      ],
    );
    addTearDown(container.dispose);
    container.listen(dailyRoutineProvider, (_, _) {});
  }

  final storage = InMemoryLocalStorage();
  late final _Reviews reviews;
  late final _Learning learning;
  late final _SlowRepository repository;
  late final ProviderContainer container;

  AsyncValue<DailyRoutine> get state => container.read(dailyRoutineProvider);
  DailyRoutineController get controller =>
      container.read(dailyRoutineProvider.notifier);
  Future<DailyRoutine> get ready => container.read(dailyRoutineProvider.future);
}

void main() {
  setUp(() => _clock = DateTime(2026, 10, 6, 9));

  group('loading', () {
    test('starts loading, then data, and saves what it planned', () async {
      final h = _Harness();
      expect(h.state, isA<AsyncLoading<DailyRoutine>>());
      final routine = await h.ready;
      expect(h.state, isA<AsyncData<DailyRoutine>>());
      expect(routine.key, '2026-10-06|it');
      expect(routine.step1.itemIds, hasLength(3));
      expect(h.repository.saves, 1);
      expect(h.storage.data['daily_routine'], isNotNull);
    });

    test('an existing routine is reloaded, never planned again', () async {
      final first = _Harness();
      final planned = await first.ready;
      await first.controller.completeStep(1);

      // A new "app launch" over the same storage, with a different memory.
      final second = _Harness(errors: []);
      await second.storage.writeString(
        'daily_routine',
        first.storage.data['daily_routine']!,
      );
      second.container.invalidate(dailyRoutineProvider);
      final loaded = await second.ready;
      expect(loaded.step1.state, RoutineStepState.completed);
      expect(loaded.step1.itemIds, planned.step1.itemIds);
      expect(second.reviews.calls, 0, reason: 'did not ask the engines again');
    });

    test('a failing planner is an error, with retry', () async {
      final h = _Harness();
      h.reviews.failure = const StorageFailure('disk');
      await expectLater(h.ready, throwsA(isA<StorageFailure>()));
      expect(h.state, isA<AsyncError<DailyRoutine>>());
      expect(h.storage.data['daily_routine'], isNull, reason: 'nothing saved');

      h.reviews.failure = null;
      h.controller.retry();
      final routine = await h.ready;
      expect(routine.step1.state, RoutineStepState.pending);
    });

    test('if it cannot be saved the routine is still shown', () async {
      final h = _Harness();
      h.repository.failSaves = true;
      final routine = await h.ready;
      expect(routine.step1.itemIds, isNotEmpty);
      expect(h.state, isA<AsyncData<DailyRoutine>>());
    });
  });

  group('completing steps', () {
    test('in order, each saved', () async {
      final h = _Harness();
      await h.ready;
      expect(await h.controller.completeStep(1), isTrue);
      expect(h.state.value!.status, RoutineStatus.step1Completed);
      expect(await h.controller.completeStep(2), isTrue);
      expect(await h.controller.completeStep(3), isTrue);
      expect(h.state.value!.status, RoutineStatus.completed);

      final stored =
          (await h.repository.load('2026-10-06', AppLanguage.italian)
                  as Success<DailyRoutine?>)
              .value;
      expect(stored, h.state.value);
    });

    test('invalid jumps and repeats are ignored and save nothing', () async {
      final h = _Harness();
      await h.ready;
      final savesBefore = h.repository.saves;
      expect(await h.controller.completeStep(2), isFalse);
      expect(await h.controller.completeStep(3), isFalse);
      expect(await h.controller.completeStep(0), isFalse);
      expect(await h.controller.completeStep(9), isFalse);
      await h.controller.completeStep(1);
      expect(await h.controller.completeStep(1), isFalse);
      expect(h.state.value!.step2.state, RoutineStepState.pending);
      expect(h.repository.saves, savesBefore + 1);
    });

    test('a double tap while saving counts once', () async {
      final h = _Harness();
      await h.ready;
      h.repository.saveGate = Completer<void>();
      final first = h.controller.completeStep(1);
      final second = h.controller.completeStep(1);
      expect(await second, isFalse, reason: 'busy');
      h.repository.saveGate!.complete();
      expect(await first, isTrue);
      expect(h.state.value!.completedCount, 1);
    });

    test('if saving fails the step is not marked as done', () async {
      final h = _Harness();
      await h.ready;
      h.repository.failSaves = true;
      expect(await h.controller.completeStep(1), isFalse);
      expect(h.state.value!.step1.state, RoutineStepState.pending);
      h.repository.failSaves = false;
      expect(await h.controller.completeStep(1), isTrue);
    });

    test('before the routine is loaded nothing completes', () async {
      final h = _Harness();
      expect(await h.controller.completeStep(1), isFalse);
      await h.ready;
    });
  });

  group('language and day', () {
    test('changing the language loads that language\'s own routine', () async {
      final h = _Harness();
      final italian = await h.ready;
      await h.controller.completeStep(1);

      await h.container
          .read(userLearningProfileProvider.notifier)
          .save(_italian.copyWith(learningLanguage: AppLanguage.english));
      final english = await h.ready;
      expect(english.key, '2026-10-06|en');
      expect(english.step1.state, isNot(RoutineStepState.completed));
      expect(english.step1.itemIds, isEmpty, reason: 'no English memory');

      await h.container
          .read(userLearningProfileProvider.notifier)
          .save(_italian);
      final back = await h.ready;
      expect(back.key, italian.key);
      expect(back.step1.state, RoutineStepState.completed);
    });

    test('a new day makes a new routine when refreshed', () async {
      final h = _Harness();
      final today = await h.ready;
      h.controller.refreshForToday();
      expect(identical(await h.ready, today), isTrue, reason: 'same day');

      _clock = DateTime(2026, 10, 7, 8);
      h.controller.refreshForToday();
      final tomorrow = await h.ready;
      expect(tomorrow.date, '2026-10-07');
    });
  });
}
