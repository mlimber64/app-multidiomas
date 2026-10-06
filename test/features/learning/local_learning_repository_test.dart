import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';

import '../../support/in_memory_local_storage.dart';

final _t1 = DateTime.utc(2026, 10, 5, 10);
final _t2 = DateTime.utc(2026, 10, 6, 9);

LearningError _error(
  String id, {
  DateTime? at,
  LearningErrorCategory category = LearningErrorCategory.grammar,
  GrammarTopic? topic,
  String explanation = 'Spiegazione.',
}) => LearningError(
  id: id,
  category: category,
  original: id.split(' -> ').first,
  corrected: id.split(' -> ').last,
  explanation: explanation,
  grammarTopic: topic,
  firstSeenAt: at ?? _t1,
  lastSeenAt: at ?? _t1,
  confidence: 0.9,
);

LearnerLearningSummary _summary(Result<LearnerLearningSummary> r) =>
    r.when(success: (s) => s, failure: (f) => fail('unexpected $f'));

void main() {
  late InMemoryLocalStorage storage;
  late LocalLearningRepository repo;

  setUp(() {
    storage = InMemoryLocalStorage();
    repo = LocalLearningRepository(storage);
  });

  group('empty and defensive reads', () {
    test('nothing stored is an empty summary, not an error', () async {
      final s = _summary(await repo.getLearningSummary());
      expect(s.totalErrors, 0);
      expect(s.recurringErrors, isEmpty);
      expect(s.grammarTopics, isEmpty);
      expect(s.vocabularyItems, isEmpty);
      expect(s.lastUpdatedAt, isNull);
    });

    test('a corrupt document reads as empty and can be overwritten', () async {
      for (final bad in [
        '{not json',
        '[]',
        '"x"',
        '{"errors": []}',
        '{"version": "1"}',
        '{"version": 0}',
      ]) {
        storage.data[LocalLearningRepository.storageKey] = bad;
        expect(
          _summary(await repo.getLearningSummary()).totalErrors,
          0,
          reason: bad,
        );
      }
      storage.data[LocalLearningRepository.storageKey] = '{not json';
      await repo.recordError(_error('ho andato -> sono andato'));
      expect(_summary(await repo.getLearningSummary()).totalErrors, 1);
    });

    test('corrupt entries are skipped without losing the good ones', () async {
      storage.data[LocalLearningRepository.storageKey] = jsonEncode({
        'version': 1,
        'errors': [
          'garbage',
          {'id': 'x'},
          {
            'id': 'ho andato -> sono andato',
            'category': 'nonsense',
            'original': 'ho andato',
            'corrected': 'sono andato',
            'frequency': 3,
            'firstSeenAt': _t1.toIso8601String(),
            'lastSeenAt': _t1.toIso8601String(),
            'confidence': 7,
          },
        ],
        'grammarTopics': [
          {'topic': 'nonexistent'},
          {'topic': 'articles', 'exposureCount': -4, 'errorCount': 'x'},
        ],
        'vocabulary': [
          42,
          {'id': 'it:pane'},
        ],
      });
      final s = _summary(await repo.getLearningSummary());
      expect(s.totalErrors, 3);
      final e = s.recurringErrors.single;
      expect(
        e.category,
        LearningErrorCategory.other,
        reason: 'unknown category',
      );
      expect(e.confidence, 0, reason: 'out-of-range confidence is dropped');
      expect(s.grammarTopics.single.topic, GrammarTopic.articles);
      expect(s.grammarTopics.single.exposureCount, 0);
      expect(s.vocabularyItems, isEmpty);
    });

    test('a newer document version is never read or overwritten', () async {
      final newer = jsonEncode({'version': 2, 'errors': [], 'extra': 'data'});
      storage.data[LocalLearningRepository.storageKey] = newer;

      final read = await repo.getLearningSummary();
      expect(read, isA<Failure<LearnerLearningSummary>>());
      expect(
        read.when(success: (_) => null, failure: (f) => f),
        isA<StorageFailure>(),
      );
      expect(await repo.recordError(_error('a -> b')), isA<Failure<void>>());
      expect(
        await repo.recordGrammarTopicExposure(GrammarTopic.articles, at: _t1),
        isA<Failure<void>>(),
      );
      expect(storage.data[LocalLearningRepository.storageKey], newer);
    });
  });

  group('errors', () {
    test('saves and recovers every field after a restart', () async {
      await repo.recordError(
        _error(
          'ho andato -> sono andato',
          at: _t2,
          topic: GrammarTopic.essereVsAvere,
        ),
      );

      // A new repository over the same storage simulates reopening the app.
      final recovered = _summary(
        await LocalLearningRepository(storage).getLearningSummary(),
      );
      expect(recovered.totalErrors, 1);
      expect(recovered.lastUpdatedAt, _t2);
      expect(
        recovered.recurringErrors,
        isEmpty,
        reason: 'frequency 1 is not recurring',
      );

      await repo.recordError(_error('ho andato -> sono andato', at: _t2));
      final e = _summary(
        await repo.getLearningSummary(),
      ).recurringErrors.single;
      expect(e.id, 'ho andato -> sono andato');
      expect(e.category, LearningErrorCategory.grammar);
      expect(e.original, 'ho andato');
      expect(e.corrected, 'sono andato');
      expect(e.explanation, 'Spiegazione.');
      expect(e.grammarTopic, GrammarTopic.essereVsAvere);
      expect(e.frequency, 2);
      expect(e.firstSeenAt, _t2);
      expect(e.confidence, 0.9);
    });

    test(
      'the same id is merged into one record; ids differ -> separate records',
      () async {
        await repo.recordError(_error('ho andato -> sono andato', at: _t1));
        await repo.recordError(_error('ho andato -> sono andato', at: _t2));
        await repo.recordError(_error('la problema -> il problema', at: _t1));

        final s = _summary(await repo.getLearningSummary());
        expect(s.totalErrors, 3, reason: 'sum of frequencies');
        final recurring = s.recurringErrors.single;
        expect(recurring.id, 'ho andato -> sono andato');
        expect(recurring.frequency, 2);
        expect(recurring.firstSeenAt, _t1);
        expect(recurring.lastSeenAt, _t2);

        final doc =
            jsonDecode(storage.data[LocalLearningRepository.storageKey]!)
                as Map;
        expect(doc['version'], 1);
        expect(
          doc['errors'],
          hasLength(2),
          reason: 'no duplicate record stored',
        );
      },
    );

    test('recurring errors are ordered by frequency, then recency', () async {
      await repo.recordError(_error('a -> b', at: _t1));
      await repo.recordError(_error('a -> b', at: _t1));
      await repo.recordError(_error('c -> d', at: _t2));
      await repo.recordError(_error('c -> d', at: _t2));
      await repo.recordError(_error('c -> d', at: _t2));
      await repo.recordError(_error('e -> f', at: _t2));
      await repo.recordError(_error('e -> f', at: _t2));

      final ids = _summary(
        await repo.getLearningSummary(),
      ).recurringErrors.map((e) => e.id);
      expect(ids, ['c -> d', 'e -> f', 'a -> b']);
    });
  });

  group('grammar topics', () {
    test('exposures, errors and successes accumulate per topic', () async {
      await repo.recordGrammarTopicExposure(
        GrammarTopic.passatoProssimo,
        at: _t1,
        wasError: true,
      );
      await repo.recordGrammarTopicExposure(
        GrammarTopic.passatoProssimo,
        at: _t1,
        wasError: true,
      );
      await repo.recordSuccessfulGrammarUse(
        GrammarTopic.passatoProssimo,
        at: _t2,
      );
      await repo.recordGrammarTopicExposure(GrammarTopic.articles, at: _t1);

      final s = _summary(await repo.getLearningSummary());
      expect(s.grammarTopics, hasLength(2));
      final passato = s.grammarTopics.firstWhere(
        (t) => t.topic == GrammarTopic.passatoProssimo,
      );
      expect(passato.exposureCount, 3);
      expect(passato.errorCount, 2);
      expect(passato.successfulUseCount, 1);
      expect(passato.confidence, closeTo(1 / 3, 1e-9));
      expect(passato.lastSeenAt, _t2);
      final articles = s.grammarTopics.firstWhere(
        (t) => t.topic == GrammarTopic.articles,
      );
      expect(articles.errorCount, 0);
      expect(
        s.grammarTopics.first.topic,
        GrammarTopic.passatoProssimo,
        reason: 'most exposed first',
      );
    });
  });

  group('vocabulary', () {
    test('words merge by id and several words coexist', () async {
      await repo.recordVocabulary(
        UserVocabulary.of(word: 'pane', at: _t1, meaning: 'pan'),
      );
      await repo.recordVocabulary(
        UserVocabulary.of(word: 'Pane', at: _t2, successfulUseCount: 1),
      );
      await repo.recordVocabulary(
        UserVocabulary.of(word: 'formaggio', at: _t1),
      );

      final s = _summary(await repo.getLearningSummary());
      expect(s.vocabularyItems, hasLength(2));
      final pane = s.vocabularyItems.firstWhere((v) => v.id == 'it:pane');
      expect(pane.exposureCount, 2);
      expect(pane.successfulUseCount, 1);
      expect(pane.meaning, 'pan');
      expect(pane.lastSeenAt, _t2);
      expect(
        s.vocabularyItems.first.id,
        'it:pane',
        reason: 'most recent first',
      );
    });
  });

  group('maintenance', () {
    test('clearLearningData erases the memory but not conversations', () async {
      storage.data['conversations'] = '{"v":1,"conversations":[]}';
      await repo.recordError(_error('a -> b'));
      await repo.recordGrammarTopicExposure(GrammarTopic.articles, at: _t1);

      await repo.clearLearningData();

      expect(_summary(await repo.getLearningSummary()).totalErrors, 0);
      expect(
        storage.data.containsKey(LocalLearningRepository.storageKey),
        isFalse,
      );
      expect(storage.data['conversations'], '{"v":1,"conversations":[]}');
    });

    test('concurrent writes are serialized and none is lost', () async {
      await Future.wait([
        for (var i = 0; i < 25; i++)
          repo.recordError(_error('ho andato -> sono andato', at: _t1)),
        for (var i = 0; i < 25; i++)
          repo.recordGrammarTopicExposure(GrammarTopic.articles, at: _t1),
      ]);
      final s = _summary(await repo.getLearningSummary());
      expect(s.recurringErrors.single.frequency, 25);
      expect(s.grammarTopics.single.exposureCount, 25);
    });
  });

  test(
    'vocabulary stored with language "it" before this patch still loads',
    () async {
      storage.data['learning_memory'] = jsonEncode({
        'version': 1,
        'vocabulary': [
          {
            'id': 'it:ciao',
            'word': 'ciao',
            'language': 'it',
            'exposureCount': 2,
            'successfulUseCount': 1,
            'lastSeenAt': _t1.toIso8601String(),
          },
        ],
      });
      final v = _summary(
        await repo.getLearningSummary(),
      ).vocabularyItems.single;
      expect(v.id, 'it:ciao');
      expect(v.language, 'it');
      expect(v.exposureCount, 2);
    },
  );
}
