import 'package:parla_con_me/features/learning/domain/practice_evidence.dart';
import 'package:parla_con_me/features/learning/domain/language_scope.dart';
import 'package:parla_con_me/features/learning/domain/italian_learning_rules.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/default_learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/in_memory_local_storage.dart';

const _andato = Correction(
  original: 'Ieri ho andato al supermercato.',
  corrected: 'Ieri sono andato al supermercato.',
  explanation: 'Con "andare" si usa "essere".',
  category: CorrectionCategory.grammar,
);

const _reserva = Correction(
  original: 'Ho fatto una reserva.',
  corrected: 'Ho fatto una prenotazione.',
  explanation: 'In italiano si dice "prenotazione".',
  category: CorrectionCategory.vocabulary,
);

/// Reads fail but writes work: success detection is impossible, mistakes are
/// still recorded.
class _ReadFailingRepository implements LearningRepository {
  _ReadFailingRepository(this._inner);
  final LearningRepository _inner;

  @override
  Future<Result<LearnerLearningSummary>> getLearningSummary() async =>
      const Failure(StorageFailure('read failed'));
  @override
  Future<Result<void>> recordError(LearningError o) => _inner.recordError(o);
  @override
  Future<Result<void>> recordVocabulary(UserVocabulary o) =>
      _inner.recordVocabulary(o);
  @override
  Future<Result<void>> recordGrammarTopicExposure(
    GrammarTopic t, {
    required DateTime at,
    bool wasError = false,
    String language = legacyLanguageCode,
  }) => _inner.recordGrammarTopicExposure(
    t,
    at: at,
    wasError: wasError,
    language: language,
  );
  @override
  Future<Result<void>> recordSuccessfulGrammarUse(
    GrammarTopic t, {
    required DateTime at,
    String language = legacyLanguageCode,
  }) => _inner.recordSuccessfulGrammarUse(t, at: at, language: language);
  @override
  Future<Result<bool>> applyPracticeEvidence(PracticeEvidence e) =>
      _inner.applyPracticeEvidence(e);
  @override
  Future<Result<void>> clearLearningData() => _inner.clearLearningData();
}

