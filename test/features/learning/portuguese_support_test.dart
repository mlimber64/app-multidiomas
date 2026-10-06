import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/default_learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/error_pattern.dart';
import 'package:parla_con_me/features/learning/domain/french_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/italian_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/language_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/portuguese_learning_rules.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/exercise_generator.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/in_memory_local_storage.dart';

const _pt = PortugueseLearningRules();
final _now = DateTime.utc(2026, 10, 20, 12);

List<GrammarTopic>? _topics(String original, String corrected) {
  final pattern = ErrorPattern.from(original, corrected);
  return pattern == null ? null : _pt.inferGrammarTopics(pattern)?.topics;
}

T _ok<T>(Result<T> r) =>
    r.when(success: (v) => v, failure: (f) => fail('unexpected $f'));

AIResponse _reply(List<Correction> corrections) =>
    AIResponse(message: 'Muito bem!', corrections: corrections);

Correction _fix(
  String original,
  String corrected, {
  CorrectionCategory category = CorrectionCategory.grammar,
}) => Correction(
  original: original,
  corrected: corrected,
  explanation: 'Porque sim.',
  category: category,
);

void main() {
  group('capabilities', () {
    test(
      'Portuguese is a supported learning language, not an interface one',
      () {
        expect(AppLanguage.portuguese.code, 'pt');
        expect(AppLanguage.portuguese.englishName, 'Portuguese');
        expect(supportedLearningLanguages, contains(AppLanguage.portuguese));
        expect(
          availableSupportLanguages,
          isNot(contains(AppLanguage.portuguese)),
        );
        expect(
          learningRulesFor(AppLanguage.portuguese)?.language,
          AppLanguage.portuguese,
        );
        for (final support in availableSupportLanguages) {
          expect(
            LanguagePair(
              support: support,
              learning: AppLanguage.portuguese,
            ).isSupported,
            isTrue,
            reason: support.name,
          );
        }
      },
    );

    test('every supported learning language has rules, and only those', () {
      for (final l in AppLanguage.values) {
        expect(
          learningRulesFor(l) != null,
          supportedLearningLanguages.contains(l),
          reason: l.name,
        );
      }
    });
  });

  group('PortugueseLearningRules: topic inference', () {
    test('the precise cases it knows', () {
      expect(_topics('Eu sou cansado', 'Eu estou cansado'), [
        GrammarTopic.serVsEstar,
      ]);
      expect(_topics('Ela está brasileira', 'Ela é brasileira'), [
        GrammarTopic.serVsEstar,
      ]);
      expect(_topics('Moro em o centro', 'Moro no centro'), [
        GrammarTopic.prepositions,
      ]);
      expect(_topics('A casa de a Maria', 'A casa da Maria'), [
        GrammarTopic.prepositions,
      ]);
      expect(_topics('Leio os livro', 'Leio os livros'), [GrammarTopic.plural]);
      expect(_topics('Vejo os homem', 'Vejo os homens'), [GrammarTopic.plural]);
      expect(
        _topics('Tenho dois animal', 'Tenho dois animais'),
        isNull,
        reason: 'no plural determiner right before',
      );
      expect(_topics('Compro as animal', 'Compro as animais'), [
        GrammarTopic.plural,
      ]);
      expect(_topics('As coração', 'As corações'), [GrammarTopic.plural]);
      expect(_topics('Eu falamos aqui', 'Eu falo aqui'), [
        GrammarTopic.verbConjugation,
      ]);
      expect(_topics('Nós falamo aqui', 'Nós falamos aqui'), [
        GrammarTopic.verbConjugation,
      ]);
      expect(_topics('O casa é bonita', 'A casa é bonita'), [
        GrammarTopic.articles,
      ]);
      expect(_topics('Tenho carro', 'Tenho um carro'), [GrammarTopic.articles]);
      expect(_topics('Vou em Lisboa', 'Vou para Lisboa'), [
        GrammarTopic.prepositions,
      ]);
      expect(_topics('sempre eu vou', 'eu vou sempre'), [
        GrammarTopic.wordOrder,
      ]);
    });

    test('no evidence, no topic', () {
      expect(_topics('Olá', 'Oi'), isNull);
      expect(_topics('Eu gosto', 'Eu adoro'), isNull);
      // ser <-> ser is not a ser/estar choice
      expect(_topics('Eu sou', 'Tu és'), isNull);
      expect(
        _topics('Quero ir', 'Quero a ir'),
        isNull,
        reason: 'a preposition only added',
      );
      expect(_topics('Mesmo texto', 'mesmo texto'), isNull);
    });

    test('never produces a topic that belongs to another language', () {
      const other = {
        GrammarTopic.essereVsAvere,
        GrammarTopic.etreVsAvoir,
        GrammarTopic.passatoProssimo,
        GrammarTopic.passeCompose,
        GrammarTopic.toBe,
        GrammarTopic.pastSimple,
        GrammarTopic.thirdPersonSingular,
      };
      for (final pair in [
        ('Eu sou cansado', 'Eu estou cansado'),
        ('os livro', 'os livros'),
        ('em o centro', 'no centro'),
      ]) {
        expect(
          (_topics(pair.$1, pair.$2) ?? const []).toSet().intersection(other),
          isEmpty,
          reason: pair.toString(),
        );
      }
    });
  });

  group('PortugueseLearningRules: success, articles, labels', () {
    LearningError known() => LearningError(
      id: 'pt:eu sou cansado -> eu estou cansado',
      language: 'pt',
      category: LearningErrorCategory.grammar,
      original: 'Eu sou cansado',
      corrected: 'Eu estou cansado',
      grammarTopic: GrammarTopic.serVsEstar,
      firstSeenAt: _now,
      lastSeenAt: _now,
      confidence: 0.9,
    );

    Map<GrammarTopic, double> detect(String message) =>
        _pt.detectGrammarSuccesses(
          messageTokens: ErrorPattern.tokensOf(message),
          knownErrors: [known()],
          errorKeysThisTurn: const {},
          errorTopicsThisTurn: const {},
        );

    test('the corrected wording after a mistake is credited, literally', () {
      expect(detect('Hoje eu estou cansado de verdade'), {
        GrammarTopic.serVsEstar: 0.7,
      });
      expect(detect('Eu sou cansado'), isEmpty);
    });

    test('articles and prompt names', () {
      for (final w in ['o', 'a', 'os', 'as', 'um', 'uma', 'uns', 'umas']) {
        expect(_pt.isArticle(w), isTrue, reason: w);
      }
      for (final w in ['the', 'el', 'le', 'il', 'meu', 'de']) {
        expect(_pt.isArticle(w), isFalse, reason: w);
      }
      expect(
        _pt.describeTopic(GrammarTopic.serVsEstar),
        'choosing ser or estar',
      );
      expect(_pt.describeTopic(GrammarTopic.etreVsAvoir), 'etreVsAvoir');
    });
  });

  group('four languages in one memory', () {
    late InMemoryLocalStorage storage;
    late LocalLearningRepository repo;
    late DefaultLearningEngine portuguese;

    setUp(() async {
      storage = InMemoryLocalStorage();
      repo = LocalLearningRepository(storage);
      portuguese = DefaultLearningEngine(repo, rules: _pt, clock: () => _now);
      final italian = DefaultLearningEngine(
        repo,
        rules: const ItalianLearningRules(),
        clock: () => _now,
      );
      final french = DefaultLearningEngine(
        repo,
        rules: const FrenchLearningRules(),
        clock: () => _now,
      );
      for (var i = 0; i < 2; i++) {
        await portuguese.analyze(
          userMessage: 'x',
          response: _reply([
            _fix('Eu sou cansado', 'Eu estou cansado'),
            _fix(
              'Eu preciso de um celular',
              'Eu preciso de um telemóvel',
              category: CorrectionCategory.vocabulary,
            ),
          ]),
        );
        await italian.analyze(
          userMessage: 'x',
          response: _reply([_fix('la problema', 'il problema')]),
        );
        await french.analyze(
          userMessage: 'x',
          response: _reply([_fix('le maison', 'la maison')]),
        );
      }
    });

    test('Portuguese is recorded and scoped as pt', () async {
      final pt = _ok(await portuguese.summary());
      expect(pt.errors.every((e) => e.language == 'pt'), isTrue);
      expect(pt.errors.every((e) => e.id.startsWith('pt:')), isTrue);
      expect(
        pt.grammarTopics.map((t) => t.topic),
        contains(GrammarTopic.serVsEstar),
      );
      expect(pt.vocabularyItems.single.id, 'pt:telemóvel');
      // Others untouched: Italian ids stay plain.
      final all = _ok(await repo.getLearningSummary());
      expect(all.errors.map((e) => e.language).toSet(), {'it', 'fr', 'pt'});
      expect(
        all.forLanguage('it').errors.map((e) => e.id),
        contains('la problema -> il problema'),
      );
    });

    test('the AI context carries only Portuguese', () async {
      final context = _ok(await portuguese.learningContext());
      expect(context.priorityTopics, contains(GrammarTopic.serVsEstar));
      for (final e in context.recurringErrors) {
        expect(e.correct, isNot(contains('il problema')));
        expect(e.correct, isNot(contains('la maison')));
      }
    });

    test(
      'review: Portuguese ids are scoped, independent of Italian/French',
      () async {
        final reviews = LocalReviewRepository(storage);
        DefaultReviewEngine engine(AppLanguage l) =>
            DefaultReviewEngine(repo, reviews, learningLanguage: l);
        Future<List<String>> queue(AppLanguage l) async => _ok(
          await engine(l).getReviewQueue(now: _now),
        ).map((i) => i.id).toList();

        final pt = await queue(AppLanguage.portuguese);
        final it = await queue(AppLanguage.italian);
        final fr = await queue(AppLanguage.french);
        expect(pt, contains('grammar:pt:serVsEstar'));
        expect(it.where((id) => id.contains('pt:')), isEmpty);
        expect(fr.where((id) => id.contains('pt:')), isEmpty);
        expect(pt.toSet().intersection(it.toSet()), isEmpty);
        expect(pt.toSet().intersection(fr.toSet()), isEmpty);
      },
    );

    test('exercises for Portuguese from Portuguese data only', () async {
      final summary = _ok(await repo.getLearningSummary());
      const generator = DefaultExerciseGenerator(
        learningLanguage: AppLanguage.portuguese,
      );
      final error = summary
          .forLanguage('pt')
          .errors
          .firstWhere((e) => e.grammarTopic == GrammarTopic.serVsEstar);
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
          ReviewItem.discovered(ReviewItemType.grammar, 'pt:serVsEstar', _now),
          summary,
        ),
      );
      expect(choice.type, ExerciseType.grammarChoice);
      expect(choice.prompt, 'serVsEstar');
      expect(choice.options, contains(choice.correctAnswer));

      // A French error never becomes a Portuguese exercise.
      expect(
        generator.generate(
          ReviewItem.discovered(
            ReviewItemType.error,
            'fr:le maison -> la maison',
            _now,
          ),
          summary,
        ),
        isA<Failure<Exercise>>(),
      );
    });
  });

  test('the teacher prompt for Portuguese: support and learning language', () {
    final text = buildTeacherInstruction(
      profile: const UserLearningProfile(
        supportLanguage: AppLanguage.italian,
        learningLanguage: AppLanguage.portuguese,
        level: LanguageLevel.a2,
        goals: {LearningGoal.liveAbroad},
        focusAreas: {LearningFocus.conversation},
      ),
      correctionMode: false,
      learningContext: const LearningContext(
        priorityTopics: [GrammarTopic.serVsEstar],
      ),
    );
    expect(text, contains('Support language: Italian'));
    expect(text, contains('Learning language: Portuguese'));
    expect(text, contains('study Portuguese'));
    expect(text, contains('live abroad where Portuguese is spoken'));
    expect(text, contains('- choosing ser or estar'));
    expect(text, isNot(contains('essere')));
  });

  test('the Portuguese rules name no other language', () {
    final text = File(
      'lib/features/learning/domain/portuguese_learning_rules.dart',
    ).readAsStringSync().toLowerCase();
    for (final other in ['italian', 'english', 'french', 'spanish']) {
      expect(text, isNot(contains(other)), reason: other);
    }
  });
}
