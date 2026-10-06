import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/exercise_generator.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';

import '../../support/in_memory_local_storage.dart';

final _now = DateTime.utc(2026, 10, 20, 12);

LearningError _error(
  String original,
  String corrected, {
  GrammarTopic? topic,
  LearningErrorCategory category = LearningErrorCategory.grammar,
  String explanation = 'Spiegazione.',
  int frequency = 2,
  String language = 'it',
}) => LearningError(
  id: '$original -> $corrected',
  category: category,
  original: original,
  corrected: corrected,
  explanation: explanation,
  grammarTopic: topic,
  language: language,
  frequency: frequency,
  firstSeenAt: _now,
  lastSeenAt: _now,
  confidence: 0.9,
);

LearnerLearningSummary _summary({
  List<LearningError> errors = const [],
  List<GrammarTopicProgress> topics = const [],
  List<UserVocabulary> vocabulary = const [],
}) => LearnerLearningSummary(
  errors: errors,
  grammarTopics: topics,
  vocabularyItems: vocabulary,
);

ReviewItem _item(ReviewItemType type, String sourceId) =>
    ReviewItem.discovered(type, sourceId, _now);

GrammarTopicProgress _topic(GrammarTopic t) => GrammarTopicProgress(
  topic: t,
  exposureCount: 2,
  errorCount: 2,
  lastSeenAt: _now,
);

Exercise _ok(Result<Exercise> r) =>
    r.when(success: (e) => e, failure: (f) => fail('unexpected $f'));

ExerciseUnavailableReason _reason(Result<Exercise> r) => r.when(
  success: (e) => fail('expected unavailable, got $e'),
  failure: (f) => (f as ExerciseUnavailableFailure).reason,
);

String _source(String path) => File(path).readAsStringSync();

