import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/default_learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/error_pattern.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/italian_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/language_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/portuguese_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/spanish_learning_rules.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/exercise_generator.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/in_memory_local_storage.dart';

const _es = SpanishLearningRules();
final _now = DateTime.utc(2026, 10, 20, 12);

List<GrammarTopic>? _topics(String original, String corrected) {
  final pattern = ErrorPattern.from(original, corrected);
  return pattern == null ? null : _es.inferGrammarTopics(pattern)?.topics;
}

T _ok<T>(Result<T> r) =>
    r.when(success: (v) => v, failure: (f) => fail('unexpected $f'));

AIResponse _reply(List<Correction> corrections) =>
    AIResponse(message: '¡Muy bien!', corrections: corrections);

Correction _fix(
  String original,
  String corrected, {
  CorrectionCategory category = CorrectionCategory.grammar,
}) => Correction(
  original: original,
  corrected: corrected,
  explanation: 'Porque sí.',
  category: category,
);

void main() {
  group('capabilities: Spanish is both a support and a learning language', () {
    test('it has rules and is offered to learn', () {
      expect(supportedLearningLanguages, contains(AppLanguage.spanish));
      expect(availableSupportLanguages, contains(AppLanguage.spanish));
      expect(
        learningRulesFor(AppLanguage.spanish)?.language,
        AppLanguage.spanish,
      );
    });

    test('pairs: English or Italian -> Spanish, never Spanish -> Spanish', () {
      for (final support in [AppLanguage.english, AppLanguage.italian]) {
        expect(
          LanguagePair(
            support: support,
            learning: AppLanguage.spanish,
          ).isSupported,
          isTrue,
          reason: support.name,
        );
      }
      expect(
        const LanguagePair(
          support: AppLanguage.spanish,
          learning: AppLanguage.spanish,
        ).isSupported,
        isFalse,
      );
      // The earlier pairs are unchanged.
      expect(
        const LanguagePair(
          support: AppLanguage.spanish,
          learning: AppLanguage.italian,
        ).isSupported,
        isTrue,
      );
    });

    test('a language is never learned through itself, whatever is stored', () {
      expect(
        defaultLearningLanguageFor(AppLanguage.spanish),
        AppLanguage.italian,
      );
      expect(
        defaultLearningLanguageFor(AppLanguage.italian),
        AppLanguage.english,
      );
    });
  });

  group('punctuation of Spanish', () {
    test('opening ¿ and ¡ are not part of the word', () {
      expect(ErrorPattern.tokensOf('¿Cómo estás? ¡Bien!'), [
        'cómo',
        'estás',
        'bien',
      ]);
    });
  });

  group('SpanishLearningRules: topic inference', () {
    test('the precise cases it knows', () {
      expect(_topics('Yo soy cansado', 'Yo estoy cansado'), [
        GrammarTopic.serVsEstar,
      ]);
      expect(_topics('Ella está médica', 'Ella es médica'), [
        GrammarTopic.serVsEstar,
      ]);
      expect(_topics('Estudio por aprender', 'Estudio para aprender'), [
        GrammarTopic.porVsPara,
      ]);
      expect(_topics('Gracias para todo', 'Gracias por todo'), [
        GrammarTopic.porVsPara,
      ]);
      expect(_topics('Voy a el mercado', 'Voy al mercado'), [
        GrammarTopic.prepositions,
      ]);
      expect(_topics('La casa de el vecino', 'La casa del vecino'), [
        GrammarTopic.prepositions,
      ]);
      expect(_topics('Leo los libro', 'Leo los libros'), [GrammarTopic.plural]);
      expect(_topics('Veo las ciudad', 'Veo las ciudades'), [
        GrammarTopic.plural,
      ]);
      expect(_topics('Tengo unos lápiz', 'Tengo unos lápices'), [
        GrammarTopic.plural,
      ]);
      expect(_topics('Nosotros hablo español', 'Nosotros hablamos español'), [
        GrammarTopic.verbConjugation,
      ]);
      expect(_topics('El casa es bonita', 'La casa es bonita'), [
        GrammarTopic.articles,
      ]);
      expect(_topics('Tengo perro', 'Tengo un perro'), [GrammarTopic.articles]);
      expect(_topics('Vivo a Madrid', 'Vivo en Madrid'), [
        GrammarTopic.prepositions,
      ]);
      expect(_topics('siempre yo voy', 'yo voy siempre'), [
        GrammarTopic.wordOrder,
      ]);
    });

    test('no evidence, no topic', () {
      expect(_topics('Hola', 'Buenas'), isNull);
      expect(_topics('Me gusta', 'Me encanta'), isNull);
      // por/para added or dropped is not a swap
      expect(_topics('Voy ir', 'Voy por ir'), isNull);
      // the personal "a" comes and goes: not safely a preposition issue
      expect(_topics('Veo Juan', 'Veo a Juan'), isNull);
      // no plural determiner right before
      expect(_topics('Tengo libro', 'Tengo libros'), isNull);
      expect(_topics('Mismo texto', 'mismo texto'), isNull);
    });

    test('never produces a topic that belongs to another language', () {
      const other = {
        GrammarTopic.essereVsAvere,
        GrammarTopic.etreVsAvoir,
        GrammarTopic.habenVsSein,
        GrammarTopic.cases,
        GrammarTopic.toBe,
        GrammarTopic.pastSimple,
        GrammarTopic.passeCompose,
      };
      for (final pair in [
        ('Yo soy cansado', 'Yo estoy cansado'),
        ('los libro', 'los libros'),
        ('a el mercado', 'al mercado'),
      ]) {
        expect(
          (_topics(pair.$1, pair.$2) ?? const []).toSet().intersection(other),
          isEmpty,
          reason: pair.toString(),
        );
      }
    });
  });

  group('SpanishLearningRules: success, articles, labels', () {
    LearningError known() => LearningError(
      id: 'es:soy cansado -> estoy cansado',
      language: 'es',
      category: LearningErrorCategory.grammar,
      original: 'soy cansado',
      corrected: 'estoy cansado',
      grammarTopic: GrammarTopic.serVsEstar,
      firstSeenAt: _now,
      lastSeenAt: _now,
      confidence: 0.9,
    );

    Map<GrammarTopic, double> detect(String message) =>
        _es.detectGrammarSuccesses(
          messageTokens: ErrorPattern.tokensOf(message),
          knownErrors: [known()],
          errorKeysThisTurn: const {},
          errorTopicsThisTurn: const {},
        );

    test('the corrected wording after a mistake is credited, literally', () {
      expect(detect('Hoy estoy cansado de verdad.'), {
        GrammarTopic.serVsEstar: 0.7,
      });
      expect(detect('Yo soy cansado'), isEmpty);
    });

    test('articles and prompt names', () {
      for (final w in ['el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas']) {
        expect(_es.isArticle(w), isTrue, reason: w);
      }
      for (final w in ['the', 'le', 'il', 'o', 'der', 'mi']) {
        expect(_es.isArticle(w), isFalse, reason: w);
      }
      expect(_es.describeTopic(GrammarTopic.porVsPara), 'choosing por or para');
      expect(
        _es.describeTopic(GrammarTopic.serVsEstar),
        'choosing ser or estar',
      );
      expect(_es.describeTopic(GrammarTopic.habenVsSein), 'habenVsSein');
    });
  });

  group('Spanish learned next to other languages', () {
    late InMemoryLocalStorage storage;
    late LocalLearningRepository repo;
    late DefaultLearningEngine spanish;

    setUp(() async {
      storage = InMemoryLocalStorage();
      repo = LocalLearningRepository(storage);
      spanish = DefaultLearningEngine(repo, rules: _es, clock: () => _now);
      final portuguese = DefaultLearningEngine(
        repo,
        rules: const PortugueseLearningRules(),
        clock: () => _now,
      );
      final italian = DefaultLearningEngine(
        repo,
        rules: const ItalianLearningRules(),
        clock: () => _now,
      );
      for (var i = 0; i < 2; i++) {
        await spanish.analyze(
          userMessage: 'x',
          response: _reply([
            _fix('Yo soy cansado', 'Yo estoy cansado'),
            _fix(
              'Necesito un celular',
              'Necesito un móvil',
              category: CorrectionCategory.vocabulary,
            ),
          ]),
        );
        // Portuguese has the same ser/estar topic and similar words.
        await portuguese.analyze(
          userMessage: 'x',
          response: _reply([_fix('Eu sou cansado', 'Eu estou cansado')]),
        );
        await italian.analyze(
          userMessage: 'x',
          response: _reply([_fix('la problema', 'il problema')]),
        );
      }
    });

    test('Spanish is recorded and scoped as es', () async {
      final es = _ok(await spanish.summary());
      expect(es.errors.every((e) => e.language == 'es'), isTrue);
      expect(es.errors.every((e) => e.id.startsWith('es:')), isTrue);
      expect(es.grammarTopics.map((t) => t.topic), [GrammarTopic.serVsEstar]);
      expect(es.vocabularyItems.single.id, 'es:móvil');
      // The same topic in Portuguese is another progress record.
      final all = _ok(await repo.getLearningSummary());
      expect(
        all.grammarTopics
            .where((t) => t.topic == GrammarTopic.serVsEstar)
            .map((t) => t.language)
            .toSet(),
        {'es', 'pt'},
      );
    });

    test('the AI context carries only Spanish', () async {
      final context = _ok(await spanish.learningContext());
      expect(context.priorityTopics, [GrammarTopic.serVsEstar]);
      for (final e in context.recurringErrors) {
        expect(e.incorrect, isNot(contains('Eu ')));
        expect(e.correct, isNot(contains('il problema')));
      }
    });

    test('review: Spanish ids are scoped and independent', () async {
      final reviews = LocalReviewRepository(storage);
      DefaultReviewEngine engine(AppLanguage l) =>
          DefaultReviewEngine(repo, reviews, learningLanguage: l);
      Future<List<String>> queue(AppLanguage l) async => _ok(
        await engine(l).getReviewQueue(now: _now),
      ).map((i) => i.id).toList();

      final es = await queue(AppLanguage.spanish);
      final pt = await queue(AppLanguage.portuguese);
      expect(es, contains('grammar:es:serVsEstar'));
      expect(pt, contains('grammar:pt:serVsEstar'));
      expect(es.toSet().intersection(pt.toSet()), isEmpty);

      _ok(
        await engine(AppLanguage.spanish).recordReviewResult(
          itemId: 'grammar:es:serVsEstar',
          result: ReviewResult.success,
          now: _now,
        ),
      );
      expect(await queue(AppLanguage.portuguese), pt, reason: 'unaffected');
    });

    test('exercises for Spanish from Spanish data only', () async {
      final summary = _ok(await repo.getLearningSummary());
      const generator = DefaultExerciseGenerator(
        learningLanguage: AppLanguage.spanish,
      );
      final error = summary
          .forLanguage('es')
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
          ReviewItem.discovered(ReviewItemType.grammar, 'es:serVsEstar', _now),
          summary,
        ),
      );
      expect(choice.type, ExerciseType.grammarChoice);
      expect(choice.prompt, 'serVsEstar');
      expect(choice.options, contains(choice.correctAnswer));

      // A Portuguese error never becomes a Spanish exercise.
      expect(
        generator.generate(
          ReviewItem.discovered(
            ReviewItemType.error,
            'pt:eu sou cansado -> eu estou cansado',
            _now,
          ),
          summary,
        ),
        isA<Failure<Exercise>>(),
      );
    });
  });

  test('the teacher prompt for Spanish: support English, learning Spanish', () {
    final text = buildTeacherInstruction(
      profile: const UserLearningProfile(
        supportLanguage: AppLanguage.english,
        learningLanguage: AppLanguage.spanish,
        level: LanguageLevel.a2,
        goals: {LearningGoal.work},
        focusAreas: {LearningFocus.grammar},
      ),
      correctionMode: false,
      learningContext: const LearningContext(
        priorityTopics: [GrammarTopic.porVsPara],
      ),
    );
    expect(text, contains('Support language: English'));
    expect(text, contains('Learning language: Spanish'));
    expect(text, contains('study Spanish'));
    expect(
      text,
      contains(
        'The learner\'s support language, the one they already understand, is English',
      ),
    );
    expect(text, contains('- choosing por or para'));
    expect(text, isNot(contains('essere')));
  });

  test('the Spanish rules name no other language', () {
    final text = File(
      'lib/features/learning/domain/spanish_learning_rules.dart',
    ).readAsStringSync().toLowerCase();
    for (final other in [
      'italian',
      'english',
      'french',
      'portuguese',
      'german',
    ]) {
      expect(text, isNot(contains(other)), reason: other);
    }
  });
}