void main() {
  late InMemoryLocalStorage storage;
  late LocalLearningRepository repo;
  late DefaultLearningEngine engine;
  var day = 1;
  DateTime now() => DateTime.utc(2026, 10, day, 10);

  Future<LearnerLearningSummary> memory() async =>
      (await repo.getLearningSummary()).when(
        success: (s) => s,
        failure: (f) => fail('unexpected $f'),
      );

  Future<GrammarTopicProgress> topic(GrammarTopic t) async =>
      (await memory()).grammarTopics.firstWhere((p) => p.topic == t);

  /// One exchange: what the learner wrote and the AI's corrections.
  Future<void> say(
    String user, [
    List<Correction> corrections = const [],
  ]) async {
    final result = await engine.analyze(
      userMessage: user,
      response: AIResponse(message: 'ok', corrections: corrections),
    );
    expect(result, isA<Success<void>>());
  }

  setUp(() {
    day = 1;
    storage = InMemoryLocalStorage();
    repo = LocalLearningRepository(storage);
    engine = DefaultLearningEngine(
      repo,
      rules: const ItalianLearningRules(),
      clock: now,
    );
  });

  group('error -> recovery in grammar', () {
    test(
      'day 1: the correction is an error and an exposure, not a success',
      () async {
        await say('Ieri ho andato al supermercato.', [_andato]);

        for (final t in [
          GrammarTopic.essereVsAvere,
          GrammarTopic.passatoProssimo,
        ]) {
          final p = await topic(t);
          expect(p.errorCount, 1, reason: '$t');
          expect(p.exposureCount, 1, reason: '$t');
          expect(p.successfulUseCount, 0, reason: '$t');
        }
        expect((await memory()).errors.single.frequency, 1);
      },
    );

    test(
      'day 2 and 3: correct uses accumulate as successes and exposures',
      () async {
        await say('Ieri ho andato al supermercato.', [_andato]);

        day = 2;
        await say('Ieri sono andato al lavoro.');
        for (final t in [
          GrammarTopic.essereVsAvere,
          GrammarTopic.passatoProssimo,
        ]) {
          final p = await topic(t);
          expect(p.errorCount, 1);
          expect(p.successfulUseCount, 1);
          expect(p.exposureCount, 2);
          expect(p.confidence, 0.5);
          expect(p.lastSeenAt, now());
        }

        day = 3;
        await say('Ieri sono andato a scuola.');
        final p = await topic(GrammarTopic.essereVsAvere);
        expect(p.errorCount, 1);
        expect(p.successfulUseCount, 2);
        expect(p.exposureCount, 3);
        expect(p.confidence, closeTo(2 / 3, 1e-9));

        // The mistake itself did not change: a success is not another error.
        final e = (await memory()).errors.single;
        expect(e.frequency, 1);
        expect(e.lastSeenAt, DateTime.utc(2026, 10, 1, 10));
      },
    );

    test('an unrelated message proves nothing', () async {
      await say('Ieri ho andato al supermercato.', [_andato]);
      final before = await topic(GrammarTopic.passatoProssimo);

      day = 2;
      await say('Oggi mangio una pizza.');
      await say('Mi piace molto il caffè.');

      final after = await topic(GrammarTopic.passatoProssimo);
      expect(after.successfulUseCount, 0);
      expect(after.exposureCount, before.exposureCount);
    });

    test(
      'no earlier mistake, no success: correct Italian alone is not evidence',
      () async {
        await say('Ieri sono andato al lavoro.');
        await say('Ho mangiato una pizza.');
        final m = await memory();
        expect(m.grammarTopics, isEmpty);
        expect(m.errors, isEmpty);
        expect(storage.data, isEmpty, reason: 'nothing to write');
      },
    );

    test(
      'the same construction twice in one message counts once; two messages count twice',
      () async {
        await say('Ieri ho andato al supermercato.', [_andato]);

        day = 2;
        await say('Sono andato a casa e sono andato al lavoro.');
        expect((await topic(GrammarTopic.essereVsAvere)).successfulUseCount, 1);

        await say('Sono andato al mare.');
        expect((await topic(GrammarTopic.essereVsAvere)).successfulUseCount, 2);
        expect((await topic(GrammarTopic.essereVsAvere)).exposureCount, 3);
      },
    );

    test(
      'two known mistakes of one topic still give one success per message',
      () async {
        await say('Ieri ho andato al supermercato.', [_andato]);
        await say('Oggi ho venuto presto.', [
          const Correction(
            original: 'Oggi ho venuto presto.',
            corrected: 'Oggi sono venuto presto.',
            explanation: '',
            category: CorrectionCategory.grammar,
          ),
        ]);

        day = 2;
        await say('Sono andato e sono venuto in tempo.');
        final p = await topic(GrammarTopic.essereVsAvere);
        expect(p.successfulUseCount, 1);
      },
    );

    test('the mistaken form still in the message is not evidence', () async {
      await say('Ieri ho andato al supermercato.', [_andato]);
      day = 2;
      await say('Ieri ho andato al lavoro e sono andato a casa.');
      await say('Noi abbiamo andato al mare e siamo andati a casa.');
      expect((await topic(GrammarTopic.essereVsAvere)).successfulUseCount, 0);
    });

    test(
      'a mistake in the same topic in this very turn cancels the success',
      () async {
        await say('Ieri ho andato al supermercato.', [_andato]);
        day = 2;
        await say('Sono andato al lavoro ma ho andato a casa.', [_andato]);

        final p = await topic(GrammarTopic.essereVsAvere);
        expect(p.successfulUseCount, 0);
        expect(p.errorCount, 2);
        expect((await memory()).errors.single.frequency, 2);
      },
    );

    test(
      'same verb, other person/gender counts; another verb does not',
      () async {
        await say('Ieri ho andato al supermercato.', [_andato]);

        day = 2;
        await say('Sono venuto ieri.');
        expect((await topic(GrammarTopic.essereVsAvere)).successfulUseCount, 0);

        await say('Maria è andata al mercato.');
        expect((await topic(GrammarTopic.essereVsAvere)).successfulUseCount, 1);
        await say('Siamo andati al cinema.');
        expect((await topic(GrammarTopic.essereVsAvere)).successfulUseCount, 2);
      },
    );

    test(
      'articles: the corrected wording credits the topic, other wording does not',
      () async {
        await say('La problema è grande.', [
          const Correction(
            original: 'la problema',
            corrected: 'il problema',
            explanation: 'Problema è maschile.',
            category: CorrectionCategory.grammar,
          ),
        ]);
        day = 2;
        await say('Ho un problema.');
        expect((await topic(GrammarTopic.articles)).successfulUseCount, 0);
        await say('Il problema è risolto.');
        expect((await topic(GrammarTopic.articles)).successfulUseCount, 1);
      },
    );

    test(
      'a mistake without an inferred topic cannot become a success',
      () async {
        await say('Sono stanco perche lavoro.', [
          const Correction(
            original: 'perche',
            corrected: 'perché',
            explanation: 'Accento.',
            category: CorrectionCategory.spelling,
          ),
        ]);
        day = 2;
        await say('Sono stanco perché lavoro.');
        expect((await memory()).grammarTopics, isEmpty);
      },
    );
  });

  group('vocabulary', () {
    test('a vocabulary correction records the corrected word once', () async {
      await say('Ho fatto una reserva.', [_reserva]);

      var m = await memory();
      final v = m.vocabularyItems.single;
      expect(v.word, 'prenotazione');
      expect(v.id, 'it:prenotazione');
      expect(v.exposureCount, 1);
      expect(v.successfulUseCount, 0);
      expect(m.errors.single.category, LearningErrorCategory.vocabulary);
      expect(m.grammarTopics, isEmpty);

      // Repeating the correction (even with different capitalization) is the
      // same item, not a duplicate.
      day = 2;
      await say('Voglio fare una reserva.', [
        const Correction(
          original: 'Voglio fare una reserva.',
          corrected: 'Voglio fare una Prenotazione.',
          explanation: '',
          category: CorrectionCategory.vocabulary,
        ),
      ]);
      m = await memory();
      expect(m.vocabularyItems, hasLength(1));
      expect(m.vocabularyItems.single.exposureCount, 2);
      expect(m.vocabularyItems.single.lastSeenAt, now());
      expect(m.vocabularyItems.single.successfulUseCount, 0);
    });

    test('using a known word is a success; other words are not', () async {
      await say('Ho fatto una reserva.', [_reserva]);

      day = 2;
      await say('Ho fatto una prenotazione.');
      var v = (await memory()).vocabularyItems.single;
      expect(v.successfulUseCount, 1);
      expect(v.exposureCount, 2);
      expect(v.confidence, 0.5);
      expect(v.lastSeenAt, now());

      await say('Ho mangiato una pizza.');
      await say('Le prenotazioni sono aperte.');
      v = (await memory()).vocabularyItems.single;
      expect(v.successfulUseCount, 1, reason: 'unrelated or inflected form');

      // Several occurrences in one message count once, any capitalization.
      await say('Prenotazione, prenotazione e ancora PRENOTAZIONE!');
      v = (await memory()).vocabularyItems.single;
      expect(v.successfulUseCount, 2);
      expect(v.exposureCount, 3);
    });

    test('a word corrected in this very turn is not also a success', () async {
      await say('Ho fatto una reserva.', [_reserva]);
      day = 2;
      await say('Ho fatto una prenotazione e una reserva.', [_reserva]);
      final v = (await memory()).vocabularyItems.single;
      expect(v.successfulUseCount, 0);
      expect(v.exposureCount, 2);
    });

    test(
      'identical pairs and tiny or long phrases create no vocabulary',
      () async {
        await say('Ho comprato una mela.', [
          const Correction(
            original: 'Ho comprato una mela.',
            corrected: 'Ho comprato una mela.',
            explanation: '',
            category: CorrectionCategory.vocabulary,
          ),
          const Correction(
            original: 'vino',
            corrected: 'tè',
            explanation: '',
            category: CorrectionCategory.vocabulary,
          ),
          const Correction(
            original: 'fare',
            corrected: 'una lunga frase di quattro parole',
            explanation: '',
            category: CorrectionCategory.vocabulary,
          ),
        ]);
        final m = await memory();
        expect(m.vocabularyItems, isEmpty);
        expect(
          m.totalErrors,
          2,
          reason:
              'the two real corrections are errors; the identical one is not',
        );
      },
    );

    test('a leading article is not part of the word', () async {
      await say('Uso la macchina da scrivere.', [
        const Correction(
          original: 'la macchina da scrivere',
          corrected: 'il computer',
          explanation: '',
          category: CorrectionCategory.vocabulary,
        ),
      ]);
      expect((await memory()).vocabularyItems.single.word, 'computer');
    });
  });

  group('error recurrence and relevance', () {
    test('frequency 1 is occasional; 2 or more is recurring', () async {
      await say('Ieri ho andato al supermercato.', [_andato]);
      var m = await memory();
      expect(m.errors, hasLength(1));
      expect(m.recurringErrors, isEmpty);

      day = 2;
      await say('Oggi ho andato a scuola.', [_andato]);
      m = await memory();
      expect(m.recurringErrors.single.frequency, 2);
      expect(m.recurringErrors.single.isRecurring, isTrue);
      expect(m.errors, hasLength(1));
    });

    LearningError error(
      String id, {
      required int frequency,
      required DateTime lastSeen,
    }) => LearningError(
      id: id,
      category: LearningErrorCategory.grammar,
      original: 'a',
      corrected: 'b',
      firstSeenAt: lastSeen,
      lastSeenAt: lastSeen,
      confidence: 0.9,
      frequency: frequency,
    );

    final today = DateTime.utc(2026, 10, 20);

    test('a frequent recent error outranks an occasional one', () {
      final summary = LearnerLearningSummary(
        errors: [
          error('la problema -> il problema', frequency: 1, lastSeen: today),
          error('ho andato -> sono andato', frequency: 5, lastSeen: today),
        ],
      );
      final ranked = summary.prioritizedErrors(today);
      expect(ranked.first.id, 'ho andato -> sono andato');
      expect(ranked.first.priority(today), closeTo(4.5, 1e-9));
      expect(ranked.last.priority(today), closeTo(0.9, 1e-9));
    });

    test('relevance fades with time (half-life 14 days)', () {
      final recent = error('a -> b', frequency: 2, lastSeen: today);
      final old = error(
        'c -> d',
        frequency: 2,
        lastSeen: today.subtract(const Duration(days: 28)),
      );
      expect(old.priority(today), closeTo(recent.priority(today) / 4, 1e-9));
      // Even a 4-times-as-frequent old error only ties with a recent one.
      final veryOld = error(
        'e -> f',
        frequency: 8,
        lastSeen: today.subtract(const Duration(days: 28)),
      );
      expect(veryOld.priority(today), closeTo(recent.priority(today), 1e-9));
      // A future date never gives more than full weight.
      expect(
        error(
          'g -> h',
          frequency: 1,
          lastSeen: today.add(const Duration(days: 3)),
        ).priority(today),
        closeTo(0.9, 1e-9),
      );
    });

    test(
      'topics: more errors and fewer successes rank higher; none-error topics are left out',
      () {
        final summary = LearnerLearningSummary(
          grammarTopics: [
            GrammarTopicProgress(
              topic: GrammarTopic.articles,
              exposureCount: 7,
              errorCount: 4,
              successfulUseCount: 3,
              lastSeenAt: today,
            ),
            GrammarTopicProgress(
              topic: GrammarTopic.passatoProssimo,
              exposureCount: 4,
              errorCount: 4,
              lastSeenAt: today,
            ),
            GrammarTopicProgress(
              topic: GrammarTopic.prepositions,
              exposureCount: 3,
              successfulUseCount: 3,
              lastSeenAt: today,
            ),
            const GrammarTopicProgress(topic: GrammarTopic.gender),
          ],
        );
        final ranked = summary.prioritizedTopics(today);
        expect(ranked.map((t) => t.topic), [
          GrammarTopic.passatoProssimo,
          GrammarTopic.articles,
        ]);
        expect(ranked.first.priority(today), closeTo(4, 1e-9));
        expect(ranked.last.priority(today), closeTo(4 * (4 / 7), 1e-9));
      },
    );

    test('mastery is clamped to 0..1 even with inconsistent counts', () {
      const p = GrammarTopicProgress(
        topic: GrammarTopic.articles,
        exposureCount: 2,
        successfulUseCount: 5,
      );
      expect(p.confidence, 1);
    });
  });

  group('persistence and compatibility', () {
    test(
      'errors, topics (with successes) and vocabulary survive a restart',
      () async {
        await say('Ieri ho andato al supermercato.', [_andato]);
        await say('Ho fatto una reserva.', [_reserva]);
        day = 2;
        await say('Ieri sono andato al lavoro. Ho fatto una prenotazione.');

        final reopened = LocalLearningRepository(storage);
        final m = (await reopened.getLearningSummary()).when(
          success: (s) => s,
          failure: (f) => fail('$f'),
        );
        expect(
          m.errors.map((e) => e.id),
          containsAll(['ho andato -> sono andato', 'reserva -> prenotazione']),
        );
        final passato = m.grammarTopics.firstWhere(
          (t) => t.topic == GrammarTopic.passatoProssimo,
        );
        expect(
          (
            passato.errorCount,
            passato.successfulUseCount,
            passato.exposureCount,
          ),
          (1, 1, 2),
        );
        final v = m.vocabularyItems.single;
        expect((v.exposureCount, v.successfulUseCount), (2, 1));

        expect(
          (jsonDecode(storage.data[LocalLearningRepository.storageKey]!)
              as Map)['version'],
          1,
        );
      },
    );

    test(
      'a memory written by PHASE 3A is read as is, and evolves from there',
      () async {
        // Literal PHASE 3A document: no field was added in 3B.
        storage.data[LocalLearningRepository.storageKey] = jsonEncode({
          'version': 1,
          'errors': [
            {
              'id': 'ho andato -> sono andato',
              'category': 'grammar',
              'original': 'ho andato',
              'corrected': 'sono andato',
              'explanation': 'Con andare si usa essere.',
              'grammarTopic': 'essereVsAvere',
              'frequency': 2,
              'firstSeenAt': '2026-10-03T10:00:00.000Z',
              'lastSeenAt': '2026-10-04T10:00:00.000Z',
              'confidence': 0.9,
            },
          ],
          'grammarTopics': [
            {
              'topic': 'essereVsAvere',
              'exposureCount': 2,
              'errorCount': 2,
              'successfulUseCount': 0,
              'lastSeenAt': '2026-10-04T10:00:00.000Z',
            },
            {
              'topic': 'passatoProssimo',
              'exposureCount': 2,
              'errorCount': 2,
              'successfulUseCount': 0,
              'lastSeenAt': '2026-10-04T10:00:00.000Z',
            },
          ],
          'vocabulary': [
            {
              'id': 'it:prenotazione',
              'word': 'prenotazione',
              'language': 'it',
              'meaning': null,
              'exposureCount': 1,
              'successfulUseCount': 0,
              'lastSeenAt': '2026-10-04T10:00:00.000Z',
            },
          ],
        });
        var m = await memory();
        expect(m.errors.single.frequency, 2);
        expect(m.recurringErrors, hasLength(1));

        day = 5;
        await say('Ieri sono andato al lavoro. Ho fatto una prenotazione.');

        m = await memory();
        final p = m.grammarTopics.firstWhere(
          (t) => t.topic == GrammarTopic.essereVsAvere,
        );
        expect(
          (p.errorCount, p.successfulUseCount, p.exposureCount),
          (2, 1, 3),
        );
        expect(m.vocabularyItems.single.successfulUseCount, 1);
        expect(
          (jsonDecode(storage.data[LocalLearningRepository.storageKey]!)
              as Map)['version'],
          1,
        );
      },
    );
  });

  group('failure handling', () {
    test(
      'if the memory cannot be read, mistakes are still recorded and a failure is reported',
      () async {
        final blind = DefaultLearningEngine(
          _ReadFailingRepository(repo),
          rules: const ItalianLearningRules(),
          clock: now,
        );
        final result = await blind.analyze(
          userMessage: 'Ieri ho andato al supermercato.',
          response: const AIResponse(message: 'ok', corrections: [_andato]),
        );
        expect(result, isA<Failure<void>>());
        expect((await memory()).errors.single.frequency, 1);

        // Without a readable memory there is no success detection, only a failure.
        day = 2;
        final again = await blind.analyze(
          userMessage: 'Ieri sono andato al lavoro.',
          response: const AIResponse(message: 'ok'),
        );
        expect(again, isA<Failure<void>>());
        expect((await topic(GrammarTopic.essereVsAvere)).successfulUseCount, 0);
      },
    );

    test('interpretSuccesses is pure and finds nothing in an empty memory', () {
      final signals = engine.interpretSuccesses(
        userMessage: 'Ieri sono andato al lavoro.',
        errorSignals: const [],
        known: LearnerLearningSummary.empty,
        at: now(),
      );
      expect(signals, isEmpty);
      expect(storage.data, isEmpty);
    });
  });
}
