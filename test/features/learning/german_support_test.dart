import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/default_learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/error_pattern.dart';
import 'package:parla_con_me/features/learning/domain/german_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/italian_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/language_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/exercise_generator.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/in_memory_local_storage.dart';

const _de = GermanLearningRules();
final _now = DateTime.utc(2026, 10, 20, 12);

List<GrammarTopic>? _topics(String original, String corrected) {
  final pattern = ErrorPattern.from(original, corrected);
  return pattern == null ? null : _de.inferGrammarTopics(pattern)?.topics;
}

T _ok<T>(Result<T> r) =>
    r.when(success: (v) => v, failure: (f) => fail('unexpected $f'));

AIResponse _reply(List<Correction> corrections) =>
    AIResponse(message: 'Sehr gut!', corrections: corrections);

Correction _fix(
  String original,
  String corrected, {
  CorrectionCategory category = CorrectionCategory.grammar,
}) => Correction(
  original: original,
  corrected: corrected,
  explanation: 'Weil.',
  category: category,
);

void main() {
  group('capabilities', () {
    test('German is a supported learning language, not an interface one', () {
      expect(AppLanguage.german.code, 'de');
      expect(AppLanguage.german.englishName, 'German');
      expect(supportedLearningLanguages, contains(AppLanguage.german));
      expect(availableSupportLanguages, isNot(contains(AppLanguage.german)));
      expect(
        learningRulesFor(AppLanguage.german)?.language,
        AppLanguage.german,
      );
      for (final support in availableSupportLanguages) {
        expect(
          LanguagePair(
            support: support,
            learning: AppLanguage.german,
          ).isSupported,
          isTrue,
          reason: support.name,
        );
      }
    });

    test('every language with rules is a supported learning language', () {
      for (final l in AppLanguage.values) {
        expect(
          learningRulesFor(l) != null,
          supportedLearningLanguages.contains(l),
          reason: l.name,
        );
      }
    });
  });

  group('ErrorPattern keeps the sentence as context', () {
    test('full tokens are available; identity is unchanged', () {
      final p = ErrorPattern.from(
        'Ich habe gestern nach Berlin gefahren',
        'Ich bin gestern nach Berlin gefahren',
      )!;
      expect(p.fullCorrectedTokens, [
        'ich',
        'bin',
        'gestern',
        'nach',
        'berlin',
        'gefahren',
      ]);
      expect(p.key, 'habe gestern -> bin gestern');
    });
  });

  group('GermanLearningRules: topic inference', () {
    test('the precise cases it knows', () {
      expect(
        _topics(
          'Ich habe gestern nach Berlin gefahren',
          'Ich bin gestern nach Berlin gefahren',
        ),
        [GrammarTopic.habenVsSein, GrammarTopic.perfekt],
      );
      expect(
        _topics('Er hat nach Hause gegangen', 'Er ist nach Hause gegangen'),
        [GrammarTopic.habenVsSein, GrammarTopic.perfekt],
      );
      expect(_topics('Ich gehst nach Hause', 'Ich gehe nach Hause'), [
        GrammarTopic.verbConjugation,
      ]);
      expect(_topics('Ich sehe der Mann', 'Ich sehe den Mann'), [
        GrammarTopic.cases,
        GrammarTopic.articles,
      ]);
      expect(_topics('Mit der Mann', 'Mit dem Mann'), [
        GrammarTopic.cases,
        GrammarTopic.articles,
      ]);
      expect(_topics('Ich habe eine Hund', 'Ich habe einen Hund'), [
        GrammarTopic.cases,
        GrammarTopic.articles,
      ]);
      expect(_topics('Das ist die Haus', 'Das ist das Haus'), [
        GrammarTopic.articles,
      ]);
      expect(_topics('Ich wohne an Berlin', 'Ich wohne in Berlin'), [
        GrammarTopic.prepositions,
      ]);
      expect(_topics('Heute ich gehe', 'Heute gehe ich'), [
        GrammarTopic.wordOrder,
      ]);
    });

    test('no evidence, no topic', () {
      expect(_topics('Hallo', 'Guten Tag'), isNull);
      // haben -> sein but no sein-participle in the sentence: a copula, not
      // the Perfekt auxiliary.
      expect(_topics('Ich habe müde', 'Ich bin müde'), isNull);
      // a verb that takes haben is not evidence for sein
      expect(_topics('Ich bin gegessen', 'Ich habe gegessen'), isNull);
      // a different verb entirely
      expect(_topics('Er geht', 'Er kauft'), isNull);
      expect(
        _topics('Ich möchte gehen', 'Ich möchte zu gehen'),
        isNull,
        reason: '"zu" only added',
      );
      // capitalization alone is not a trackable mistake
      expect(_topics('haus', 'Haus'), isNull);
    });

    test('never produces a topic that belongs to another language', () {
      const other = {
        GrammarTopic.essereVsAvere,
        GrammarTopic.etreVsAvoir,
        GrammarTopic.serVsEstar,
        GrammarTopic.passatoProssimo,
        GrammarTopic.passeCompose,
        GrammarTopic.toBe,
        GrammarTopic.pastSimple,
        GrammarTopic.thirdPersonSingular,
      };
      for (final pair in [
        ('Ich habe nach Berlin gefahren', 'Ich bin nach Berlin gefahren'),
        ('Ich sehe der Mann', 'Ich sehe den Mann'),
        ('Ich gehst', 'Ich gehe'),
      ]) {
        expect(
          (_topics(pair.$1, pair.$2) ?? const []).toSet().intersection(other),
          isEmpty,
          reason: pair.toString(),
        );
      }
    });
  });

  group('GermanLearningRules: success, articles, labels', () {
    LearningError known() => LearningError(
      id: 'de:habe gestern -> bin gestern',
      language: 'de',
      category: LearningErrorCategory.grammar,
      original: 'habe gestern',
      corrected: 'bin gestern',
      grammarTopic: GrammarTopic.habenVsSein,
      firstSeenAt: _now,
      lastSeenAt: _now,
      confidence: 0.9,
    );

    Map<GrammarTopic, double> detect(String message) =>
        _de.detectGrammarSuccesses(
          messageTokens: ErrorPattern.tokensOf(message),
          knownErrors: [known()],
          errorKeysThisTurn: const {},
          errorTopicsThisTurn: const {},
        );

    test('the corrected wording after a mistake is credited, literally', () {
      expect(detect('Ich bin gestern nach Wien gefahren'), {
        GrammarTopic.habenVsSein: 0.7,
      });
      expect(detect('Ich habe gestern gearbeitet'), isEmpty);
    });

    test('articles and prompt names', () {
      for (final w in [
        'der',
        'die',
        'das',
        'den',
        'dem',
        'ein',
        'eine',
        'einen',
      ]) {
        expect(_de.isArticle(w), isTrue, reason: w);
      }
      for (final w in ['the', 'el', 'le', 'il', 'mein', 'kein', 'und']) {
        expect(_de.isArticle(w), isFalse, reason: w);
      }
      expect(
        _de.describeTopic(GrammarTopic.habenVsSein),
        'choosing haben or sein as the auxiliary verb',
      );
      expect(_de.describeTopic(GrammarTopic.etreVsAvoir), 'etreVsAvoir');
    });
  });

  group('German in the shared memory', () {
    late InMemoryLocalStorage storage;
    late LocalLearningRepository repo;
    late DefaultLearningEngine german;

    setUp(() async {
      storage = InMemoryLocalStorage();
      repo = LocalLearningRepository(storage);
      german = DefaultLearningEngine(repo, rules: _de, clock: () => _now);
      final italian = DefaultLearningEngine(
        repo,
        rules: const ItalianLearningRules(),
        clock: () => _now,
      );
      for (var i = 0; i < 2; i++) {
        await german.analyze(
          userMessage: 'x',
          response: _reply([
            _fix('Ich sehe der Mann', 'Ich sehe den Mann'),
            _fix(
              'Ich brauche ein Handy',
              'Ich brauche ein Mobiltelefon',
              category: CorrectionCategory.vocabulary,
            ),
          ]),
        );
        await italian.analyze(
          userMessage: 'x',
          response: _reply([_fix('la problema', 'il problema')]),
        );
      }
    });

    test('German is recorded and scoped as de', () async {
      final de = _ok(await german.summary());
      expect(de.errors.every((e) => e.language == 'de'), isTrue);
      expect(de.errors.every((e) => e.id.startsWith('de:')), isTrue);
      expect(
        de.grammarTopics.map((t) => t.topic),
        contains(GrammarTopic.cases),
      );
      expect(de.vocabularyItems.single.id, 'de:mobiltelefon');
      expect(
        _ok(
          await repo.getLearningSummary(),
        ).forLanguage('it').errors.map((e) => e.id),
        contains('la problema -> il problema'),
      );
    });

    test('the AI context carries only German', () async {
      final context = _ok(await german.learningContext());
      expect(context.priorityTopics, contains(GrammarTopic.cases));
      for (final e in context.recurringErrors) {
        expect(e.correct, isNot(contains('il problema')));
      }
    });

    test('review: German ids are scoped and independent of Italian', () async {
      final reviews = LocalReviewRepository(storage);
      DefaultReviewEngine engine(AppLanguage l) =>
          DefaultReviewEngine(repo, reviews, learningLanguage: l);
      Future<List<String>> queue(AppLanguage l) async => _ok(
        await engine(l).getReviewQueue(now: _now),
      ).map((i) => i.id).toList();

      final de = await queue(AppLanguage.german);
      final it = await queue(AppLanguage.italian);
      expect(de, contains('grammar:de:cases'));
      expect(it.where((id) => id.contains('de:')), isEmpty);
      expect(de.toSet().intersection(it.toSet()), isEmpty);
    });

    test('exercises for German from German data only', () async {
      final summary = _ok(await repo.getLearningSummary());
      const generator = DefaultExerciseGenerator(
        learningLanguage: AppLanguage.german,
      );
      final error = summary
          .forLanguage('de')
          .errors
          .firstWhere((e) => e.grammarTopic == GrammarTopic.cases);
      final correction = _ok(
        generator.generate(
          ReviewItem.discovered(ReviewItemType.error, error.id, _now),
          summary,
        ),
      );
      expect(correction.type, ExerciseType.errorCorrection);
      expect(correction.correctAnswer, error.corrected);

      final choice = _ok(
        generator.generate(
          ReviewItem.discovered(ReviewItemType.grammar, 'de:cases', _now),
          summary,
        ),
      );
      expect(choice.type, ExerciseType.grammarChoice);
      expect(choice.prompt, 'cases');
      expect(choice.options, contains(choice.correctAnswer));

      expect(
        generator.generate(
          ReviewItem.discovered(
            ReviewItemType.error,
            'la problema -> il problema',
            _now,
          ),
          summary,
        ),
        isA<Failure<Exercise>>(),
      );
    });
  });

  test('the teacher prompt for German: support and learning language', () {
    final text = buildTeacherInstruction(
      profile: const UserLearningProfile(
        learningLanguage: AppLanguage.german,
        level: LanguageLevel.a2,
        goals: {LearningGoal.work},
        focusAreas: {LearningFocus.grammar},
      ),
      correctionMode: false,
      learningContext: const LearningContext(
        priorityTopics: [GrammarTopic.cases],
      ),
    );
    expect(text, contains('Support language: Spanish'));
    expect(text, contains('Learning language: German'));
    expect(text, contains('study German'));
    expect(text, contains('use German at work'));
    expect(text, contains('- cases (Nominativ, Akkusativ, Dativ, Genitiv)'));
    expect(text, isNot(contains('essere')));
  });

  test('the German rules name no other language', () {
    final text = File(
      'lib/features/learning/domain/german_learning_rules.dart',
    ).readAsStringSync().toLowerCase();
    for (final other in [
      'italian',
      'english',
      'french',
      'spanish',
      'portuguese',
    ]) {
      expect(text, isNot(contains(other)), reason: other);
    }
  });
}
