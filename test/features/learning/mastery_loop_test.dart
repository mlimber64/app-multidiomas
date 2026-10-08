import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/daily_routine/presentation/daily_routine_controller.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/default_learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/english_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/italian_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/learning_context_builder.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/practice_evidence.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_controller.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/domain/answer_evaluator.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/features/review/presentation/review_session_controller.dart';
import 'package:parla_con_me/features/review/domain/review_repository.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

final _now = DateTime(2026, 10, 6, 9);
final _later = DateTime(2026, 10, 7, 9);
const _italian = ItalianLearningRules();
const _english = EnglishLearningRules();

LearningError _error(
  String id, {
  GrammarTopic? topic = GrammarTopic.essereVsAvere,
  String language = 'it',
}) => LearningError(
  id: id,
  language: language,
  category: LearningErrorCategory.grammar,
  original: 'ho andato',
  corrected: 'sono andato',
  explanation: 'Usiamo "essere" con andare.',
  grammarTopic: topic,
  firstSeenAt: _now,
  lastSeenAt: _now,
  confidence: 0.9,
);

/// Two mistakes on a topic (so it is weak), a word and a second, topic-less
/// mistake, all in Italian.
Future<void> _seed(LocalLearningRepository repo) async {
  for (var i = 0; i < 2; i++) {
    await repo.recordError(_error('ho andato -> sono andato'));
    await repo.recordGrammarTopicExposure(
      GrammarTopic.essereVsAvere,
      at: _now,
      wasError: true,
    );
  }
  await repo.recordVocabulary(UserVocabulary.of(word: 'ciao', at: _now));
}

class _World {
  _World._(this.storage, this.learningRepo, this.reviewRepo);

  static Future<_World> create({
    InMemoryLocalStorage? storage,
    bool seed = true,
    ReviewRepository Function(ReviewRepository)? wrapReviews,
  }) async {
    final s = storage ?? InMemoryLocalStorage();
    final w = _World._(s, LocalLearningRepository(s), LocalReviewRepository(s));
    if (seed) await _seed(w.learningRepo);
    w.learning = DefaultLearningEngine(
      w.learningRepo,
      rules: _italian,
      clock: () => _now,
    );
    w.reviews = DefaultReviewEngine(
      w.learningRepo,
      wrapReviews?.call(w.reviewRepo) ?? w.reviewRepo,
      learningLanguage: AppLanguage.italian,
      evidence: w.learning,
    );
    return w;
  }

  final InMemoryLocalStorage storage;
  final LocalLearningRepository learningRepo;
  final LocalReviewRepository reviewRepo;
  late final DefaultLearningEngine learning;
  late final DefaultReviewEngine reviews;

  Future<LearnerLearningSummary> summary() async =>
      ((await learningRepo.getLearningSummary()) as Success).value
          as LearnerLearningSummary;

  Future<GrammarTopicProgress> topic(
    GrammarTopic t, {
    String language = 'it',
  }) async => (await summary()).grammarTopics.firstWhere(
    (p) => p.topic == t && p.language == language,
  );

  Future<ReviewItem> item(ReviewItemType type) async {
    final queue =
        ((await reviews.getReviewQueue(now: _now, limit: 50)) as Success).value
            as List<ReviewItem>;
    return queue.firstWhere((i) => i.type == type);
  }
}

PracticeEvidence _evidence({
  String id = 'e1',
  PracticeEvidenceSource source = PracticeEvidenceSource.review,
  PracticeEvidenceType type = PracticeEvidenceType.production,
  PracticeEvidenceOutcome outcome = PracticeEvidenceOutcome.success,
  String language = 'it',
  GrammarTopic? topic = GrammarTopic.essereVsAvere,
  String? word,
}) => PracticeEvidence(
  eventId: id,
  source: source,
  type: type,
  outcome: outcome,
  learningLanguage: language,
  occurredAt: _later,
  grammarTopic: topic?.name,
  vocabularyWord: word,
  referenceId: word == null ? null : UserVocabulary.idFor(word, language),
);

