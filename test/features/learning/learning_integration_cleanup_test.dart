import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/default_learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/italian_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_signal.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/practice_evidence.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_controller.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/features/review/domain/review_repository.dart';
import 'package:parla_con_me/features/review/presentation/review_session_controller.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/services/storage/local_storage.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

// Phase 10B.1: the learning revision, the single write path and the
// idempotency of the practice evidence.

final _now = DateTime(2026, 10, 6, 9);
final _later = DateTime(2026, 10, 7, 9);
const _italian = ItalianLearningRules();

LearningError _error(String id, {GrammarTopic? topic}) => LearningError(
  id: id,
  language: 'it',
  category: LearningErrorCategory.grammar,
  original: 'ho andato',
  corrected: 'sono andato',
  explanation: 'Usiamo "essere" con andare.',
  grammarTopic: topic,
  firstSeenAt: _now,
  lastSeenAt: _now,
  confidence: 0.9,
);

/// Two mistakes on a topic, so it is weak and reviewable.
Future<void> _seedTopic(LocalLearningRepository repo) async {
  for (var i = 0; i < 2; i++) {
    await repo.recordError(
      _error('ho andato -> sono andato', topic: GrammarTopic.essereVsAvere),
    );
    await repo.recordGrammarTopicExposure(
      GrammarTopic.essereVsAvere,
      at: _now,
      wasError: true,
    );
  }
}

PracticeEvidence _evidence({
  String id = 'e1',
  PracticeEvidenceSource source = PracticeEvidenceSource.review,
  PracticeEvidenceOutcome outcome = PracticeEvidenceOutcome.success,
  String language = 'it',
  GrammarTopic topic = GrammarTopic.essereVsAvere,
}) => PracticeEvidence(
  eventId: id,
  source: source,
  type: PracticeEvidenceType.production,
  outcome: outcome,
  learningLanguage: language,
  occurredAt: _later,
  grammarTopic: topic.name,
);

AIResponse _reply([List<Correction> corrections = const []]) =>
    AIResponse(message: 'Bene!', corrections: corrections);

const _andato = Correction(
  original: 'Ieri ho andato al supermercato.',
  corrected: 'Ieri sono andato al supermercato.',
  explanation: 'Con "andare" si usa "essere".',
  category: CorrectionCategory.grammar,
);

/// A storage whose writes to [failingKey] fail while [failWrites] is set.
class _FlakyStorage extends InMemoryLocalStorage {
  _FlakyStorage(this.failingKey);
  final String failingKey;
  bool failWrites = false;

  @override
  Future<Result<void>> writeString(String key, String value) async {
    if (failWrites && key == failingKey) {
      return const Failure(StorageFailure('disk error'));
    }
    return super.writeString(key, value);
  }
}

class _FailingReads implements LocalStorage {
  @override
  Future<Result<String?>> readString(String key) async =>
      const Failure(StorageFailure('disk error'));
  @override
  Future<Result<void>> writeString(String key, String value) async =>
      const Failure(StorageFailure('disk error'));
  @override
  Future<Result<void>> remove(String key) async =>
      const Failure(StorageFailure('disk error'));
}

/// A review repository whose first `saveItem` fails (a crash after the
/// learning memory heard about the answer, before the schedule was saved).
class _FlakyReviews implements ReviewRepository {
  _FlakyReviews(this._inner);
  final ReviewRepository _inner;
  bool failNext = true;

  @override
  Future<Result<void>> saveItem(ReviewItem item) async {
    if (failNext) {
      failNext = false;
      return const Failure(StorageFailure('disk error'));
    }
    return _inner.saveItem(item);
  }

  @override
  Future<Result<void>> saveItems(Iterable<ReviewItem> items) =>
      _inner.saveItems(items);
  @override
  Future<Result<ReviewItem?>> getItem(String id) => _inner.getItem(id);
  @override
  Future<Result<List<ReviewItem>>> getItems() => _inner.getItems();
  @override
  Future<Result<void>> deleteItem(String id) => _inner.deleteItem(id);
}

