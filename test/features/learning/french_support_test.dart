import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/default_learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/english_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/error_pattern.dart';
import 'package:parla_con_me/features/learning/domain/french_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/italian_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/language_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/exercise_generator.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/in_memory_local_storage.dart';

const _fr = FrenchLearningRules();
final _now = DateTime.utc(2026, 10, 20, 12);

List<GrammarTopic>? _topics(String original, String corrected) {
  final pattern = ErrorPattern.from(original, corrected);
  return pattern == null ? null : _fr.inferGrammarTopics(pattern)?.topics;
}

T _ok<T>(Result<T> r) =>
    r.when(success: (v) => v, failure: (f) => fail('unexpected $f'));

AIResponse _reply(List<Correction> corrections) =>
    AIResponse(message: 'Très bien !', corrections: corrections);

Correction _fix(
  String original,
  String corrected, {
  CorrectionCategory category = CorrectionCategory.grammar,
}) => Correction(
  original: original,
  corrected: corrected,
  explanation: 'Parce que.',
  category: category,
);

void main() {
  group('capabilities', () {
    test('French is a supported learning language, not an interface one', () {
      expect(AppLanguage.french.code, 'fr');
      expect(AppLanguage.french.englishName, 'French');
      expect(supportedLearningLanguages, contains(AppLanguage.french));
      expect(availableSupportLanguages, isNot(contains(AppLanguage.french)));
      expect(availableUiLanguages, isNot(contains(AppLanguage.french)));
      expect(
        learningRulesFor(AppLanguage.french)?.language,
        AppLanguage.french,
      );
    });

    test(
      'pairs: any interface language -> French, never French as support',
      () {
        for (final support in availableSupportLanguages) {
          expect(
            LanguagePair(
              support: support,
              learning: AppLanguage.french,
            ).isSupported,
            isTrue,
            reason: support.name,
          );
        }
        expect(
          const LanguagePair(
            support: AppLanguage.french,
            learning: AppLanguage.italian,
          ).isSupported,
          isFalse,
          reason: 'there is no French interface yet',
        );
      },
    );
  });

  group('FrenchLearningRules: topic inference', () {
    test('the precise cases it knows', () {
      expect(_topics("J'ai allé au marché", 'Je suis allé au marché'), [
        GrammarTopic.etreVsAvoir,
        GrammarTopic.passeCompose,
      ]);
      expect(_topics('Il a tombé', 'Il est tombé'), [
        GrammarTopic.etreVsAvoir,
        GrammarTopic.passeCompose,
      ]);
      expect(_topics('Elles ont arrivé', 'Elles sont arrivées'), [
        GrammarTopic.etreVsAvoir,
        GrammarTopic.passeCompose,
      ]);
      expect(_topics('Je regarde les chat', 'Je regarde les chats'), [
        GrammarTopic.plural,
      ]);
      expect(_topics('des animal', 'des animaux'), [GrammarTopic.plural]);
      expect(_topics('Nous mangons ici', 'Nous mangeons ici'), [
        GrammarTopic.verbConjugation,
      ]);
      expect(_topics('Tu manges', 'Tu mange'), [GrammarTopic.verbConjugation]);
      expect(
        _topics('Manges', 'Mange'),
        isNull,
        reason: 'no subject pronoun before the verb',
      );
      expect(_topics('Tu chantes ici', 'Tu chante ici'), [
        GrammarTopic.verbConjugation,
      ]);
      expect(_topics('Le maison est grande', 'La maison est grande'), [
        GrammarTopic.articles,
      ]);
      expect(_topics("J'ai chat", "J'ai un chat"), [GrammarTopic.articles]);
      expect(_topics('Je vais en Paris', 'Je vais à Paris'), [
        GrammarTopic.prepositions,
      ]);
      expect(_topics('toujours je vais', 'je vais toujours'), [
        GrammarTopic.wordOrder,
      ]);
    });

    test('no evidence, no topic', () {
      expect(_topics('Bonjour', 'Salut'), isNull);
      expect(_topics('Il parle', 'Il chante'), isNull, reason: 'another verb');
      expect(_topics('Les chat', 'Les chien'), isNull);
      expect(_topics('Tu es ici', 'Tu as ici'), isNull, reason: 'too short');
      // Verbs that can take avoir are not être verbs.
      expect(
        _topics("J'ai sorti la voiture", 'Je suis sorti la voiture'),
        isNull,
      );
      // A preposition only added is not safely a preposition issue.
      expect(_topics('Je veux aller', 'Je veux à aller'), isNull);
      expect(_topics('Même texte', 'même texte'), isNull);
    });

    test('never produces a topic that belongs to another language', () {
      const other = {
        GrammarTopic.essereVsAvere,
        GrammarTopic.passatoProssimo,
        GrammarTopic.toBe,
        GrammarTopic.presentContinuous,
        GrammarTopic.pastSimple,
        GrammarTopic.presentPerfect,
        GrammarTopic.thirdPersonSingular,
      };
      for (final pair in [
        ("J'ai allé", 'Je suis allé'),
        ('les chat', 'les chats'),
        ('Nous mangons', 'Nous mangeons'),
        ('le maison', 'la maison'),
      ]) {
        expect(
          (_topics(pair.$1, pair.$2) ?? const []).toSet().intersection(other),
          isEmpty,
          reason: pair.toString(),
        );
      }
    });
  });

  group('FrenchLearningRules: success, articles, labels', () {
    LearningError known() => LearningError(
      id: "fr:j'ai allé -> je suis allé",
      language: 'fr',
      category: LearningErrorCategory.grammar,
      original: "J'ai allé",
      corrected: 'Je suis allé',
      grammarTopic: GrammarTopic.etreVsAvoir,
      firstSeenAt: _now,
      lastSeenAt: _now,
      confidence: 0.9,
    );

    Map<GrammarTopic, double> detect(
      String message, {
      Set<GrammarTopic> topics = const {},
    }) => _fr.detectGrammarSuccesses(
      messageTokens: ErrorPattern.tokensOf(message),
      knownErrors: [known()],
      errorKeysThisTurn: const {},
      errorTopicsThisTurn: topics,
    );

    test('the corrected wording after a mistake is credited, literally', () {
      expect(detect('Hier je suis allé au parc.'), {
        GrammarTopic.etreVsAvoir: 0.7,
      });
      expect(detect("Hier j'ai allé au parc"), isEmpty);
      expect(detect('Nous sommes allés au parc'), isEmpty, reason: 'literal');
      expect(
        detect('Je suis allé', topics: {GrammarTopic.etreVsAvoir}),
        isEmpty,
      );
    });

    test('articles and prompt names', () {
      for (final w in ['le', 'la', 'les', "l'", 'un', 'une', 'des', 'du']) {
        expect(_fr.isArticle(w), isTrue, reason: w);
      }
      for (final w in ['the', 'il', 'el', 'ce', 'mon']) {
        expect(_fr.isArticle(w), isFalse, reason: w);
      }
      expect(
        _fr.describeTopic(GrammarTopic.etreVsAvoir),
        'choosing être or avoir as the auxiliary verb',
      );
      expect(_fr.describeTopic(GrammarTopic.articles), 'articles');
      expect(_fr.describeTopic(GrammarTopic.essereVsAvere), 'essereVsAvere');
    });
  });

  group('three languages in one memory', () {
    late InMemoryLocalStorage storage;
    late LocalLearningRepository repo;
    late DefaultLearningEngine french;
    late DefaultLearningEngine italian;
    late DefaultLearningEngine english;

    setUp(() async {
      storage = InMemoryLocalStorage();
      repo = LocalLearningRepository(storage);
      french = DefaultLearningEngine(repo, rules: _fr, clock: () => _now);
      italian = DefaultLearningEngine(
        repo,
        rules: const ItalianLearningRules(),
        clock: () => _now,
      );
      english = DefaultLearningEngine(
        repo,
        rules: const EnglishLearningRules(),
        clock: () => _now,
      );
      for (var i = 0; i < 2; i++) {
        await french.analyze(
          userMessage: 'x',
          response: _reply([
            _fix("J'ai allé au marché", 'Je suis allé au marché'),
            _fix(
              "J'ai besoin d'un portable",
              "J'ai besoin d'un téléphone",
              category: CorrectionCategory.vocabulary,
            ),
          ]),
        );
        await italian.analyze(
          userMessage: 'x',
          response: _reply([_fix('la problema', 'il problema')]),
        );
        await english.analyze(
          userMessage: 'x',
          response: _reply([_fix('He go to work', 'He goes to work')]),
        );
      }
    });

    test('each engine only sees its own language', () async {
      final fr = _ok(await french.summary());
      final it = _ok(await italian.summary());
      final en = _ok(await english.summary());
      expect(fr.errors.every((e) => e.language == 'fr'), isTrue);
      expect(it.errors.every((e) => e.language == 'it'), isTrue);
      expect(en.errors.every((e) => e.language == 'en'), isTrue);
      expect(fr.errors.every((e) => e.id.startsWith('fr:')), isTrue);
      expect(
        fr.grammarTopics.map((t) => t.topic),
        contains(GrammarTopic.etreVsAvoir),
      );
      expect(
        it.grammarTopics.map((t) => t.topic),
        isNot(contains(GrammarTopic.etreVsAvoir)),
      );
      expect(fr.vocabularyItems.every((v) => v.language == 'fr'), isTrue);
      expect(it.vocabularyItems, isEmpty);
      // Italian ids are still the plain, legacy ones.
      expect(
        it.errors.map((e) => e.id),
        contains('la problema -> il problema'),
      );
    });

    test('the AI context carries only French', () async {
      final context = _ok(await french.learningContext());
      expect(context.priorityTopics, contains(GrammarTopic.etreVsAvoir));
      expect(
        context.recurringErrors.map((e) => e.correct).toList(),
        everyElement(isNot(contains('il problema'))),
      );
    });

    test('review: French grammar ids are scoped and independent', () async {
      final reviews = LocalReviewRepository(storage);
      DefaultReviewEngine engine(AppLanguage l) =>
          DefaultReviewEngine(repo, reviews, learningLanguage: l);
      Future<List<String>> queue(AppLanguage l) async => _ok(
        await engine(l).getReviewQueue(now: _now),
      ).map((i) => i.id).toList();

      final fr = await queue(AppLanguage.french);
      final it = await queue(AppLanguage.italian);
      final en = await queue(AppLanguage.english);
      expect(fr, contains('grammar:fr:etreVsAvoir'));
      expect(it.where((id) => id.contains('fr:')), isEmpty);
      expect(en.where((id) => id.contains('fr:')), isEmpty);
      expect(fr.toSet().intersection(it.toSet()), isEmpty);
      expect(fr.toSet().intersection(en.toSet()), isEmpty);

      _ok(
        await engine(AppLanguage.french).recordReviewResult(
          itemId: 'grammar:fr:etreVsAvoir',
          result: ReviewResult.success,
          now: _now,
        ),
      );
      expect(
        await queue(AppLanguage.french),
        isNot(contains('grammar:fr:etreVsAvoir')),
      );
      expect(await queue(AppLanguage.italian), it, reason: 'unaffected');
    });

    test('exercises for French from French data only', () async {
      final summary = _ok(await repo.getLearningSummary());
      const generator = DefaultExerciseGenerator(
        learningLanguage: AppLanguage.french,
      );
      final error = summary
          .forLanguage('fr')
          .errors
          .firstWhere((e) => e.grammarTopic == GrammarTopic.etreVsAvoir);
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
          ReviewItem.discovered(ReviewItemType.grammar, 'fr:etreVsAvoir', _now),
          summary,
        ),
      );
      expect(choice.type, ExerciseType.grammarChoice);
      expect(choice.prompt, 'etreVsAvoir');
      expect(choice.options, contains(choice.correctAnswer));

      // An Italian error never becomes a French exercise.
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

  test('the teacher prompt for French: support and learning language', () {
    final text = buildTeacherInstruction(
      profile: const UserLearningProfile(
        supportLanguage: AppLanguage.english,
        learningLanguage: AppLanguage.french,
        level: LanguageLevel.b1,
        goals: {LearningGoal.work},
        focusAreas: {LearningFocus.grammar},
      ),
      correctionMode: false,
      learningContext: const LearningContext(
        priorityTopics: [GrammarTopic.etreVsAvoir],
      ),
    );
    expect(text, contains('Support language: English'));
    expect(text, contains('Learning language: French'));
    expect(text, contains('study French'));
    expect(text, contains('use French at work'));
    expect(text, contains('- choosing être or avoir as the auxiliary verb'));
    expect(text, isNot(contains('Italian')));
    expect(text, isNot(contains('essere')));
  });

  test('the French rules name no other language', () {
    final text = File(
      'lib/features/learning/domain/french_learning_rules.dart',
    ).readAsStringSync().toLowerCase();
    expect(text, isNot(contains('italian')));
    expect(text, isNot(contains('english')));
    expect(text, isNot(contains('spanish')));
  });

  test('vocabulary of French is recorded as French', () async {
    final storage = InMemoryLocalStorage();
    final repo = LocalLearningRepository(storage);
    await DefaultLearningEngine(repo, rules: _fr, clock: () => _now).analyze(
      userMessage: 'x',
      response: _reply([
        _fix(
          'une machine à écrire',
          'un ordinateur',
          category: CorrectionCategory.vocabulary,
        ),
      ]),
    );
    final words = _ok(await repo.getLearningSummary()).vocabularyItems;
    expect(words.single.language, 'fr');
    expect(words.single.id, 'fr:ordinateur');
    expect(UserVocabulary.idFor('Ordinateur', 'fr'), 'fr:ordinateur');
  });
}