class _Spy implements PracticeEvidenceRecorder {
  final events = <PracticeEvidence>[];
  @override
  Future<Result<void>> recordPracticeEvidence(PracticeEvidence e) async {
    events.add(e);
    return const Success(null);
  }
}

/// A review repository whose first `saveItem` fails.
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

void main() {
  group('PracticeEvidence contract', () {
    test('the strength hierarchy is fixed', () {
      EvidenceStrength of(
        PracticeEvidenceSource s,
        PracticeEvidenceType t,
        PracticeEvidenceOutcome o,
      ) => _evidence(source: s, type: t, outcome: o).strength;
      const c = PracticeEvidenceSource.conversation;
      const r = PracticeEvidenceSource.review;
      const prod = PracticeEvidenceType.production;
      const rec = PracticeEvidenceType.recognition;
      const ok = PracticeEvidenceOutcome.success;
      const ko = PracticeEvidenceOutcome.failure;

      expect(of(c, prod, ok), EvidenceStrength.veryStrong);
      expect(of(c, prod, ko), EvidenceStrength.veryStrong);
      expect(of(r, prod, ok), EvidenceStrength.strong);
      expect(of(r, prod, ko), EvidenceStrength.strong);
      expect(of(r, rec, ok), EvidenceStrength.weak);
      expect(of(r, rec, ko), EvidenceStrength.medium);
      for (final s in [c, r]) {
        for (final o in [ok, ko]) {
          expect(
            of(s, PracticeEvidenceType.exposure, o),
            EvidenceStrength.veryWeak,
          );
        }
      }
      expect(
        EvidenceStrength.veryStrong.weight,
        greaterThan(EvidenceStrength.strong.weight),
      );
      expect(
        EvidenceStrength.strong.weight,
        greaterThan(EvidenceStrength.weak.weight),
      );
      expect(
        EvidenceStrength.weak.weight,
        greaterThan(EvidenceStrength.veryWeak.weight),
      );
    });

    test('it carries its identity and compares by value', () {
      final a = _evidence(word: 'ciao');
      expect(a.eventId, 'e1');
      expect(a.source, PracticeEvidenceSource.review);
      expect(a.type, PracticeEvidenceType.production);
      expect(a.outcome, PracticeEvidenceOutcome.success);
      expect(a.learningLanguage, 'it');
      expect(a.referenceId, 'it:ciao');
      expect(a.vocabularyWord, 'ciao');
      expect(a, _evidence(word: 'ciao'));
      expect(a.hashCode, _evidence(word: 'ciao').hashCode);
      expect(a, isNot(_evidence(word: 'ciao', id: 'e2')));
    });

    test('every exercise type is classified', () {
      expect(
        ExerciseType.errorCorrection.practiceType,
        PracticeEvidenceType.production,
      );
      expect(
        ExerciseType.vocabularyContext.practiceType,
        PracticeEvidenceType.production,
      );
      expect(
        ExerciseType.grammarChoice.practiceType,
        PracticeEvidenceType.recognition,
      );
      expect(
        {for (final t in ExerciseType.values) t: t.practiceType}.length,
        ExerciseType.values.length,
        reason: 'no exercise type is left unclassified',
      );
    });

    test('the classification matches how each exercise is answered', () {
      // Typed answers have no options; picked ones do.
      final typed = Exercise(
        id: 'x',
        reviewItemId: 'i',
        type: ExerciseType.errorCorrection,
        prompt: 'p',
        correctAnswer: 'a',
      );
      final picked = Exercise(
        id: 'y',
        reviewItemId: 'i',
        type: ExerciseType.grammarChoice,
        prompt: 'p',
        correctAnswer: 'a',
        options: const ['a', 'b'],
      );
      expect(typed.isMultipleChoice, isFalse);
      expect(picked.isMultipleChoice, isTrue);
      expect(AnswerEvaluator.isAnswerable(picked, 'zz'), isFalse);
    });
  });

  group('review result -> evidence', () {
    test(
      'each exercise type, right and wrong, sends the right evidence',
      () async {
        final w = await _World.create();
        final spy = _Spy();
        final engine = DefaultReviewEngine(
          w.learningRepo,
          w.reviewRepo,
          learningLanguage: AppLanguage.italian,
          evidence: spy,
        );
        final queue =
            ((await engine.getReviewQueue(now: _now, limit: 50)) as Success)
                    .value
                as List<ReviewItem>;
        final error = queue.firstWhere((i) => i.type == ReviewItemType.error);
        final grammar = queue.firstWhere(
          (i) => i.type == ReviewItemType.grammar,
        );
        final vocab = queue.firstWhere(
          (i) => i.type == ReviewItemType.vocabulary,
        );

        final cases = [
          (
            error,
            ExerciseType.errorCorrection,
            PracticeEvidenceType.production,
          ),
          (
            grammar,
            ExerciseType.grammarChoice,
            PracticeEvidenceType.recognition,
          ),
          (
            vocab,
            ExerciseType.vocabularyContext,
            PracticeEvidenceType.production,
          ),
        ];
        for (final (item, exercise, expected) in cases) {
          for (final result in ReviewResult.values) {
            spy.events.clear();
            await engine.recordReviewResult(
              itemId: item.id,
              result: result,
              now: _now,
              exercise: exercise,
            );
            final e = spy.events.single;
            expect(e.source, PracticeEvidenceSource.review);
            expect(e.type, expected);
            expect(
              e.outcome,
              result == ReviewResult.success
                  ? PracticeEvidenceOutcome.success
                  : PracticeEvidenceOutcome.failure,
            );
            expect(e.learningLanguage, 'it');
            if (item.type == ReviewItemType.vocabulary) {
              expect(e.vocabularyWord, 'ciao');
              expect(e.referenceId, item.sourceId);
            } else {
              expect(e.grammarTopic, GrammarTopic.essereVsAvere.name);
            }
          }
        }
      },
    );

    test('one result is one event, with a stable id per attempt', () async {
      final w = await _World.create();
      final spy = _Spy();
      final engine = DefaultReviewEngine(
        w.learningRepo,
        w.reviewRepo,
        learningLanguage: AppLanguage.italian,
        evidence: spy,
      );
      final item = await w.item(ReviewItemType.grammar);
      await engine.recordReviewResult(
        itemId: item.id,
        result: ReviewResult.failure,
        now: _now,
      );
      await engine.recordReviewResult(
        itemId: item.id,
        result: ReviewResult.success,
        now: _now.add(const Duration(hours: 1)),
      );
      expect(spy.events, hasLength(2));
      expect(spy.events[0].eventId, '${'review:${item.id}'}:attempt:1');
      expect(spy.events[1].eventId, '${'review:${item.id}'}:attempt:2');
      // With no exercise said, the item's own exercise kind is used.
      expect(spy.events[0].type, PracticeEvidenceType.recognition);
    });

    test(
      'a mistake without a topic proves nothing the memory can hold',
      () async {
        final w = await _World.create(seed: false);
        for (var i = 0; i < 2; i++) {
          await w.learningRepo.recordError(
            _error('colore -> colore', topic: null),
          );
        }
        final spy = _Spy();
        final engine = DefaultReviewEngine(
          w.learningRepo,
          w.reviewRepo,
          learningLanguage: AppLanguage.italian,
          evidence: spy,
        );
        final item = await _first(engine, ReviewItemType.error);
        await engine.recordReviewResult(
          itemId: item.id,
          result: ReviewResult.success,
          now: _now,
        );
        expect(spy.events, isEmpty);
        // The review itself still happened.
        final saved = (await w.reviewRepo.getItem(item.id) as Success).value;
        expect((saved as ReviewItem).successfulReviews, 1);
      },
    );

    test('without a recorder the review works as before', () async {
      final w = await _World.create();
      final engine = DefaultReviewEngine(
        w.learningRepo,
        w.reviewRepo,
        learningLanguage: AppLanguage.italian,
      );
      final item = await _first(engine, ReviewItemType.grammar);
      final r = await engine.recordReviewResult(
        itemId: item.id,
        result: ReviewResult.success,
        now: _now,
      );
      expect(r, isA<Success<ReviewItem>>());
    });
  });

  group('what the evidence does to the memory', () {
    test('review and learning both change from one result', () async {
      final w = await _World.create();
      final before = await w.topic(GrammarTopic.essereVsAvere);
      final item = await w.item(ReviewItemType.error);
      final result = await w.reviews.recordReviewResult(
        itemId: item.id,
        result: ReviewResult.success,
        now: _later,
        exercise: ExerciseType.errorCorrection,
      );
      // Review memory: scheduling.
      final updated = (result as Success<ReviewItem>).value;
      expect(updated.successfulReviews, 1);
      expect(updated.nextReviewAt.isAfter(_later), isTrue);
      // Learning memory: the topic heard about it.
      final after = await w.topic(GrammarTopic.essereVsAvere);
      expect(after.weightedSuccesses, before.weightedSuccesses + 0.5);
      expect(after.weightedExposure, before.weightedExposure + 0.5);
      expect(after.confidence, greaterThan(before.confidence));
      expect(after.priority(_later), lessThan(before.priority(_later)));
      // What the learner wrote is untouched.
      expect(after.exposureCount, before.exposureCount);
      expect(after.successfulUseCount, before.successfulUseCount);
      expect(after.lastSeenAt, before.lastSeenAt);
    });

    test('stronger evidence counts more: conversation > review production > '
        'review recognition', () async {
      final w = await _World.create(seed: false);
      for (final t in [
        GrammarTopic.essereVsAvere,
        GrammarTopic.articles,
        GrammarTopic.prepositions,
      ]) {
        for (var i = 0; i < 2; i++) {
          await w.learningRepo.recordGrammarTopicExposure(
            t,
            at: _now,
            wasError: true,
          );
        }
      }
      await w.learning.recordPracticeEvidence(
        _evidence(
          id: 'c',
          source: PracticeEvidenceSource.conversation,
          topic: GrammarTopic.essereVsAvere,
        ),
      );
      await w.learning.recordPracticeEvidence(
        _evidence(id: 'p', topic: GrammarTopic.articles),
      );
      await w.learning.recordPracticeEvidence(
        _evidence(
          id: 'r',
          type: PracticeEvidenceType.recognition,
          topic: GrammarTopic.prepositions,
        ),
      );
      final conv = await w.topic(GrammarTopic.essereVsAvere);
      final prod = await w.topic(GrammarTopic.articles);
      final rec = await w.topic(GrammarTopic.prepositions);
      expect(conv.confidence, greaterThan(prod.confidence));
      expect(prod.confidence, greaterThan(rec.confidence));
      expect(rec.confidence, greaterThan(0));
      expect(conv.priority(_later), lessThan(prod.priority(_later)));
      expect(prod.priority(_later), lessThan(rec.priority(_later)));
    });

    test(
      'a failure in review makes the topic matter more, by strength',
      () async {
        final w = await _World.create(seed: false);
        for (final t in [GrammarTopic.articles, GrammarTopic.prepositions]) {
          for (var i = 0; i < 2; i++) {
            await w.learningRepo.recordGrammarTopicExposure(
              t,
              at: _now,
              wasError: true,
            );
          }
          // Some success first, so there is mastery to lose.
          await w.learningRepo.recordSuccessfulGrammarUse(t, at: _now);
        }
        final base = await w.topic(GrammarTopic.articles);
        await w.learning.recordPracticeEvidence(
          _evidence(
            id: 'f1',
            outcome: PracticeEvidenceOutcome.failure,
            topic: GrammarTopic.articles,
          ),
        );
        await w.learning.recordPracticeEvidence(
          _evidence(
            id: 'f2',
            type: PracticeEvidenceType.recognition,
            outcome: PracticeEvidenceOutcome.failure,
            topic: GrammarTopic.prepositions,
          ),
        );
        final typed = await w.topic(GrammarTopic.articles);
        final picked = await w.topic(GrammarTopic.prepositions);
        expect(typed.confidence, lessThan(base.confidence));
        expect(typed.priority(_now), greaterThan(base.priority(_now)));
        expect(picked.priority(_now), greaterThan(base.priority(_now)));
        expect(
          typed.priority(_now),
          greaterThan(picked.priority(_now)),
          reason: 'a failed typed answer weighs more than a failed pick',
        );
      },
    );

    test(
      'one success does not clear a weakness; several turn it around',
      () async {
        final w = await _World.create();
        List<GrammarTopic> toReinforce(LearnerLearningSummary s) => [
          for (final t in selectTopicsToReinforce(s.forLanguage('it'), _now))
            t.topic,
        ];

        await w.learning.recordPracticeEvidence(_evidence(id: 'one'));
        var s = await w.summary();
        expect(toReinforce(s), contains(GrammarTopic.essereVsAvere));
        expect(isImprovingTopic(s.grammarTopics.single), isFalse);
        expect(s.grammarTopics.single.confidence, lessThan(0.5));

        for (var i = 0; i < 5; i++) {
          await w.learning.recordPracticeEvidence(_evidence(id: 'more-$i'));
        }
        s = await w.summary();
        expect(isImprovingTopic(s.grammarTopics.single), isTrue);
        expect(toReinforce(s), isNot(contains(GrammarTopic.essereVsAvere)));
      },
    );

    test('vocabulary practiced in review updates the same word', () async {
      final w = await _World.create();
      final before = (await w.summary()).vocabularyItems.single;
      await w.learning.recordPracticeEvidence(
        _evidence(id: 'v1', topic: null, word: 'ciao'),
      );
      final after = (await w.summary()).vocabularyItems.single;
      expect((await w.summary()).vocabularyItems, hasLength(1));
      expect(after.id, before.id);
      expect(after.weightedSuccesses, 0.5);
      expect(after.confidence, greaterThan(before.confidence));
      expect(after.confidence, lessThan(1));
      expect(after.priority(_later), lessThan(before.priority(_later)));
      expect(after.exposureCount, before.exposureCount);
    });

    test(
      'a word the memory does not hold is not invented by a review',
      () async {
        final w = await _World.create();
        await w.learning.recordPracticeEvidence(
          _evidence(id: 'v2', topic: null, word: 'gatto'),
        );
        expect((await w.summary()).vocabularyItems.map((v) => v.word), [
          'ciao',
        ]);
      },
    );

    test('conversation goes through the same contract', () async {
      final w = await _World.create(seed: false);
      await w.learning.recordPracticeEvidence(
        _evidence(
          id: 'c1',
          source: PracticeEvidenceSource.conversation,
          outcome: PracticeEvidenceOutcome.failure,
        ),
      );
      await w.learning.recordPracticeEvidence(
        _evidence(id: 'c2', source: PracticeEvidenceSource.conversation),
      );
      final t = await w.topic(GrammarTopic.essereVsAvere);
      expect(t.exposureCount, 2);
      expect(t.errorCount, 1);
      expect(t.successfulUseCount, 1);
      expect(t.weightedExposure, 2.0);
      expect(t.confidence, 0.5);
    });
  });

  group('idempotency', () {
    test('the same event twice counts once', () async {
      final w = await _World.create();
      final e = _evidence(id: 'dup');
      await w.learning.recordPracticeEvidence(e);
      final once = await w.topic(GrammarTopic.essereVsAvere);
      await w.learning.recordPracticeEvidence(e);
      await w.learning.recordPracticeEvidence(e);
      final again = await w.topic(GrammarTopic.essereVsAvere);
      expect(again.weightedSuccesses, once.weightedSuccesses);
      expect(again.weightedExposure, once.weightedExposure);
      expect(
        await w.learningRepo.applyPracticeEvidence(e),
        isA<Success<bool>>().having((s) => s.value, 'changed', isFalse),
      );
    });

    test('the same event is also ignored after a restart', () async {
      final w = await _World.create();
      final e = _evidence(id: 'persisted');
      await w.learning.recordPracticeEvidence(e);
      final reopened = LocalLearningRepository(w.storage);
      final result = await reopened.applyPracticeEvidence(e);
      expect((result as Success<bool>).value, isFalse);
    });

    test('remembered events are bounded', () async {
      final w = await _World.create();
      for (var i = 0; i < 250; i++) {
        await w.learning.recordPracticeEvidence(_evidence(id: 'n$i'));
      }
      final json = jsonDecode(w.storage.data['learning_memory']!) as Map;
      expect((json['appliedEvents'] as List).length, 200);
    });

    test(
      'answering again after the schedule failed to save counts once',
      () async {
        late _FlakyReviews flaky;
        final w = await _World.create(
          wrapReviews: (r) => flaky = _FlakyReviews(r),
        );
        final item = await w.item(ReviewItemType.error);
        final first = await w.reviews.recordReviewResult(
          itemId: item.id,
          result: ReviewResult.success,
          now: _later,
          exercise: ExerciseType.errorCorrection,
        );
        expect(first, isA<Failure<ReviewItem>>());
        final afterFailure = await w.topic(GrammarTopic.essereVsAvere);

        final retry = await w.reviews.recordReviewResult(
          itemId: item.id,
          result: ReviewResult.success,
          now: _later,
          exercise: ExerciseType.errorCorrection,
        );
        expect(retry, isA<Success<ReviewItem>>());
        expect(flaky.failNext, isFalse);
        final after = await w.topic(GrammarTopic.essereVsAvere);
        expect(after.weightedSuccesses, afterFailure.weightedSuccesses);
      },
    );
  });

  group('language isolation', () {
    test(
      'Italian practice never touches English memory, and vice versa',
      () async {
        final w = await _World.create();
        for (var i = 0; i < 2; i++) {
          await w.learningRepo.recordGrammarTopicExposure(
            GrammarTopic.articles,
            language: 'en',
            at: _now,
            wasError: true,
          );
        }
        await w.learningRepo.recordVocabulary(
          UserVocabulary.of(word: 'ciao', at: _now, language: 'en'),
        );
        final enBefore = await w.topic(GrammarTopic.articles, language: 'en');
        final summaryBefore = await w.summary();

        await w.learning.recordPracticeEvidence(_evidence(id: 'it1'));
        await w.learning.recordPracticeEvidence(
          _evidence(id: 'it2', topic: null, word: 'ciao'),
        );

        final enAfter = await w.topic(GrammarTopic.articles, language: 'en');
        expect(enAfter.weightedSuccesses, enBefore.weightedSuccesses);
        expect(enAfter.weightedExposure, enBefore.weightedExposure);
        final enWord = (await w.summary()).vocabularyItems.firstWhere(
          (v) => v.language == 'en',
        );
        expect(
          enWord.weightedSuccesses,
          summaryBefore.vocabularyItems
              .firstWhere((v) => v.language == 'en')
              .weightedSuccesses,
        );
        expect(
          (await w.topic(GrammarTopic.essereVsAvere)).weightedSuccesses,
          0.5,
        );

        // An engine for English ignores Italian evidence, and the other way.
        final english = DefaultLearningEngine(
          w.learningRepo,
          rules: _english,
          clock: () => _now,
        );
        await english.recordPracticeEvidence(_evidence(id: 'it3'));
        expect(
          (await w.topic(GrammarTopic.essereVsAvere)).weightedSuccesses,
          0.5,
        );
        await english.recordPracticeEvidence(
          _evidence(id: 'en1', language: 'en', topic: GrammarTopic.articles),
        );
        expect(
          (await w.topic(
            GrammarTopic.articles,
            language: 'en',
          )).weightedSuccesses,
          0.5,
        );
      },
    );

    test(
      'the review of one language sends evidence for that language',
      () async {
        final w = await _World.create(seed: false);
        for (var i = 0; i < 2; i++) {
          await w.learningRepo.recordGrammarTopicExposure(
            GrammarTopic.articles,
            language: 'en',
            at: _now,
            wasError: true,
          );
          await w.learningRepo.recordError(
            _error('a car', topic: GrammarTopic.articles, language: 'en'),
          );
        }
        final spy = _Spy();
        final engine = DefaultReviewEngine(
          w.learningRepo,
          w.reviewRepo,
          learningLanguage: AppLanguage.english,
          evidence: spy,
        );
        final queue =
            ((await engine.getReviewQueue(now: _now, limit: 50)) as Success)
                    .value
                as List<ReviewItem>;
        await engine.recordReviewResult(
          itemId: queue.first.id,
          result: ReviewResult.success,
          now: _now,
        );
        expect(spy.events.single.learningLanguage, 'en');
      },
    );
  });

  group('persistence', () {
    test('memory written before evidence existed reads the same', () async {
      final storage = InMemoryLocalStorage();
      storage.data['learning_memory'] = jsonEncode({
        'version': 1,
        'errors': [],
        'grammarTopics': [
          {
            'topic': 'articles',
            'language': 'it',
            'exposureCount': 4,
            'errorCount': 3,
            'successfulUseCount': 1,
            'lastSeenAt': _now.toIso8601String(),
          },
        ],
        'vocabulary': [
          {
            'id': 'it:ciao',
            'word': 'ciao',
            'language': 'it',
            'exposureCount': 2,
            'successfulUseCount': 1,
            'lastSeenAt': _now.toIso8601String(),
          },
        ],
      });
      final repo = LocalLearningRepository(storage);
      final s =
          ((await repo.getLearningSummary()) as Success).value
              as LearnerLearningSummary;
      final t = s.grammarTopics.single;
      expect(t.confidence, 0.25);
      expect(t.weightedErrors, 3);
      expect(t.priority(_now), 3 * 0.75);
      expect(s.vocabularyItems.single.confidence, 0.5);
    });

    test('a conversation-only memory is stored exactly as before', () async {
      final w = await _World.create(seed: false);
      await w.learning.recordPracticeEvidence(
        _evidence(
          id: 'c',
          source: PracticeEvidenceSource.conversation,
          outcome: PracticeEvidenceOutcome.failure,
        ),
      );
      final json = jsonDecode(w.storage.data['learning_memory']!) as Map;
      expect(json['version'], 1);
      expect(json.containsKey('appliedEvents'), isFalse);
      final topic = (json['grammarTopics'] as List).single as Map;
      expect(topic.containsKey('weightedExposure'), isFalse);
    });

    test('review evidence survives a restart', () async {
      final w = await _World.create();
      await w.learning.recordPracticeEvidence(_evidence(id: 'keep'));
      final reopened = LocalLearningRepository(w.storage);
      final s =
          ((await reopened.getLearningSummary()) as Success).value
              as LearnerLearningSummary;
      final t = s.grammarTopics.firstWhere(
        (p) => p.topic == GrammarTopic.essereVsAvere,
      );
      expect(t.weightedSuccesses, 0.5);
      expect(t.successfulUseCount, 0);
    });
  });

  group('routine', () {
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
          dailyRoutineClockProvider.overrideWithValue(() => _now),
          reviewSessionClockProvider.overrideWithValue(() => _now),
        ],
      );
      addTearDown(c.dispose);
      c.listen(dailyRoutineProvider, (_, _) {});
      return c;
    }

    test(
      'practicing in the routine does not change the routine of the day',
      () async {
        final storage = InMemoryLocalStorage();
        await _seed(LocalLearningRepository(storage));
        final c = containerFor(storage);
        final routine = await c.read(dailyRoutineProvider.future);
        final storedBefore = storage.data['daily_routine'];
        final memoryBefore = storage.data['learning_memory'];
        expect(routine.step1.itemIds, isNotEmpty);

        final session = c.read(reviewSessionControllerProvider.notifier);
        await session.start(onlyItems: routine.step1.itemIds.toSet());
        final exercise = c.read(reviewSessionControllerProvider).current!;
        await session.submitAnswer(exercise.correctAnswer);

        expect(
          storage.data['learning_memory'],
          isNot(memoryBefore),
          reason: 'the learning memory heard about the answer',
        );
        expect(c.read(dailyRoutineProvider).value, routine);
        expect(storage.data['daily_routine'], storedBefore);
      },
    );

    test('the next routine is planned from the updated memory', () async {
      final storage = InMemoryLocalStorage();
      await _seed(LocalLearningRepository(storage));
      final c = containerFor(storage);
      await c.read(dailyRoutineProvider.future);
      final planner = c.read(dailyRoutinePlannerProvider);

      final tomorrow = _later;
      final before =
          (await planner.plan(now: tomorrow, profile: profile)) as Success;
      expect(
        (before.value as dynamic).step2.mission.targetTopics,
        contains(GrammarTopic.essereVsAvere),
      );

      final engine = c.read(practiceEvidenceRecorderProvider);
      for (var i = 0; i < 6; i++) {
        await engine.recordPracticeEvidence(_evidence(id: 'day-$i'));
      }

      final after =
          (await planner.plan(now: tomorrow, profile: profile)) as Success;
      expect(
        (after.value as dynamic).step2.mission.targetTopics,
        isNot(contains(GrammarTopic.essereVsAvere)),
      );
      // Today's routine is still the one planned this morning.
      expect((c.read(dailyRoutineProvider).value!).date, '2026-10-06');
    });
  });

  group('architecture', () {
    String sourceOf(FileSystemEntity f) => (f as File).readAsStringSync();

    test('review never reaches the concrete learning repository', () {
      final files = Directory('lib/features/review')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      for (final f in files) {
        final s = sourceOf(f);
        expect(s, isNot(contains('LocalLearningRepository')), reason: f.path);
        expect(s, isNot(contains('learning/data/')), reason: f.path);
      }
    });

    test('review reads the learning memory but never writes it', () {
      final s = File(
        'lib/features/review/domain/review_engine.dart',
      ).readAsStringSync();
      for (final write in [
        '_learning.record',
        '_learning.apply',
        '_learning.clear',
      ]) {
        expect(s, isNot(contains(write)));
      }
    });

    test(
      'review screens and controllers do not touch the learning repository',
      () {
        final files = Directory('lib/features/review/presentation')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.dart') &&
                  !f.path.endsWith('review_providers.dart'),
            );
        for (final f in files) {
          expect(sourceOf(f), isNot(contains('LearningRepository')));
          expect(sourceOf(f), isNot(contains('learningRepositoryProvider')));
        }
      },
    );

    test('the learning engine is the only writer of the practice evidence', () {
      final writers = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => sourceOf(f).contains('.applyPracticeEvidence('))
          .map((f) => f.path.replaceAll('\\', '/'))
          .toList();
      expect(writers, [
        'lib/features/learning/domain/default_learning_engine.dart',
      ]);
    });
  });
}

Future<ReviewItem> _first(ReviewEngine engine, ReviewItemType type) async {
  final queue =
      ((await engine.getReviewQueue(now: _now, limit: 50)) as Success).value
          as List<ReviewItem>;
  return queue.firstWhere((i) => i.type == type);
}
