import 'package:parla_con_me/features/learning/domain/italian_learning_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_context_builder.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_overview.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';

final _now = DateTime.utc(2026, 10, 20, 12);

LearningError _error(
  String original,
  String corrected, {
  int frequency = 2,
  GrammarTopic? topic,
  DateTime? lastSeen,
}) => LearningError(
  id: '$original -> $corrected',
  category: LearningErrorCategory.grammar,
  original: original,
  corrected: corrected,
  grammarTopic: topic,
  frequency: frequency,
  firstSeenAt: lastSeen ?? _now,
  lastSeenAt: lastSeen ?? _now,
  confidence: 0.9,
);

GrammarTopicProgress _topic(
  GrammarTopic topic, {
  int errors = 0,
  int successes = 0,
}) => GrammarTopicProgress(
  topic: topic,
  exposureCount: errors + successes,
  errorCount: errors,
  successfulUseCount: successes,
  lastSeenAt: _now,
);

UserVocabulary _word(
  String word, {
  int exposure = 1,
  int successes = 0,
  String? meaning,
  DateTime? lastSeen,
}) => UserVocabulary.of(
  word: word,
  at: lastSeen ?? _now,
  meaning: meaning,
  exposureCount: exposure,
  successfulUseCount: successes,
);

LearnerLearningSummary _summary({
  List<LearningError> errors = const [],
  List<GrammarTopicProgress> topics = const [],
  List<UserVocabulary> vocabulary = const [],
}) => LearnerLearningSummary(
  errors: errors,
  recurringErrors: [
    for (final e in errors)
      if (e.isRecurring) e,
  ],
  grammarTopics: topics,
  vocabularyItems: vocabulary,
);

LearningOverview _build(LearnerLearningSummary s) =>
    buildLearningOverview(s, now: _now, rules: const ItalianLearningRules());