/// The learning and review engines as the app wires them, over [storage].
/// Calling it again over the same storage is "restarting the app".
class _App {
  _App(
    this.storage, {
    ReviewRepository Function(ReviewRepository)? wrapReviews,
  }) {
    learningRepo = LocalLearningRepository(storage);
    learning = DefaultLearningEngine(
      learningRepo,
      rules: _italian,
      clock: () => _now,
      onMemoryChanged: () => changes++,
    );
    final reviewRepo = LocalReviewRepository(storage);
    reviews = DefaultReviewEngine(
      learningRepo,
      wrapReviews?.call(reviewRepo) ?? reviewRepo,
      learningLanguage: AppLanguage.italian,
      evidence: learning,
    );
  }

  final InMemoryLocalStorage storage;
  late final LocalLearningRepository learningRepo;
  late final DefaultLearningEngine learning;
  late final DefaultReviewEngine reviews;

  /// Times the learning engine said the memory changed.
  int changes = 0;

  Future<ReviewItem> errorItem() async {
    final queue =
        ((await reviews.getReviewQueue(now: _now, limit: 50)) as Success).value
            as List<ReviewItem>;
    return queue.firstWhere((i) => i.type == ReviewItemType.error);
  }

  Future<Result<ReviewItem>> answer(ReviewItem item, {DateTime? at}) =>
      reviews.recordReviewResult(
        itemId: item.id,
        result: ReviewResult.success,
        now: at ?? _later,
        exercise: ExerciseType.errorCorrection,
      );

  Future<GrammarTopicProgress> topic() async {
    final s =
        ((await learningRepo.getLearningSummary()) as Success).value
            as LearnerLearningSummary;
    return s.grammarTopics.firstWhere(
      (p) => p.topic == GrammarTopic.essereVsAvere,
    );
  }

  List<String> applied() {
    final raw = storage.data['learning_memory'];
    if (raw == null) return const [];
    final json = jsonDecode(raw) as Map;
    return [for (final id in (json['appliedEvents'] as List? ?? [])) '$id'];
  }
}

