import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/services/storage/local_storage.dart';

import '../../support/in_memory_local_storage.dart';

final _now = DateTime.utc(2026, 10, 20, 12);

String _read(String path) => File(path).readAsStringSync();

T _ok<T>(Result<T> r) =>
    r.when(success: (v) => v, failure: (f) => fail('unexpected $f'));

LearningError _error(String id, {DateTime? at, int times = 2}) => LearningError(
  id: id,
  category: LearningErrorCategory.grammar,
  original: id.split(' -> ').first,
  corrected: id.split(' -> ').last,
  firstSeenAt: at ?? _now,
  lastSeenAt: at ?? _now,
  confidence: 0.9,
  frequency: times,
);

class _FailingWrites extends InMemoryLocalStorage {
  bool failWrites = false;

  @override
  Future<Result<void>> writeString(String key, String value) async => failWrites
      ? const Failure(StorageFailure('disk full'))
      : super.writeString(key, value);
}

void main() {
  late InMemoryLocalStorage storage;
  late LocalLearningRepository learning;
  late LocalReviewRepository reviews;
  late DefaultReviewEngine engine;

  DefaultReviewEngine engineFor(AppLanguage language) =>
      DefaultReviewEngine(learning, reviews, learningLanguage: language);

  setUp(() {
    storage = InMemoryLocalStorage();
    learning = LocalLearningRepository(storage);
    reviews = LocalReviewRepository(storage);
    engine = engineFor(AppLanguage.italian);
  });

  Future<List<ReviewItem>> queue({DateTime? at, int limit = 10}) async =>
      _ok(await engine.getReviewQueue(now: at ?? _now, limit: limit));

  Future<void> seedError(String id, {int times = 2, DateTime? at}) async {
    for (var i = 0; i < times; i++) {
      await learning.recordError(_error(id, times: 1, at: at));
    }
  }

  group('ReviewPolicy / scheduling', () {
    ReviewItem fresh() =>
        ReviewItem.discovered(ReviewItemType.error, 'a -> b', _now);

    test('successive successes: 1, 3, 7, 14, 30, 30 days', () {
      var item = fresh();
      var at = _now;
      final expected = [1, 3, 7, 14, 30, 30];
      for (var i = 0; i < expected.length; i++) {
        item = item.recordResult(ReviewResult.success, at);
        expect(item.interval, Duration(days: expected[i]), reason: 'step $i');
        expect(item.nextReviewAt, at.add(Duration(days: expected[i])));
        expect(item.successfulReviews, i + 1);
        expect(item.lastReviewedAt, at);
        at = item.nextReviewAt;
      }
    });

    test('status: fresh -> learning -> review -> mastered (conservative)', () {
      var item = fresh();
      expect(item.status, ReviewStatus.fresh);
      final statuses = <ReviewStatus>[];
      for (var i = 0; i < 5; i++) {
        item = item.recordResult(ReviewResult.success, _now);
        statuses.add(item.status);
      }
      expect(statuses, [
        ReviewStatus.learning,
        ReviewStatus.review,
        ReviewStatus.review,
        ReviewStatus.review,
        ReviewStatus.mastered,
      ]);
    });

    test('one success never masters; a failure breaks the progression', () {
      var item = fresh().recordResult(ReviewResult.success, _now);
      expect(item.status, isNot(ReviewStatus.mastered));

      // Four successes, a failure, then four more: still not mastered.
      item = fresh();
      for (var i = 0; i < 4; i++) {
        item = item.recordResult(ReviewResult.success, _now);
      }
      item = item.recordResult(ReviewResult.failure, _now);
      for (var i = 0; i < 4; i++) {
        item = item.recordResult(ReviewResult.success, _now);
      }
      expect(item.successfulReviews, 8);
      expect(item.status, isNot(ReviewStatus.mastered));
    });

    test('failure: counters, zero interval, short retry, back to learning', () {
      var item = fresh();
      for (var i = 0; i < 5; i++) {
        item = item.recordResult(ReviewResult.success, _now);
      }
      final failed = item.recordResult(ReviewResult.failure, _now);
      expect(failed.failedReviews, 1);
      expect(failed.successfulReviews, 5, reason: 'history is kept');
      expect(failed.consecutiveSuccesses, 0);
      expect(failed.interval, Duration.zero);
      expect(failed.status, ReviewStatus.learning);
      expect(failed.nextReviewAt, _now.add(ReviewPolicy.failureRetryDelay));
      expect(failed.lastReviewedAt, _now);

      // The progression restarts at 1 day.
      expect(
        failed.recordResult(ReviewResult.success, _now).interval,
        const Duration(days: 1),
      );
    });

    test('intervals are never negative and times are UTC', () {
      final local = DateTime(2026, 10, 20, 12);
      final item = fresh().recordResult(ReviewResult.failure, local);
      expect(item.interval.isNegative, isFalse);
      expect(item.nextReviewAt.isUtc, isTrue);
      expect(ReviewPolicy.intervalAfterSuccesses(-3), Duration.zero);
    });

    test('recording is deterministic', () {
      expect(
        fresh().recordResult(ReviewResult.success, _now),
        fresh().recordResult(ReviewResult.success, _now),
      );
    });
  });

  group('candidates', () {
    test(
      'a recurring error becomes a candidate; a single one does not',
      () async {
        await seedError('ho andato -> sono andato');
        await seedError('un errore -> uno sbaglio', times: 1);
        final items = await queue();
        expect(items.map((i) => i.id), ['error:ho andato -> sono andato']);
        expect(items.single.status, ReviewStatus.fresh);
      },
    );

    test('a grammar topic with errors becomes a candidate', () async {
      await learning.recordGrammarTopicExposure(
        GrammarTopic.articles,
        at: _now,
        wasError: true,
      );
      // Exposed without errors: nothing to review.
      await learning.recordGrammarTopicExposure(GrammarTopic.plural, at: _now);
      final items = await queue();
      expect(items.map((i) => i.id), ['grammar:articles']);
    });

    test('vocabulary needing reinforcement becomes a candidate', () async {
      await learning.recordVocabulary(
        UserVocabulary.of(word: 'Prenotazione', at: _now, language: 'it'),
      );
      // A well-known word is not a candidate.
      await learning.recordVocabulary(
        UserVocabulary.of(
          word: 'ciao',
          at: _now,
          language: 'it',
          exposureCount: 5,
          successfulUseCount: 5,
        ),
      );
      final items = await queue();
      expect(items.map((i) => i.id), ['vocabulary:it:prenotazione']);
    });

    test('ids are stable and repeated syncs never duplicate', () async {
      await seedError('ho andato -> sono andato');
      await learning.recordGrammarTopicExposure(
        GrammarTopic.articles,
        at: _now,
        wasError: true,
      );
      final first = _ok(await engine.synchronize(now: _now));
      final second = _ok(await engine.synchronize(now: _now));
      // A brand new engine over the same storage (a restart).
      final third = _ok(
        await engineFor(AppLanguage.italian).synchronize(now: _now),
      );
      expect(first.map((i) => i.id), second.map((i) => i.id));
      expect(third.map((i) => i.id), first.map((i) => i.id));
      expect(_ok(await reviews.getItems()), hasLength(2));
    });

    test(
      'a candidate that is already gone from learning memory is ignored',
      () async {
        await seedError('ho andato -> sono andato');
        await queue();
        await learning.clearLearningData();
        expect(await queue(), isEmpty);
        expect(
          _ok(await reviews.getItems()),
          hasLength(1),
          reason: 'not deleted',
        );
      },
    );
  });

  group('queue', () {
    test('new items are returned, future-scheduled ones are not', () async {
      await seedError('a -> b');
      var items = await queue();
      expect(items, hasLength(1));

      await engine.recordReviewResult(
        itemId: items.single.id,
        result: ReviewResult.success,
        now: _now,
      );
      expect(await queue(), isEmpty, reason: 'due again tomorrow');
      expect(
        await queue(at: _now.add(const Duration(hours: 23, minutes: 59))),
        isEmpty,
      );
      items = await queue(at: _now.add(const Duration(days: 1)));
      expect(items.single.successfulReviews, 1, reason: 'due at the boundary');
    });

    test('a failed item is not handed out again immediately', () async {
      await seedError('a -> b');
      final id = (await queue()).single.id;
      await engine.recordReviewResult(
        itemId: id,
        result: ReviewResult.failure,
        now: _now,
      );
      expect(await queue(), isEmpty);
      expect(
        await queue(at: _now.add(ReviewPolicy.failureRetryDelay)),
        hasLength(1),
      );
    });

    test('mastered items stay out until they are due again', () async {
      await seedError('a -> b');
      final id = (await queue()).single.id;
      var at = _now;
      late ReviewItem item;
      for (var i = 0; i < 5; i++) {
        item = _ok(
          await engine.recordReviewResult(
            itemId: id,
            result: ReviewResult.success,
            now: at,
          ),
        );
        at = item.nextReviewAt;
      }
      expect(item.status, ReviewStatus.mastered);
      expect(await queue(at: at.subtract(const Duration(days: 1))), isEmpty);
      expect(await queue(at: at), hasLength(1));
    });

    test('limit is respected and order is deterministic', () async {
      await seedError('b -> b1', times: 3);
      await seedError('a -> a1', times: 3); // same priority as b
      await seedError('c -> c1', times: 6); // higher priority
      await seedError('d -> d1', times: 2); // lower priority

      final all = await queue();
      expect(all.map((i) => i.sourceId), [
        'c -> c1',
        'a -> a1', // tie: same priority and same nextReviewAt -> by id
        'b -> b1',
        'd -> d1',
      ]);
      expect(all.map((i) => i.priority), isNot(contains(0)));
      expect(all[0].priority, greaterThan(all[1].priority));
      expect(all[1].priority, all[2].priority);

      expect((await queue(limit: 2)).map((i) => i.sourceId), [
        'c -> c1',
        'a -> a1',
      ]);
      expect(await queue(limit: 0), isEmpty);
      // Repeating gives exactly the same answer.
      expect(await queue(), all);
    });

    test('older nextReviewAt wins when priority ties', () async {
      await seedError('a -> a1', times: 3);
      await seedError('b -> b1', times: 3);
      final a = (await queue()).firstWhere((i) => i.sourceId == 'a -> a1');
      // Review `a` into the past-due state: due earlier than `b`'s creation.
      await reviews.saveItem(
        ReviewItem(
          type: a.type,
          sourceId: a.sourceId,
          firstSeenAt: _now.subtract(const Duration(days: 9)),
          nextReviewAt: _now.subtract(const Duration(days: 2)),
          lastReviewedAt: _now.subtract(const Duration(days: 8)),
          status: ReviewStatus.learning,
        ),
      );
      await reviews.saveItem(
        ReviewItem(
          type: ReviewItemType.error,
          sourceId: 'b -> b1',
          firstSeenAt: _now,
          nextReviewAt: _now,
        ),
      );
      final items = await queue();
      expect(items.map((i) => i.sourceId), ['a -> a1', 'b -> b1']);
    });

    test('recording an unknown item is a failure, not a crash', () async {
      final r = await engine.recordReviewResult(
        itemId: 'error:nope',
        result: ReviewResult.success,
        now: _now,
      );
      expect(r, isA<Failure<ReviewItem>>());
    });
  });

  group('synchronization', () {
    test(
      'existing schedule survives new observations of other things',
      () async {
        await seedError('a -> b');
        final id = (await queue()).single.id;
        await engine.recordReviewResult(
          itemId: id,
          result: ReviewResult.success,
          now: _now,
        );
        final before = _ok(await reviews.getItem(id))!;

        await seedError('c -> d'); // a new observation elsewhere
        await learning.recordGrammarTopicExposure(
          GrammarTopic.articles,
          at: _now,
          wasError: true,
        );
        _ok(await engine.synchronize(now: _now));
        _ok(await engine.synchronize(now: _now));

        expect(_ok(await reviews.getItem(id)), before);
      },
    );

    test(
      'the same mistake again raises priority without erasing history',
      () async {
        await seedError('a -> b', at: _now.subtract(const Duration(days: 30)));
        final id = ReviewItem.idFor(ReviewItemType.error, 'a -> b');
        final at = _now.subtract(const Duration(days: 29));
        _ok(await engine.synchronize(now: at));
        await engine.recordReviewResult(
          itemId: id,
          result: ReviewResult.success,
          now: at,
        );
        var item = _ok(await reviews.getItem(id))!;
        expect(item.nextReviewAt, at.add(const Duration(days: 1)));
        final oldPriority = _ok(
          await engine.synchronize(now: _now),
        ).firstWhere((i) => i.id == id).priority;

        // The learner makes the mistake again, after the last review.
        await learning.recordError(_error('a -> b', times: 1, at: _now));
        final synced = _ok(await engine.synchronize(now: _now));
        item = _ok(await reviews.getItem(id))!;

        expect(
          synced.firstWhere((i) => i.id == id).priority,
          greaterThan(oldPriority),
        );
        expect(item.successfulReviews, 1, reason: 'history kept');
        expect(item.lastReviewedAt, at);
        expect(item.firstSeenAt, at);
        expect(item.consecutiveSuccesses, 0);
        expect(item.isDue(_now), isTrue);

        // Syncing again does not keep reopening it.
        await engine.recordReviewResult(
          itemId: id,
          result: ReviewResult.success,
          now: _now,
        );
        final after = _ok(await reviews.getItem(id))!;
        _ok(await engine.synchronize(now: _now));
        expect(_ok(await reviews.getItem(id)), after);
      },
    );

    test(
      'a failing save does not fail the call or lose learning memory',
      () async {
        final flaky = _FailingWrites();
        final learningRepo = LocalLearningRepository(flaky);
        await learningRepo.recordError(_error('a -> b', times: 1));
        await learningRepo.recordError(_error('a -> b', times: 1));
        final eng = DefaultReviewEngine(
          learningRepo,
          LocalReviewRepository(flaky),
          learningLanguage: AppLanguage.italian,
        );
        flaky.failWrites = true;
        final items = _ok(await eng.synchronize(now: _now));
        expect(items, hasLength(1));
        flaky.failWrites = false;
        expect(
          _ok(await learningRepo.getLearningSummary()).errors.single.frequency,
          2,
        );
      },
    );

    test('an unreadable learning memory is reported, not thrown', () async {
      final eng = DefaultReviewEngine(
        _FailingLearning(),
        reviews,
        learningLanguage: AppLanguage.italian,
      );
      expect(
        await eng.getReviewQueue(now: _now),
        isA<Failure<List<ReviewItem>>>(),
      );
    });
  });

  group('language', () {
    test('only vocabulary of the learning language is reviewed', () async {
      await learning.recordVocabulary(
        UserVocabulary.of(word: 'prenotazione', at: _now, language: 'it'),
      );
      await learning.recordVocabulary(
        UserVocabulary.of(word: 'reserva', at: _now, language: 'es'),
      );
      expect((await queue()).map((i) => i.id), ['vocabulary:it:prenotazione']);

      // Same memory, an engine configured with another language code. This
      // only proves the language comes from configuration; no second learning
      // language is supported by the app.
      engine = engineFor(AppLanguage.spanish);
      expect((await queue()).map((i) => i.id), ['vocabulary:es:reserva']);
    });

    test('the review engine sources contain no hardcoded language code', () {
      // Guard against re-introducing a literal language in the new feature.
      final src = [
        'lib/features/review/domain/review_engine.dart',
        'lib/features/review/domain/review_item.dart',
        'lib/features/review/data/local_review_repository.dart',
      ];
      for (final path in src) {
        final text = _read(path);
        expect(text, isNot(contains("'it'")), reason: path);
        expect(text, isNot(contains('"it"')), reason: path);
      }
    });
  });

  group('persistence', () {
    ReviewItem full() => ReviewItem(
      type: ReviewItemType.vocabulary,
      sourceId: 'it:ciao',
      status: ReviewStatus.review,
      firstSeenAt: _now,
      lastReviewedAt: _now.add(const Duration(days: 1)),
      nextReviewAt: _now.add(const Duration(days: 4)),
      interval: const Duration(days: 3),
      successfulReviews: 2,
      failedReviews: 1,
      consecutiveSuccesses: 2,
    );

    Map<String, Object?> stored(ReviewItem i) => {
      'id': i.id,
      'type': i.type.name,
      'sourceId': i.sourceId,
      'status': i.status.name,
      'firstSeenAt': i.firstSeenAt.toIso8601String(),
      'lastReviewedAt': i.lastReviewedAt?.toIso8601String(),
      'nextReviewAt': i.nextReviewAt.toIso8601String(),
      'intervalSeconds': i.interval.inSeconds,
      'successfulReviews': i.successfulReviews,
      'failedReviews': i.failedReviews,
      'consecutiveSuccesses': i.consecutiveSuccesses,
    };

    void write(Object? items, {Object? version = 1}) =>
        storage.data['review_memory'] = jsonEncode({
          'version': version,
          'items': items,
        });

    test('save, load, version 1, separate key', () async {
      await reviews.saveItem(full());
      expect(_ok(await reviews.getItems()), [full()]);
      expect(_ok(await reviews.getItem(full().id)), full());
      expect(_ok(await reviews.getItem('nope')), isNull);
      final doc = jsonDecode(storage.data['review_memory']!) as Map;
      expect(doc['version'], 1);
      expect(storage.data.containsKey('learning_memory'), isFalse);

      // A restart (new repository over the same storage).
      expect(_ok(await LocalReviewRepository(storage).getItems()), [full()]);

      await reviews.deleteItem(full().id);
      expect(_ok(await reviews.getItems()), isEmpty);
    });

    test('review memory never touches learning_memory', () async {
      await seedError('a -> b');
      final before = storage.data['learning_memory'];
      await queue();
      await engine.recordReviewResult(
        itemId: 'error:a -> b',
        result: ReviewResult.failure,
        now: _now,
      );
      expect(storage.data['learning_memory'], before);
    });

    test('corrupt documents read as empty and can be overwritten', () async {
      for (final bad in ['{not json', '[]', '"x"', '{"version":"1"}', '{}']) {
        storage.data['review_memory'] = bad;
        expect(_ok(await reviews.getItems()), isEmpty, reason: bad);
      }
      storage.data['review_memory'] = '{not json';
      await reviews.saveItem(full());
      expect(_ok(await reviews.getItems()), [full()]);
    });

    test('malformed items are skipped, the rest survives', () async {
      final good = stored(full());
      write([
        good,
        'garbage',
        {...good, 'id': 'vocabulary:it:other', 'type': 'pronunciation'},
        {...good, 'id': 'vocabulary:it:s', 'sourceId': 's', 'status': 'x'},
        {
          ...good,
          'id': 'vocabulary:it:d',
          'sourceId': 'd',
          'nextReviewAt': 'nope',
        },
        {
          ...good,
          'id': 'vocabulary:it:e',
          'sourceId': 'e',
          'lastReviewedAt': 'nope',
        },
        {
          ...good,
          'id': 'vocabulary:it:m',
          'sourceId': 'm',
          'failedReviews': 'many',
        },
        {...good, 'id': 'wrong-id'},
        {...good, 'sourceId': ''},
      ]);
      expect(_ok(await reviews.getItems()), [full()]);
    });

    test('negative numbers are normalized to zero', () async {
      write([
        {
          ...stored(full()),
          'intervalSeconds': -5,
          'successfulReviews': -1,
          'failedReviews': -2,
          'consecutiveSuccesses': -3,
        },
      ]);
      final item = _ok(await reviews.getItems()).single;
      expect(item.interval, Duration.zero);
      expect(item.successfulReviews, 0);
      expect(item.failedReviews, 0);
      expect(item.consecutiveSuccesses, 0);
    });

    test('duplicate ids keep the most recently reviewed one', () async {
      final older = stored(full());
      final newer = {
        ...older,
        'lastReviewedAt': _now.add(const Duration(days: 2)).toIso8601String(),
        'successfulReviews': 9,
      };
      for (final order in [
        [older, newer],
        [newer, older],
      ]) {
        write(order);
        final items = _ok(await reviews.getItems());
        expect(items, hasLength(1));
        expect(items.single.successfulReviews, 9);
      }
    });

    test('a newer version is reported and never overwritten', () async {
      write([stored(full())], version: 2);
      expect(await reviews.getItems(), isA<Failure<List<ReviewItem>>>());
      expect(await reviews.saveItem(full()), isA<Failure<void>>());
      expect((jsonDecode(storage.data['review_memory']!) as Map)['version'], 2);
    });
  });
}

class _FailingLearning extends LocalLearningRepository {
  _FailingLearning() : super(_Unreadable());
}

class _Unreadable implements LocalStorage {
  @override
  Future<Result<String?>> readString(String key) async =>
      const Failure(StorageFailure('unreadable'));
  @override
  Future<Result<void>> writeString(String key, String value) async =>
      const Failure(StorageFailure('unreadable'));
  @override
  Future<Result<void>> remove(String key) async =>
      const Failure(StorageFailure('unreadable'));
}
