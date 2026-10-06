import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/learning/domain/error_pattern.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic_inference.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';

final _t1 = DateTime.utc(2026, 10, 5, 10);
final _t2 = DateTime.utc(2026, 10, 6, 9);

ErrorPattern _pattern(String original, String corrected) =>
    ErrorPattern.from(original, corrected)!;

void main() {
  group('ErrorPattern (identity of a mistake)', () {
    test('a whole sentence and a fragment are the same mistake', () {
      final sentence = _pattern(
        'Ieri ho andato al supermercato.',
        'Ieri sono andato al supermercato.',
      );
      final fragment = _pattern('ho andato', 'sono andato');

      expect(sentence.original, 'ho andato');
      expect(sentence.corrected, 'sono andato');
      expect(sentence.key, 'ho andato -> sono andato');
      expect(fragment.key, sentence.key);
    });

    test('case and surrounding punctuation do not matter', () {
      expect(
        _pattern(
          'Ieri Ho andato al supermercato!',
          'ieri sono andato al supermercato',
        ).key,
        'ho andato -> sono andato',
      );
    });

    test('different words are different mistakes', () {
      expect(
        _pattern('ho venuto', 'sono venuto').key,
        isNot(_pattern('ho andato', 'sono andato').key),
      );
      expect(
        _pattern('la problema', 'il problema').key,
        isNot(_pattern('ho andato', 'sono andato').key),
      );
    });

    test('accents are part of the mistake', () {
      final p = _pattern(
        'Sono stanco perche ho lavorato.',
        'Sono stanco perché ho lavorato.',
      );
      expect(p.original, 'perche');
      expect(p.corrected, 'perché');
    });

    test('a missing word keeps one word of context', () {
      final p = _pattern('vado supermercato', 'vado al supermercato');
      expect(p.original, 'supermercato');
      expect(p.corrected, 'al supermercato');
    });

    test('identical, case-only or empty pairs are not a mistake', () {
      expect(ErrorPattern.from('ho fatto', 'ho fatto'), isNull);
      expect(ErrorPattern.from('Ciao!', 'ciao'), isNull);
      expect(ErrorPattern.from('', 'sono andato'), isNull);
      expect(ErrorPattern.from('ho andato', '  '), isNull);
    });
  });

  group('grammar topic inference', () {
    test(
      'avere + motion participle -> essere is essereVsAvere/passatoProssimo',
      () {
        final inference = inferGrammarTopics(
          _pattern('ho andato', 'sono andato'),
        )!;
        expect(inference.topics, [
          GrammarTopic.essereVsAvere,
          GrammarTopic.passatoProssimo,
        ]);
        expect(inference.primary, GrammarTopic.essereVsAvere);
        expect(inference.confidence, 0.8);

        expect(
          inferGrammarTopics(
            _pattern('Lei ha venuta qui', 'Lei è venuta qui'),
          )?.primary,
          GrammarTopic.essereVsAvere,
        );
      },
    );

    test('articles and prepositions swaps', () {
      final articles = inferGrammarTopics(
        _pattern('la problema', 'il problema'),
      )!;
      expect(articles.topics, [GrammarTopic.articles]);
      expect(articles.confidence, lessThan(0.8));

      expect(
        inferGrammarTopics(
          _pattern('vado in supermercato', 'vado al supermercato'),
        )!.topics,
        [GrammarTopic.prepositions],
      );
    });

    test('no reliable rule means no topic (better than a wrong one)', () {
      expect(
        inferGrammarTopics(
          _pattern('ho mangiato pizza', 'ho mangiato la pizza'),
        ),
        isNull,
      );
      expect(inferGrammarTopics(_pattern('ho fatto', 'ho mangiato')), isNull);
      // "ho uscito il cane" can be correct, so it is not inferred.
      expect(inferGrammarTopics(_pattern('ho uscito', 'sono uscito')), isNull);
      expect(inferGrammarTopics(_pattern('perche', 'perché')), isNull);
    });
  });

  group('LearningError', () {
    LearningError error({
      DateTime? seen,
      String explanation = 'Con andare si usa essere.',
      GrammarTopic? topic = GrammarTopic.essereVsAvere,
      double confidence = 0.9,
    }) => LearningError(
      id: 'ho andato -> sono andato',
      category: LearningErrorCategory.grammar,
      original: 'ho andato',
      corrected: 'sono andato',
      explanation: explanation,
      grammarTopic: topic,
      firstSeenAt: seen ?? _t1,
      lastSeenAt: seen ?? _t1,
      confidence: confidence,
    );

    test('a new error starts at frequency 1 and is not recurring', () {
      final e = error();
      expect(e.frequency, 1);
      expect(e.isRecurring, isFalse);
    });

    test('merging a repeat increases frequency and updates lastSeenAt', () {
      final merged = error().merge(error(seen: _t2));
      expect(merged.frequency, 2);
      expect(merged.isRecurring, isTrue);
      expect(merged.firstSeenAt, _t1);
      expect(merged.lastSeenAt, _t2);
    });

    test(
      'merge keeps the topic, the latest explanation and the best confidence',
      () {
        final merged = error(confidence: 0.6).merge(
          error(seen: _t2, explanation: 'Nuova spiegazione.', topic: null),
        );
        expect(merged.grammarTopic, GrammarTopic.essereVsAvere);
        expect(merged.explanation, 'Nuova spiegazione.');
        expect(merged.confidence, 0.9);

        // An empty explanation never erases a useful one.
        expect(
          error().merge(error(seen: _t2, explanation: '')).explanation,
          'Con andare si usa essere.',
        );
      },
    );

    test('merging out of order keeps the real first/last dates', () {
      final merged = error(seen: _t2).merge(error(seen: _t1));
      expect(merged.firstSeenAt, _t1);
      expect(merged.lastSeenAt, _t2);
    });
  });

  group('GrammarTopicProgress', () {
    test('starts empty with zero mastery', () {
      const p = GrammarTopicProgress(topic: GrammarTopic.passatoProssimo);
      expect(p.exposureCount, 0);
      expect(p.confidence, 0);
    });

    test('8 exposures with 4 successes is 0.5', () {
      var p = const GrammarTopicProgress(topic: GrammarTopic.passatoProssimo);
      for (var i = 0; i < 4; i++) {
        p = p.recordExposure(at: _t1, wasError: true);
      }
      for (var i = 0; i < 4; i++) {
        p = p.recordSuccess(at: _t2);
      }
      expect(p.exposureCount, 8);
      expect(p.errorCount, 4);
      expect(p.successfulUseCount, 4);
      expect(p.confidence, 0.5);
      expect(p.lastSeenAt, _t2);
    });

    test('lastSeenAt never moves backwards', () {
      final p = const GrammarTopicProgress(
        topic: GrammarTopic.articles,
      ).recordExposure(at: _t2).recordExposure(at: _t1);
      expect(p.lastSeenAt, _t2);
    });
  });

  group('UserVocabulary', () {
    test('identity is per language and case-insensitive', () {
      expect(
        UserVocabulary.idFor(' Pane ', 'it'),
        UserVocabulary.idFor('pane', 'it'),
      );
      expect(
        UserVocabulary.idFor('pane', 'it'),
        isNot(UserVocabulary.idFor('pane', 'en')),
      );
    });

    test('merging sums counts, keeps the meaning and the latest date', () {
      final a = UserVocabulary.of(word: 'pane', at: _t1, meaning: 'pan');
      final b = UserVocabulary.of(word: 'Pane', at: _t2, successfulUseCount: 1);
      final merged = a.merge(b);
      expect(merged.exposureCount, 2);
      expect(merged.successfulUseCount, 1);
      expect(merged.confidence, 0.5);
      expect(merged.meaning, 'pan');
      expect(merged.word, 'pane');
      expect(merged.lastSeenAt, _t2);
    });
  });
}