void main() {
  group('learning revision', () {
    final profile = onboardedProfile.copyWith(
      learningLanguage: AppLanguage.italian,
    );

    ProviderContainer containerFor(InMemoryLocalStorage storage) {
      final c = ProviderContainer(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(storage),
          userLearningProfileProvider.overrideWith(
            () => PreloadedUserLearningProfileController(profile),
          ),
          reviewSessionClockProvider.overrideWithValue(() => _now),
        ],
      );
      addTearDown(c.dispose);
      c.listen(learningRevisionProvider, (_, _) {});
      return c;
    }

    test('a review answer that updates the learning memory bumps the '
        'revision, once', () async {
      final storage = InMemoryLocalStorage();
      await _seedTopic(LocalLearningRepository(storage));
      final c = containerFor(storage);
      final before = c.read(learningRevisionProvider);
      final memoryBefore = storage.data['learning_memory'];

      final session = c.read(reviewSessionControllerProvider.notifier);
      await session.start();
      final exercise = c.read(reviewSessionControllerProvider).current!;
      await session.submitAnswer(exercise.correctAnswer);

      expect(storage.data['learning_memory'], isNot(memoryBefore));
      expect(c.read(learningRevisionProvider), before + 1);
    });

    test('a failed answer is learning evidence too', () async {
      final storage = InMemoryLocalStorage();
      await _seedTopic(LocalLearningRepository(storage));
      final c = containerFor(storage);
      final before = c.read(learningRevisionProvider);

      final session = c.read(reviewSessionControllerProvider.notifier);
      await session.start();
      final exercise = c.read(reviewSessionControllerProvider).current!;
      // A wrong answer the session accepts: another option, or other text.
      final wrong = exercise.isMultipleChoice
          ? exercise.options.firstWhere((o) => o != exercise.correctAnswer)
          : 'una risposta sbagliata';
      await session.submitAnswer(wrong);

      expect(c.read(learningRevisionProvider), before + 1);
    });

    test('a review that proves nothing the memory can hold does not bump the '
        'revision', () async {
      final storage = InMemoryLocalStorage();
      final repo = LocalLearningRepository(storage);
      // A recurring mistake with no topic and no word behind it.
      await repo.recordError(_error('ho andato -> sono andato'));
      await repo.recordError(_error('ho andato -> sono andato'));
      final c = containerFor(storage);
      final before = c.read(learningRevisionProvider);
      final memoryBefore = storage.data['learning_memory'];

      final session = c.read(reviewSessionControllerProvider.notifier);
      await session.start();
      final exercise = c.read(reviewSessionControllerProvider).current!;
      await session.submitAnswer(exercise.correctAnswer);

      expect(
        storage.data['review_memory'],
        isNotNull,
        reason: 'the review itself was recorded',
      );
      expect(storage.data['learning_memory'], memoryBefore);
      expect(c.read(learningRevisionProvider), before);
    });
  });

  group('the engine says when the memory really changed', () {
    test('an analysis that wrote something notifies once', () async {
      final app = _App(InMemoryLocalStorage());
      await app.learning.analyze(
        userMessage: 'Ieri ho andato al supermercato.',
        response: _reply([_andato]),
      );
      // One error, two topics: several writes, one notification.
      expect(app.changes, 1);
    });

    test('an analysis with nothing to learn does not notify', () async {
      final app = _App(InMemoryLocalStorage());
      await app.learning.analyze(userMessage: 'Ciao!', response: _reply());
      expect(app.changes, 0);
    });

    test('an analysis that cannot be stored does not notify', () async {
      var changes = 0;
      final broken = DefaultLearningEngine(
        LocalLearningRepository(_FailingReads()),
        rules: _italian,
        onMemoryChanged: () => changes++,
      );
      final result = await broken.analyze(
        userMessage: 'x',
        response: _reply([_andato]),
      );
      expect(result, isA<Failure<void>>());
      expect(changes, 0);
    });

    test('applied evidence notifies; repeated, foreign or unknown evidence '
        'does not', () async {
      final storage = InMemoryLocalStorage();
      await _seedTopic(LocalLearningRepository(storage));
      final app = _App(storage);

      await app.learning.recordPracticeEvidence(_evidence(id: 'a'));
      expect(app.changes, 1);

      await app.learning.recordPracticeEvidence(_evidence(id: 'a'));
      expect(app.changes, 1, reason: 'the same event is not a change');

      await app.learning.recordPracticeEvidence(
        _evidence(id: 'b', language: 'en'),
      );
      expect(app.changes, 1, reason: 'another language is not ours');

      await app.learning.recordPracticeEvidence(
        _evidence(id: 'c', topic: GrammarTopic.gender),
      );
      expect(app.changes, 1, reason: 'review cannot create unknown topics');
    });

    test('an evidence that fails to be stored does not notify', () async {
      final storage = _FlakyStorage('learning_memory');
      await _seedTopic(LocalLearningRepository(storage));
      final app = _App(storage);
      storage.failWrites = true;

      final result = await app.learning.recordPracticeEvidence(_evidence());
      expect(result, isA<Failure<void>>());
      expect(app.changes, 0);
    });
  });

  group('single write path', () {
    List<File> libFiles() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    String norm(File f) => f.path.replaceAll('\\', '/');

    test('only the learning engine calls the repository write methods', () {
      const writes = [
        '.recordError(',
        '.recordVocabulary(',
        '.recordGrammarTopicExposure(',
        '.recordSuccessfulGrammarUse(',
        '.applyPracticeEvidence(',
        '.clearLearningData(',
      ];
      for (final write in writes) {
        final callers = [
          for (final f in libFiles())
            if (f.readAsStringSync().contains(write)) norm(f),
        ];
        // `recordSuccessfulGrammarUse` and `clearLearningData` have no caller
        // in the app: successes arrive as evidence, and nothing erases the
        // memory yet. They stay in the repository contract for compatibility.
        expect(
          callers,
          anyOf(
            isEmpty,
            equals([
              'lib/features/learning/domain/default_learning_engine.dart',
            ]),
          ),
          reason: write,
        );
        if (write != '.recordSuccessfulGrammarUse(' &&
            write != '.clearLearningData(') {
          expect(callers, isNotEmpty, reason: write);
        }
      }
    });

    test(
      'nobody but the learning providers builds the concrete repository',
      () {
        final builders = [
          for (final f in libFiles())
            if (!norm(f).endsWith('data/local_learning_repository.dart') &&
                f.readAsStringSync().contains('LocalLearningRepository('))
              norm(f),
        ];
        expect(builders, [
          'lib/features/learning/presentation/learning_providers.dart',
        ]);
      },
    );

    test('the conversation talks to the learning engine, not to the '
        'repository', () {
      final files = libFiles().where(
        (f) => norm(f).startsWith('lib/features/conversation/'),
      );
      expect(files, isNotEmpty);
      for (final f in files) {
        final s = f.readAsStringSync();
        expect(s, isNot(contains('LearningRepository')), reason: norm(f));
        expect(s, isNot(contains('learningRepositoryProvider')));
        expect(s, isNot(contains('learning/data/')), reason: norm(f));
      }
    });

    test('the revision only moves from the learning engine\'s hook', () {
      final movers = [
        for (final f in libFiles())
          if (f.readAsStringSync().contains(
            'learningRevisionProvider.notifier',
          ))
            norm(f),
      ];
      expect(movers, [
        'lib/features/learning/presentation/learning_providers.dart',
      ]);
    });

    test('a topic that came up without a mistake still goes through the '
        'engine, as a plain exposure', () async {
      final storage = InMemoryLocalStorage();
      final app = _App(storage);
      await app.learning.apply(
        LearningSignal(
          id: 's1',
          type: LearningSignalType.topicExposure,
          source: LearningSignalSource.ruleInference,
          createdAt: _now,
          confidence: 0.8,
          metadata: {SignalKeys.topic: GrammarTopic.essereVsAvere.name},
        ),
      );
      final t = await app.topic();
      expect(t.exposureCount, 1);
      expect(t.successfulUseCount, 0);
      expect(t.errorCount, 0);
      expect(app.changes, 1);
    });
  });

  group('idempotency', () {
    test('one review attempt, two deliveries: one update', () async {
      final storage = InMemoryLocalStorage();
      await _seedTopic(LocalLearningRepository(storage));
      final app = _App(storage);
      final item = await app.errorItem();
      await app.answer(item);
      final once = storage.data['learning_memory'];

      // The very same event, as the review engine would send it again.
      final event = app.applied().single;
      expect(event, startsWith('review:${item.id}:attempt:'));
      await app.learning.recordPracticeEvidence(
        PracticeEvidence(
          eventId: event,
          source: PracticeEvidenceSource.review,
          type: PracticeEvidenceType.production,
          outcome: PracticeEvidenceOutcome.success,
          learningLanguage: 'it',
          occurredAt: _later,
          grammarTopic: GrammarTopic.essereVsAvere.name,
        ),
      );
      expect(storage.data['learning_memory'], once);
    });

    test('after a restart the same event is still one update', () async {
      final storage = InMemoryLocalStorage();
      await _seedTopic(LocalLearningRepository(storage));
      final first = _App(storage);
      await first.learning.recordPracticeEvidence(_evidence(id: 'r1'));
      final once = storage.data['learning_memory'];

      final restarted = _App(storage);
      await restarted.learning.recordPracticeEvidence(_evidence(id: 'r1'));

      expect(storage.data['learning_memory'], once);
      expect(restarted.changes, 0);
    });

    test('a crash after the learning memory heard, before the schedule was '
        'saved: the retry after a restart counts once', () async {
      final storage = InMemoryLocalStorage();
      await _seedTopic(LocalLearningRepository(storage));
      final crashing = _App(storage, wrapReviews: (r) => _FlakyReviews(r));
      final item = await crashing.errorItem();
      final failed = await crashing.answer(item);
      expect(failed, isA<Failure<ReviewItem>>());
      final afterCrash = await crashing.topic();
      expect(crashing.changes, 1);

      // The app is restarted and the learner answers the same item again.
      final restarted = _App(storage);
      final retry = await restarted.answer(await restarted.errorItem());
      expect(retry, isA<Success<ReviewItem>>());

      final after = await restarted.topic();
      expect(after.weightedSuccesses, afterCrash.weightedSuccesses);
      expect(after.weightedExposure, afterCrash.weightedExposure);
      expect(restarted.changes, 0, reason: 'nothing new for the memory');
    });

    test('once the schedule is saved, the next answer is a new attempt and '
        'counts', () async {
      final storage = InMemoryLocalStorage();
      await _seedTopic(LocalLearningRepository(storage));
      final app = _App(storage);
      final item = await app.errorItem();
      final a = await app.topic();

      await app.answer(item, at: _later);
      var current =
          ((await app.reviews.synchronize(now: _later)) as Success).value
              as List<ReviewItem>;
      final again = current.firstWhere((i) => i.id == item.id);
      await app.answer(again, at: _later.add(const Duration(days: 2)));
      current =
          ((await app.reviews.synchronize(now: _later)) as Success).value
              as List<ReviewItem>;
      final third = current.firstWhere((i) => i.id == item.id);
      await app.answer(third, at: _later.add(const Duration(days: 8)));

      final ids = app.applied();
      expect(ids, hasLength(3));
      expect(ids.toSet(), hasLength(3));
      expect(ids.map((i) => i.split(':').last), ['1', '2', '3']);
      final b = await app.topic();
      expect(b.weightedSuccesses, a.weightedSuccesses + 3 * 0.5);
      expect(app.changes, 3);
    });

    test('a learning memory that could not be written does not remember the '
        'event: the retry applies it once', () async {
      final storage = _FlakyStorage('learning_memory');
      await _seedTopic(LocalLearningRepository(storage));
      final app = _App(storage);
      final before = await app.topic();

      storage.failWrites = true;
      final failed = await app.learning.recordPracticeEvidence(
        _evidence(id: 'retry'),
      );
      expect(failed, isA<Failure<void>>());
      storage.failWrites = false;
      expect((await app.topic()).weightedSuccesses, before.weightedSuccesses);
      expect(app.applied(), isEmpty);

      await app.learning.recordPracticeEvidence(_evidence(id: 'retry'));
      await app.learning.recordPracticeEvidence(_evidence(id: 'retry'));

      final after = await app.topic();
      expect(after.weightedSuccesses, before.weightedSuccesses + 0.5);
      expect(app.changes, 1);
    });

    test('the window keeps an event while fewer than 200 others have come '
        'after it', () async {
      final storage = InMemoryLocalStorage();
      await _seedTopic(LocalLearningRepository(storage));
      final app = _App(storage);
      await app.learning.recordPracticeEvidence(_evidence(id: 'first'));
      for (var i = 0; i < 199; i++) {
        await app.learning.recordPracticeEvidence(_evidence(id: 'n$i'));
      }
      final before = storage.data['learning_memory'];

      await app.learning.recordPracticeEvidence(_evidence(id: 'first'));
      expect(storage.data['learning_memory'], before);
    });

    test('conversation evidence is never remembered: it has no identity '
        'outside the analysis that made it', () async {
      final storage = InMemoryLocalStorage();
      await _seedTopic(LocalLearningRepository(storage));
      final app = _App(storage);
      await app.learning.recordPracticeEvidence(
        _evidence(id: 'c1', source: PracticeEvidenceSource.conversation),
      );
      expect(app.applied(), isEmpty);
    });
  });
}
