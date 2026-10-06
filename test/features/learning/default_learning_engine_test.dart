import 'package:parla_con_me/features/learning/domain/italian_learning_rules.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/default_learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_signal.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/services/storage/local_storage.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/other_language_rules.dart';
import '../../support/in_memory_local_storage.dart';

const _andato = Correction(
  original: 'Ieri ho andato al supermercato.',
  corrected: 'Ieri sono andato al supermercato.',
  explanation: 'Con "andare" si usa "essere".',
  category: CorrectionCategory.grammar,
);

AIResponse _reply([List<Correction> corrections = const []]) =>
    AIResponse(message: 'Bene!', corrections: corrections);

class _FailingStorage implements LocalStorage {
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

void main() {
  late InMemoryLocalStorage storage;
  late LocalLearningRepository repo;
  late DefaultLearningEngine engine;
  var now = DateTime.utc(2026, 10, 5, 10);

  Future<LearnerLearningSummary> summary() async => (await engine.summary())
      .when(success: (s) => s, failure: (f) => fail('unexpected $f'));

  Future<void> analyze(AIResponse response, {String user = 'msg'}) async {
    final result = await engine.analyze(userMessage: user, response: response);
    expect(result, isA<Success<void>>());
  }

  setUp(() {
    now = DateTime.utc(2026, 10, 5, 10);
    storage = InMemoryLocalStorage();
    repo = LocalLearningRepository(storage);
    engine = DefaultLearningEngine(
      repo,
      rules: const ItalianLearningRules(),
      clock: () => now,
    );
  });

  test(
    'an AI correction becomes a learning error with an inferred topic',
    () async {
      await analyze(_reply([_andato]), user: 'Ieri ho andato al supermercato.');

      final s = await summary();
      expect(s.totalErrors, 1);
      expect(s.lastUpdatedAt, now);

      // Frequency 1 is not "recurring": check through a second sighting below,
      // and here through the stored topics.
      final topics = {for (final t in s.grammarTopics) t.topic: t};
      expect(topics.keys, {
        GrammarTopic.essereVsAvere,
        GrammarTopic.passatoProssimo,
      });
      for (final t in topics.values) {
        expect(t.exposureCount, 1);
        expect(t.errorCount, 1);
        expect(t.successfulUseCount, 0);
        expect(t.confidence, 0);
      }

      now = now.add(const Duration(days: 1));
      await analyze(_reply([_andato]));
      final e = (await summary()).recurringErrors.single;
      expect(e.original, 'ho andato');
      expect(e.corrected, 'sono andato');
      expect(e.category, LearningErrorCategory.grammar);
      expect(e.grammarTopic, GrammarTopic.essereVsAvere);
      expect(e.confidence, DefaultLearningEngine.aiCorrectionConfidence);
      expect(e.explanation, contains('essere'));
    },
  );

  test('the same mistake again is one record with frequency 2', () async {
    await analyze(_reply([_andato]));
    now = DateTime.utc(2026, 10, 7, 8);
    // Same mistake, phrased as a fragment this time.
    await analyze(
      _reply([
        const Correction(
          original: 'ho andato',
          corrected: 'sono andato',
          explanation: '',
          category: CorrectionCategory.grammar,
        ),
      ]),
    );

    final s = await summary();
    expect(s.totalErrors, 2);
    final e = s.recurringErrors.single;
    expect(e.frequency, 2);
    expect(e.firstSeenAt, DateTime.utc(2026, 10, 5, 10));
    expect(e.lastSeenAt, now);
    expect(
      e.explanation,
      contains('essere'),
      reason: 'empty explanation did not erase it',
    );
    for (final t in s.grammarTopics) {
      expect(t.exposureCount, 2);
      expect(t.errorCount, 2);
    }
  });

  test('different mistakes stay separate', () async {
    await analyze(
      _reply([
        _andato,
        const Correction(
          original: 'la problema',
          corrected: 'il problema',
          explanation: 'Problema è maschile.',
          category: CorrectionCategory.grammar,
        ),
      ]),
    );
    await analyze(_reply([_andato]));

    final s = await summary();
    expect(s.totalErrors, 3);
    expect(s.recurringErrors.single.id, 'ho andato -> sono andato');
    final topics = {for (final t in s.grammarTopics) t.topic: t};
    expect(topics[GrammarTopic.articles]!.exposureCount, 1);
    expect(topics[GrammarTopic.essereVsAvere]!.exposureCount, 2);
  });

  test('a response without corrections creates no learning data', () async {
    await analyze(_reply());
    await analyze(_reply(), user: 'Ieri sono andato al supermercato.');

    final s = await summary();
    expect(s.totalErrors, 0);
    expect(s.recurringErrors, isEmpty);
    expect(s.grammarTopics, isEmpty);
    expect(s.vocabularyItems, isEmpty);
    expect(
      storage.data.containsKey(LocalLearningRepository.storageKey),
      isFalse,
    );
  });

  test('a "correction" that changes nothing is not a mistake', () async {
    await analyze(
      _reply([
        const Correction(
          original: 'ho fatto',
          corrected: 'ho fatto',
          explanation: '',
          category: CorrectionCategory.grammar,
        ),
      ]),
    );
    expect((await summary()).totalErrors, 0);
  });

  test('category and topic are only as specific as the evidence', () async {
    await analyze(
      _reply([
        const Correction(
          original: 'Sono stanco perche ho lavorato.',
          corrected: 'Sono stanco perché ho lavorato.',
          explanation: "Serve l'accento.",
          category: CorrectionCategory.spelling,
        ),
        const Correction(
          original: 'Vado in supermercato.',
          corrected: 'Vado al supermercato.',
          explanation: '',
          category: CorrectionCategory.grammar,
        ),
        const Correction(
          original: 'ho mangiato pizza',
          corrected: 'ho mangiato la pizza',
          explanation: '',
          category: CorrectionCategory.grammar,
        ),
      ]),
    );
    // Each stored error keeps its own category; only the preposition swap has a topic.
    await analyze(
      _reply([
        const Correction(
          original: 'Vado in supermercato.',
          corrected: 'Vado al supermercato.',
          explanation: '',
          category: CorrectionCategory.grammar,
        ),
      ]),
    );
    final s = await summary();
    final prep = s.recurringErrors.single;
    expect(prep.category, LearningErrorCategory.preposition);
    expect(prep.grammarTopic, GrammarTopic.prepositions);
    expect(s.grammarTopics.map((t) => t.topic), [GrammarTopic.prepositions]);
    expect(s.totalErrors, 4);
  });

  test(
    'a vocabulary correction records the error and the correct word',
    () async {
      await analyze(
        _reply([
          const Correction(
            original: 'la macchina da scrivere',
            corrected: 'il computer',
            explanation: 'Parola più comune oggi.',
            category: CorrectionCategory.vocabulary,
          ),
        ]),
      );
      final s = await summary();
      expect(s.totalErrors, 1);
      expect(
        s.grammarTopics,
        isEmpty,
        reason: 'no topic inference for vocabulary',
      );
      final v = s.vocabularyItems.single;
      expect(v.word, contains('computer'));
      expect(v.language, 'it');
      expect(v.exposureCount, 1);
      expect(v.successfulUseCount, 0);
    },
  );

  test('interpret is pure and describes the evidence it found', () {
    final signals = engine.interpret([_andato], at: now);
    expect(signals.map((s) => s.type), [
      LearningSignalType.grammarError,
      LearningSignalType.topicExposure,
      LearningSignalType.topicExposure,
    ]);
    expect(signals.first.source, LearningSignalSource.aiCorrection);
    expect(signals.first.confidence, 0.9);
    expect(
      signals.first.metadata[SignalKeys.patternKey],
      'ho andato -> sono andato',
    );
    expect(signals[1].source, LearningSignalSource.ruleInference);
    expect(signals[1].confidence, 0.8);
    expect(signals.map((s) => s.id).toSet(), hasLength(3));
    expect(
      storage.data,
      isEmpty,
      reason: 'interpreting does not touch storage',
    );
  });

  test('a successfulVocabularyUse signal records a successful use', () async {
    await engine.apply(
      LearningSignal(
        id: 's1',
        type: LearningSignalType.successfulVocabularyUse,
        source: LearningSignalSource.ruleInference,
        createdAt: now,
        confidence: 0.5,
        metadata: const {
          SignalKeys.word: 'formaggio',
          SignalKeys.meaning: 'queso',
        },
      ),
    );
    final v = (await summary()).vocabularyItems.single;
    expect(v.successfulUseCount, 1);
    expect(v.meaning, 'queso');
  });

  test('storage problems come back as a failure, never an exception', () async {
    final broken = DefaultLearningEngine(
      LocalLearningRepository(_FailingStorage()),
      rules: const ItalianLearningRules(),
    );
    final result = await broken.analyze(
      userMessage: 'x',
      response: _reply([_andato]),
    );
    expect(result, isA<Failure<void>>());
    expect((await broken.summary()), isA<Failure<LearnerLearningSummary>>());
  });

  group('learning language', () {
    final correction = _reply([
      const Correction(
        original: 'la macchina da scrivere',
        corrected: 'il computer',
        explanation: 'Parola più comune oggi.',
        category: CorrectionCategory.vocabulary,
      ),
    ]);

    // These use another language code only to prove the engine takes the
    // language from its configuration; no other learning language is
    // supported by the app yet.
    test('new vocabulary is recorded in the configured language', () async {
      engine = DefaultLearningEngine(
        repo,
        rules: const NoGrammarRules(AppLanguage.spanish),
        clock: () => now,
      );
      await analyze(correction);
      expect((await summary()).vocabularyItems.single.language, 'es');
    });

    test('the learning context only uses words of that language', () async {
      Future<List<String>> contextWords(AppLanguage language) async {
        final e = DefaultLearningEngine(
          repo,
          rules: language == AppLanguage.italian
              ? const ItalianLearningRules()
              : NoGrammarRules(language),
          clock: () => now,
        );
        return (await e.learningContext()).when(
          success: (c) => c.vocabularyToReinforce,
          failure: (f) => fail('unexpected $f'),
        );
      }

      await analyze(correction); // Italian engine: stored as 'it'.
      expect(await contextWords(AppLanguage.italian), isNotEmpty);
      expect(await contextWords(AppLanguage.spanish), isEmpty);
    });
  });
}