void main() {
  const generator = DefaultExerciseGenerator(
    learningLanguage: AppLanguage.italian,
  );
  final ho = _error(
    'ho andato',
    'sono andato',
    topic: GrammarTopic.essereVsAvere,
  );

  group('error -> correction', () {
    test('built from the stored mistake', () {
      final item = _item(ReviewItemType.error, ho.id);
      final e = _ok(generator.generate(item, _summary(errors: [ho])));
      expect(e.type, ExerciseType.errorCorrection);
      expect(e.reviewItemId, item.id);
      expect(e.id, 'exercise:${item.id}');
      expect(e.prompt, 'ho andato');
      expect(e.correctAnswer, 'sono andato');
      expect(e.explanation, 'Spiegazione.');
      expect(e.isMultipleChoice, isFalse);
    });

    test('a missing source is unavailable, nothing is invented', () {
      final item = _item(ReviewItemType.error, 'gone -> gone');
      expect(
        _reason(generator.generate(item, _summary(errors: [ho]))),
        ExerciseUnavailableReason.sourceMissing,
      );
    });

    test('an error without two different forms is unavailable', () {
      for (final e in [_error('x', '  '), _error('ciao', 'ciao')]) {
        expect(
          _reason(
            generator.generate(
              _item(ReviewItemType.error, e.id),
              _summary(errors: [e]),
            ),
          ),
          ExerciseUnavailableReason.insufficientData,
        );
      }
    });
  });

  group('grammar -> choice', () {
    final summary = _summary(
      topics: [_topic(GrammarTopic.essereVsAvere)],
      errors: [
        ho,
        _error(
          'ho venuto',
          'sono venuto',
          topic: GrammarTopic.essereVsAvere,
          frequency: 1,
        ),
        _error('a il', 'al', topic: GrammarTopic.articles),
      ],
    );
    final item = _item(ReviewItemType.grammar, 'essereVsAvere');

    test('options are the learner own forms for that topic', () {
      final e = _ok(generator.generate(item, summary));
      expect(e.type, ExerciseType.grammarChoice);
      expect(e.reviewItemId, 'grammar:essereVsAvere');
      expect(e.prompt, 'essereVsAvere');
      expect(e.correctAnswer, 'sono andato', reason: 'most frequent error');
      expect(e.options, [
        'ho andato',
        'ho venuto',
        'sono andato',
        'sono venuto',
      ]);
      expect(e.options, contains(e.correctAnswer));
      expect(e.options, isNot(contains('al')), reason: 'other topic');
      expect(e.explanation, 'Spiegazione.');
      expect(e.isMultipleChoice, isTrue);
    });

    test('at most four distinct options', () {
      final many = _summary(
        topics: [_topic(GrammarTopic.articles)],
        errors: [
          for (var i = 0; i < 5; i++)
            _error(
              'a$i',
              'b$i',
              topic: GrammarTopic.articles,
              frequency: 9 - i,
            ),
        ],
      );
      final e = _ok(
        generator.generate(_item(ReviewItemType.grammar, 'articles'), many),
      );
      expect(e.options, hasLength(DefaultExerciseGenerator.maxOptions));
      expect(e.options.toSet(), hasLength(e.options.length));
      expect(e.correctAnswer, 'b0');
    });

    test('a topic with no error of its own is unavailable', () {
      final s = _summary(topics: [_topic(GrammarTopic.plural)]);
      expect(
        _reason(generator.generate(_item(ReviewItemType.grammar, 'plural'), s)),
        ExerciseUnavailableReason.insufficientData,
      );
    });

    test('an unknown topic is unavailable', () {
      expect(
        _reason(
          generator.generate(_item(ReviewItemType.grammar, 'klingon'), summary),
        ),
        ExerciseUnavailableReason.sourceMissing,
      );
    });
  });

  group('vocabulary -> context', () {
    final word = UserVocabulary.of(word: 'computer', at: _now, language: 'it');
    final fix = _error(
      'la macchina da scrivere',
      'il computer',
      category: LearningErrorCategory.vocabulary,
      explanation: 'Parola più comune oggi.',
    );

    test('a cloze from the correction that contains the word', () {
      final item = _item(ReviewItemType.vocabulary, word.id);
      final e = _ok(
        generator.generate(item, _summary(errors: [fix], vocabulary: [word])),
      );
      expect(e.type, ExerciseType.vocabularyContext);
      expect(e.reviewItemId, 'vocabulary:it:computer');
      expect(e.prompt, 'il ${Exercise.blank}');
      expect(e.correctAnswer, 'computer');
      expect(e.explanation, 'Parola più comune oggi.');
      expect(e.isMultipleChoice, isFalse);
    });

    test('multi-word expressions are blanked as a whole', () {
      final w = UserVocabulary.of(word: 'in ritardo', at: _now, language: 'it');
      final e = _ok(
        generator.generate(
          _item(ReviewItemType.vocabulary, w.id),
          _summary(
            errors: [_error('tardi', 'sono in ritardo')],
            vocabulary: [w],
          ),
        ),
      );
      expect(e.prompt, 'sono ${Exercise.blank}');
      expect(e.correctAnswer, 'in ritardo');
    });

    test(
      'no correction with context -> unavailable (no sentence invented)',
      () {
        final item = _item(ReviewItemType.vocabulary, word.id);
        for (final errors in [
          <LearningError>[],
          [_error('pc', 'computer')],
          [_error('la macchina', 'il telefono')],
        ]) {
          expect(
            _reason(
              generator.generate(
                item,
                _summary(errors: errors, vocabulary: [word]),
              ),
            ),
            ExerciseUnavailableReason.insufficientData,
          );
        }
      },
    );

    test('a missing word is unavailable', () {
      expect(
        _reason(
          generator.generate(
            _item(ReviewItemType.vocabulary, 'it:ghost'),
            _summary(errors: [fix]),
          ),
        ),
        ExerciseUnavailableReason.sourceMissing,
      );
    });
  });

  group('language', () {
    test('vocabulary of another language is never used', () {
      final es = UserVocabulary.of(word: 'computer', at: _now, language: 'es');
      final summary = _summary(
        errors: [_error('la macchina', 'il computer', language: 'es')],
        vocabulary: [es],
      );
      final item = _item(ReviewItemType.vocabulary, es.id);

      expect(
        _reason(generator.generate(item, summary)),
        ExerciseUnavailableReason.sourceMissing,
      );
      // Only the configured language decides; nothing is fixed to Italian.
      const spanish = DefaultExerciseGenerator(
        learningLanguage: AppLanguage.spanish,
      );
      expect(_ok(spanish.generate(item, summary)).correctAnswer, 'computer');
    });

    test('the generator sources contain no hardcoded language code', () {
      final text = _source(
        'lib/features/review/domain/exercise_generator.dart',
      );
      expect(text, isNot(contains("'it'")));
      expect(text, isNot(contains('"it"')));
    });
  });

  group('determinism and purity', () {
    test('same input, same exercise, whatever the list order', () {
      final errors = [
        ho,
        _error('ho venuto', 'sono venuto', topic: GrammarTopic.essereVsAvere),
        _error('ho partito', 'sono partito', topic: GrammarTopic.essereVsAvere),
      ];
      final item = _item(ReviewItemType.grammar, 'essereVsAvere');
      Exercise build(List<LearningError> list) => _ok(
        generator.generate(
          item,
          _summary(topics: [_topic(GrammarTopic.essereVsAvere)], errors: list),
        ),
      );
      final first = build(errors);
      expect(build(errors), first);
      expect(build(errors.reversed.toList()), first);
      expect(build([...errors]..shuffle()), first);
      // Equal frequency: ties are broken by id, not by position.
      expect(first.correctAnswer, 'sono andato');
    });

    test('the schedule of the item does not influence the exercise', () {
      final item = _item(ReviewItemType.error, ho.id);
      final reviewed = item.recordResult(ReviewResult.failure, _now);
      final s = _summary(errors: [ho]);
      final a = _ok(generator.generate(item, s));
      final b = _ok(generator.generate(reviewed, s));
      expect(b, a);
    });

    test('the generator sources use no randomness, clock or network', () {
      final text = _source(
        'lib/features/review/domain/exercise_generator.dart',
      );
      for (final banned in [
        'Random',
        'DateTime.now',
        'dart:io',
        'http',
        'Uuid',
      ]) {
        expect(text, isNot(contains(banned)), reason: banned);
      }
    });
  });

  group('persistence', () {
    test(
      'generating exercises changes neither learning nor review memory',
      () async {
        final storage = InMemoryLocalStorage();
        final learning = LocalLearningRepository(storage);
        final reviews = LocalReviewRepository(storage);
        await learning.recordError(
          _error('ho andato', 'sono andato', topic: GrammarTopic.essereVsAvere),
        );
        await learning.recordError(
          _error('ho andato', 'sono andato', topic: GrammarTopic.essereVsAvere),
        );
        await learning.recordGrammarTopicExposure(
          GrammarTopic.essereVsAvere,
          at: _now,
          wasError: true,
        );
        final engine = DefaultReviewEngine(
          learning,
          reviews,
          learningLanguage: AppLanguage.italian,
        );
        final queue = (await engine.getReviewQueue(
          now: _now,
        )).when(success: (q) => q, failure: (f) => fail('unexpected $f'));
        expect(queue, isNotEmpty);

        final before = Map<String, String>.of(storage.data);
        final summary = (await learning.getLearningSummary()).when(
          success: (s) => s,
          failure: (f) => fail('unexpected $f'),
        );
        for (final item in queue) {
          generator.generate(item, summary);
        }
        expect(storage.data, before);
        expect(storage.data.keys.toSet(), {'learning_memory', 'review_memory'});
      },
    );
  });
}