void main() {
  group('empty and partial memory', () {
    test('an empty memory is an empty overview', () {
      final o = _build(LearnerLearningSummary.empty);
      expect(o.isEmpty, isTrue);
      expect(o.hasTopics, isFalse);
      expect(o.hasVocabulary, isFalse);
      expect(LearningOverview.empty.isEmpty, isTrue);
    });

    test('only errors: topics and errors, no vocabulary', () {
      final o = _build(
        _summary(
          errors: [
            _error(
              'ho andato',
              'sono andato',
              topic: GrammarTopic.essereVsAvere,
            ),
          ],
          topics: [_topic(GrammarTopic.essereVsAvere, errors: 2)],
        ),
      );
      expect(o.isEmpty, isFalse);
      expect(o.toReinforce.map((t) => t.topic), [GrammarTopic.essereVsAvere]);
      expect(o.recurringErrors.single.incorrect, 'ho andato');
      expect(o.improving, isEmpty);
      expect(o.hasVocabulary, isFalse);
    });

    test('only vocabulary: just words', () {
      final o = _build(
        _summary(vocabulary: [_word('prenotazione', meaning: 'reserva')]),
      );
      expect(o.isEmpty, isFalse);
      expect(o.hasTopics, isFalse);
      expect(o.recurringErrors, isEmpty);
      expect(o.vocabularyToConsolidate.single.word, 'prenotazione');
      expect(o.vocabularyToConsolidate.single.meaning, 'reserva');
    });

    test('only progress: improving, nothing to reinforce', () {
      final o = _build(
        _summary(
          topics: [_topic(GrammarTopic.articles, errors: 1, successes: 4)],
        ),
      );
      expect(o.improving.map((t) => t.topic), [GrammarTopic.articles]);
      expect(o.toReinforce, isEmpty);
      expect(o.isEmpty, isFalse);
    });

    test(
      'data that is not relevant (a lone old topic with no errors) shows nothing',
      () {
        final o = _build(
          _summary(topics: [_topic(GrammarTopic.articles, successes: 3)]),
        );
        expect(o.isEmpty, isTrue);
      },
    );
  });

  group('topics', () {
    test('priorities come in the order the memory ranks them', () {
      final o = _build(
        _summary(
          topics: [
            _topic(GrammarTopic.articles, errors: 2),
            _topic(GrammarTopic.essereVsAvere, errors: 5, successes: 1),
            _topic(GrammarTopic.prepositions, errors: 4),
          ],
        ),
      );
      expect(o.toReinforce.map((t) => t.topic), [
        GrammarTopic.essereVsAvere,
        GrammarTopic.prepositions,
        GrammarTopic.articles,
      ]);
    });

    test('improvement is shown as improvement, never as a weakness', () {
      final o = _build(
        _summary(
          topics: [
            _topic(GrammarTopic.passatoProssimo, errors: 1, successes: 5),
            _topic(GrammarTopic.articles, errors: 3),
          ],
        ),
      );
      expect(o.improving.map((t) => t.topic), [GrammarTopic.passatoProssimo]);
      expect(o.improving.single.standing, TopicStanding.improving);
      expect(o.toReinforce.map((t) => t.topic), [GrammarTopic.articles]);
      expect(o.toReinforce.single.standing, TopicStanding.toReinforce);
      expect(
        o.toReinforce.map((t) => t.topic),
        isNot(contains(GrammarTopic.passatoProssimo)),
      );
    });

    test(
      'the same selection rules as the AI context: one definition of what matters',
      () {
        final summary = _summary(
          topics: [
            _topic(GrammarTopic.articles, errors: 2),
            _topic(GrammarTopic.essereVsAvere, errors: 5),
            _topic(GrammarTopic.prepositions, errors: 4, successes: 1),
            _topic(GrammarTopic.gender, errors: 1, successes: 4),
            _topic(GrammarTopic.plural, errors: 1, successes: 6),
          ],
          errors: [
            _error('ho andato', 'sono andato', frequency: 5),
            _error('la problema', 'il problema', frequency: 3),
            _error('in supermercato', 'al supermercato', frequency: 2),
            _error('uno', 'due', frequency: 1),
          ],
        );
        final overview = _build(summary);
        final context = buildLearningContext(
          summary,
          now: _now,
          language: 'it',
        );
        expect(
          overview.toReinforce
              .take(maxPriorityTopics)
              .map((t) => t.topic)
              .toList(),
          context.priorityTopics,
        );
        expect(
          overview.improving
              .take(maxPositiveSignals)
              .map((t) => t.topic)
              .toList(),
          context.positiveSignals,
        );
        expect(
          overview.recurringErrors
              .take(maxRecurringErrors)
              .map((e) => e.incorrect)
              .toList(),
          context.recurringErrors.map((e) => e.incorrect).toList(),
        );
      },
    );

    test('evidence is the real counts: correct out of appearances', () {
      final o = _build(
        _summary(
          topics: [_topic(GrammarTopic.articles, errors: 4, successes: 4)],
        ),
      );
      // 4 correct out of 8 appearances is "improving" only from 60%; here it is
      // a topic to reinforce that already shows some progress.
      final t = o.toReinforce.single;
      expect(t.successfulUses, 4);
      expect(t.appearances, 8);
      expect(t.hasProgress, isTrue);
      expect(t.correctShare, 0.5);

      final none = _build(
        _summary(topics: [_topic(GrammarTopic.gender, errors: 3)]),
      ).toReinforce.single;
      expect(none.hasProgress, isFalse);
      expect(none.correctShare, 0);
    });

    test('topics are limited to $overviewMaxTopics per list', () {
      final o = _build(
        _summary(
          topics: [
            for (final t in GrammarTopic.values.take(8)) _topic(t, errors: 2),
          ],
        ),
      );
      expect(o.toReinforce, hasLength(overviewMaxTopics));
    });
  });

  group('recurring errors', () {
    test(
      'only errors seen at least twice, at most $overviewMaxRecurringErrors',
      () {
        final o = _build(
          _summary(
            errors: [
              _error('la problema', 'il problema', frequency: 1),
              for (var i = 0; i < 8; i++)
                _error('sbaglio$i', 'giusto$i', frequency: 2 + i),
            ],
          ),
        );
        expect(o.recurringErrors, hasLength(overviewMaxRecurringErrors));
        expect(o.recurringErrors.every((e) => e.isRecurring), isTrue);
        expect(
          o.recurringErrors.map((e) => e.incorrect),
          isNot(contains('la problema')),
        );
        // Most frequent (and so most relevant) first.
        expect(o.recurringErrors.first.incorrect, 'sbaglio7');
      },
    );

    test(
      'an error in an area that is already improving is not listed as a problem',
      () {
        final o = _build(
          _summary(
            topics: [
              _topic(GrammarTopic.essereVsAvere, errors: 5, successes: 8),
            ],
            errors: [
              _error(
                'ho andato',
                'sono andato',
                frequency: 5,
                topic: GrammarTopic.essereVsAvere,
              ),
            ],
          ),
        );
        expect(o.recurringErrors, isEmpty);
        expect(o.improving.single.topic, GrammarTopic.essereVsAvere);
      },
    );
  });

  group('topic detail data', () {
    test('a topic knows its mistakes and the topics they connect it to', () {
      final o = _build(
        _summary(
          topics: [
            _topic(GrammarTopic.passatoProssimo, errors: 4),
            _topic(GrammarTopic.essereVsAvere, errors: 4),
          ],
          errors: [
            _error(
              'ho andato',
              'sono andato',
              frequency: 4,
              topic: GrammarTopic.essereVsAvere,
            ),
            _error(
              'la problema',
              'il problema',
              frequency: 2,
              topic: GrammarTopic.articles,
            ),
          ],
        ),
      );
      final passato = o.toReinforce.firstWhere(
        (t) => t.topic == GrammarTopic.passatoProssimo,
      );
      expect(passato.relatedErrors.map((e) => e.incorrect), ['ho andato']);
      expect(passato.relatedErrors.single.correct, 'sono andato');
      expect(passato.relatedErrors.single.isRecurring, isTrue);
      expect(passato.relatedTopics, [GrammarTopic.essereVsAvere]);

      final essere = o.toReinforce.firstWhere(
        (t) => t.topic == GrammarTopic.essereVsAvere,
      );
      expect(essere.relatedTopics, [GrammarTopic.passatoProssimo]);
    });

    test('related errors are limited and unrelated ones are left out', () {
      final o = _build(
        _summary(
          topics: [_topic(GrammarTopic.articles, errors: 5)],
          errors: [
            for (var i = 0; i < 6; i++)
              _error('la cosa$i', 'il cosa$i', topic: GrammarTopic.articles),
            _error(
              'in supermercato',
              'al supermercato',
              topic: GrammarTopic.prepositions,
            ),
          ],
        ),
      );
      final t = o.toReinforce.single;
      expect(t.relatedErrors, hasLength(overviewMaxRelatedErrors));
      expect(
        t.relatedErrors.map((e) => e.incorrect),
        everyElement(startsWith('la cosa')),
      );
    });
  });

  group('vocabulary', () {
    test(
      'words are split by what the memory can show, never called learned',
      () {
        final o = _build(
          _summary(
            vocabulary: [
              _word('prenotazione'),
              _word('appuntamento', exposure: 3, successes: 1),
              _word('scontrino', exposure: 5, successes: 5),
            ],
          ),
        );
        expect(
          o.vocabularyToConsolidate.map((w) => w.word),
          containsAll(['prenotazione', 'appuntamento']),
        );
        expect(o.vocabularyInUse.map((w) => w.word), ['scontrino']);
        final used = o.vocabularyToConsolidate.firstWhere(
          (w) => w.word == 'appuntamento',
        );
        expect(used.hasBeenUsedCorrectly, isTrue);
        expect(used.isConsolidated, isFalse);
        expect(
          o.vocabularyToConsolidate
              .firstWhere((w) => w.word == 'prenotazione')
              .hasBeenUsedCorrectly,
          isFalse,
        );
        expect(o.vocabularyInUse.single.isConsolidated, isTrue);
      },
    );

    test('all words show, however old, and each section is limited', () {
      final o = _build(
        _summary(
          vocabulary: [
            _word(
              'anticaparola',
              lastSeen: _now.subtract(const Duration(days: 200)),
            ),
            for (var i = 0; i < 70; i++) _word('nuova$i'),
            for (var i = 0; i < 70; i++)
              _word('nota$i', exposure: 5, successes: 5),
          ],
        ),
      );
      expect(
        o.vocabularyToConsolidate,
        hasLength(overviewMaxVocabularyPerSection),
      );
      expect(o.vocabularyInUse, hasLength(overviewMaxVocabularyPerSection));
      final stale = _build(
        _summary(
          vocabulary: [
            _word(
              'anticaparola',
              lastSeen: _now.subtract(const Duration(days: 200)),
            ),
          ],
        ),
      );
      expect(stale.vocabularyToConsolidate.single.word, 'anticaparola');
    });
  });
}
