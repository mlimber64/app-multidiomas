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
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/mandarin_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/domain/answer_evaluator.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/exercise_generator.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/in_memory_local_storage.dart';

const _zh = MandarinLearningRules();
final _now = DateTime.utc(2026, 10, 20, 12);

List<GrammarTopic>? _topics(String original, String corrected) {
  final pattern = ErrorPattern.from(original, corrected);
  return pattern == null ? null : _zh.inferGrammarTopics(pattern)?.topics;
}

T _ok<T>(Result<T> r) =>
    r.when(success: (v) => v, failure: (f) => fail('unexpected $f'));

AIResponse _reply(List<Correction> corrections) =>
    AIResponse(message: '很好！', corrections: corrections);

Correction _fix(
  String original,
  String corrected, {
  CorrectionCategory category = CorrectionCategory.grammar,
}) => Correction(
  original: original,
  corrected: corrected,
  explanation: '因为。',
  category: category,
);

void main() {
  group('reading Chinese: one character per word', () {
    test('Han characters are words of their own; the rest keeps its runs', () {
      expect(ErrorPattern.tokensOf('我喜欢咖啡。'), ['我', '喜', '欢', '咖', '啡']);
      expect(ErrorPattern.tokensOf('我有 iPhone，很好'), [
        '我',
        '有',
        'iphone',
        '很',
        '好',
      ]);
      expect(ErrorPattern.tokensOf('你好吗？'), ['你', '好', '吗']);
      expect(ErrorPattern.tokensOf('nǐ hǎo ma'), ['nǐ', 'hǎo', 'ma']);
    });

    test('other scripts read exactly as before', () {
      expect(ErrorPattern.tokensOf('Ieri ho andato al lavoro.'), [
        'ieri',
        'ho',
        'andato',
        'al',
        'lavoro',
      ]);
      expect(ErrorPattern.joinTokens(['ho', 'andato']), 'ho andato');
    });

    test('tokens are written back without spaces between Han characters', () {
      expect(ErrorPattern.joinTokens(['我', '喜', '欢']), '我喜欢');
      expect(ErrorPattern.joinTokens(['我', 'iphone', '很']), '我 iphone 很');
      expect(ErrorPattern.isHan('我'), isTrue);
      expect(ErrorPattern.isHan('a'), isFalse);
      expect(ErrorPattern.isHan('我们'), isFalse);
    });

    test('a pattern is the few characters that changed, shown as text', () {
      final p = ErrorPattern.from('我不有书', '我没有书')!;
      expect(p.coreOriginalTokens, ['不']);
      expect(p.coreCorrectedTokens, ['没']);
      expect(p.original, isNot(contains(' ')));
      expect(p.corrected, isNot(contains(' ')));
      expect(p.key, '不有 -> 没有');
      // The same mistake in another sentence is the same pattern.
      expect(ErrorPattern.from('他不有钱', '他没有钱')!.key, p.key);
    });
  });

  group('capabilities', () {
    test('Mandarin is a supported learning language, not an interface one', () {
      expect(AppLanguage.mandarin.code, 'zh');
      expect(AppLanguage.mandarin.englishName, 'Mandarin Chinese');
      expect(supportedLearningLanguages, contains(AppLanguage.mandarin));
      expect(availableSupportLanguages, isNot(contains(AppLanguage.mandarin)));
      expect(
        learningRulesFor(AppLanguage.mandarin)?.language,
        AppLanguage.mandarin,
      );
      for (final support in availableSupportLanguages) {
        expect(
          LanguagePair(
            support: support,
            learning: AppLanguage.mandarin,
          ).isSupported,
          isTrue,
          reason: support.name,
        );
      }
    });

    test('Chinese has no articles and names how it is to be taught', () {
      expect(_zh.isArticle('的'), isFalse);
      expect(_zh.isArticle('the'), isFalse);
      expect(_zh.teachingNote, contains('simplified'));
      expect(_zh.teachingNote, contains('pinyin'));
      // Only Chinese and Quechua ask for a note so far.
      for (final l in AppLanguage.values) {
        if (l == AppLanguage.mandarin || l == AppLanguage.quechua) continue;
        expect(learningRulesFor(l)?.teachingNote, isNull, reason: l.name);
      }
    });
  });

  group('MandarinLearningRules: topic inference', () {
    test('the precise cases it knows', () {
      expect(_topics('我不有书', '我没有书'), [GrammarTopic.negation]);
      expect(_topics('我没喜欢咖啡', '我不喜欢咖啡'), [GrammarTopic.negation]);
      expect(_topics('他跑的很快', '他跑得很快'), [GrammarTopic.structuralParticles]);
      expect(_topics('她高兴得说', '她高兴地说'), [GrammarTopic.structuralParticles]);
      expect(_topics('我有三书', '我有三本书'), [GrammarTopic.measureWords]);
      expect(_topics('我买了一个书', '我买了一本书'), [GrammarTopic.measureWords]);
      expect(_topics('我吃饭', '我吃饭了'), [GrammarTopic.aspectParticles]);
      expect(_topics('我去过中国', '我去了中国'), [GrammarTopic.aspectParticles]);
      expect(_topics('我昨天去商店', '昨天我去商店'), [GrammarTopic.wordOrder]);
    });

    test('no evidence, no topic', () {
      expect(_topics('你好', '您好'), isNull);
      expect(_topics('我喜欢咖啡', '我喜欢茶'), isNull);
      // A measure word with no number or 这/那 before it is not safe.
      expect(_topics('我有书', '我有本书'), isNull);
      expect(_topics('我是学生', '我是老师'), isNull);
      expect(_topics('同样的', '同样的'), isNull);
    });

    test('never produces a topic that belongs to another language', () {
      const other = {
        GrammarTopic.articles,
        GrammarTopic.plural,
        GrammarTopic.verbConjugation,
        GrammarTopic.essereVsAvere,
        GrammarTopic.serVsEstar,
        GrammarTopic.cases,
      };
      for (final pair in [
        ('我不有书', '我没有书'),
        ('我有三书', '我有三本书'),
        ('我吃饭', '我吃饭了'),
      ]) {
        expect(
          (_topics(pair.$1, pair.$2) ?? const []).toSet().intersection(other),
          isEmpty,
          reason: pair.toString(),
        );
      }
    });
  });

  group('MandarinLearningRules: success and labels', () {
    LearningError known() => LearningError(
      id: 'zh:不有 -> 没有',
      language: 'zh',
      category: LearningErrorCategory.grammar,
      original: '不有',
      corrected: '没有',
      grammarTopic: GrammarTopic.negation,
      firstSeenAt: _now,
      lastSeenAt: _now,
      confidence: 0.9,
    );

    Map<GrammarTopic, double> detect(String message) =>
        _zh.detectGrammarSuccesses(
          messageTokens: ErrorPattern.tokensOf(message),
          knownErrors: [known()],
          errorKeysThisTurn: const {},
          errorTopicsThisTurn: const {},
        );

    test('the corrected wording after a mistake is credited, literally', () {
      expect(detect('我今天没有时间。'), {GrammarTopic.negation: 0.7});
      expect(detect('我不有时间'), isEmpty);
      expect(detect('我不喜欢'), isEmpty);
    });

    test('prompt names', () {
      expect(
        _zh.describeTopic(GrammarTopic.measureWords),
        'measure words (量词)',
      );
      expect(_zh.describeTopic(GrammarTopic.negation), 'negation with 不 and 没');
      expect(_zh.describeTopic(GrammarTopic.cases), 'cases');
    });
  });

  group('Mandarin in the shared memory', () {
    late InMemoryLocalStorage storage;
    late LocalLearningRepository repo;
    late DefaultLearningEngine mandarin;

    setUp(() async {
      storage = InMemoryLocalStorage();
      repo = LocalLearningRepository(storage);
      mandarin = DefaultLearningEngine(repo, rules: _zh, clock: () => _now);
      final italian = DefaultLearningEngine(
        repo,
        rules: const ItalianLearningRules(),
        clock: () => _now,
      );
      for (var i = 0; i < 2; i++) {
        await mandarin.analyze(
          userMessage: '我不有书',
          response: _reply([
            _fix('我不有书', '我没有书'),
            _fix('我用打字机', '我用电脑', category: CorrectionCategory.vocabulary),
          ]),
        );
        await italian.analyze(
          userMessage: 'x',
          response: _reply([_fix('la problema', 'il problema')]),
        );
      }
    });

    test(
      'Chinese mistakes are recorded as zh, as text without spaces',
      () async {
        final zh = _ok(await mandarin.summary());
        expect(zh.errors.every((e) => e.language == 'zh'), isTrue);
        expect(zh.errors.every((e) => e.id.startsWith('zh:')), isTrue);
        final negation = zh.errors.firstWhere(
          (e) => e.grammarTopic == GrammarTopic.negation,
        );
        expect(negation.original, '不有');
        expect(negation.corrected, '没有');
        expect(negation.frequency, 2, reason: 'the same mistake, seen twice');
        expect(
          zh.grammarTopics.map((t) => t.topic),
          contains(GrammarTopic.negation),
        );
      },
    );

    test('a Chinese word is a few characters, not a letter count', () async {
      final zh = _ok(await mandarin.summary());
      final word = zh.vocabularyItems.single;
      expect(word.word, '电脑');
      expect(word.id, 'zh:电脑');
      expect(word.language, 'zh');
    });

    test('a correct use of the word is detected in running text', () async {
      await mandarin.analyze(
        userMessage: '我每天用电脑工作',
        response: _reply(const []),
      );
      final word = _ok(await mandarin.summary()).vocabularyItems.single;
      expect(word.successfulUseCount, 1);
    });

    test('the AI context carries only Chinese', () async {
      final context = _ok(await mandarin.learningContext());
      expect(context.priorityTopics, contains(GrammarTopic.negation));
      for (final e in context.recurringErrors) {
        expect(e.correct, isNot(contains('il problema')));
      }
    });

    test('review: Chinese ids are scoped and independent of Italian', () async {
      final reviews = LocalReviewRepository(storage);
      DefaultReviewEngine engine(AppLanguage l) =>
          DefaultReviewEngine(repo, reviews, learningLanguage: l);
      Future<List<String>> queue(AppLanguage l) async => _ok(
        await engine(l).getReviewQueue(now: _now),
      ).map((i) => i.id).toList();

      final zh = await queue(AppLanguage.mandarin);
      final it = await queue(AppLanguage.italian);
      expect(zh, contains('grammar:zh:negation'));
      expect(zh, contains('vocabulary:zh:电脑'));
      expect(it.where((id) => id.contains('zh:')), isEmpty);
      expect(zh.toSet().intersection(it.toSet()), isEmpty);
    });

    test('exercises for Chinese: texts without spaces', () async {
      final summary = _ok(await repo.getLearningSummary());
      const generator = DefaultExerciseGenerator(
        learningLanguage: AppLanguage.mandarin,
      );
      final error = summary
          .forLanguage('zh')
          .errors
          .firstWhere((e) => e.grammarTopic == GrammarTopic.negation);
      final correction = _ok(
        generator.generate(
          ReviewItem.discovered(ReviewItemType.error, error.id, _now),
          summary,
        ),
      );
      expect(correction.type, ExerciseType.errorCorrection);
      expect(correction.prompt, '不有');
      expect(correction.correctAnswer, '没有');
      expect(AnswerEvaluator.isCorrect(correction, '没有'), isTrue);
      expect(AnswerEvaluator.isCorrect(correction, '不有'), isFalse);

      final choice = _ok(
        generator.generate(
          ReviewItem.discovered(ReviewItemType.grammar, 'zh:negation', _now),
          summary,
        ),
      );
      expect(choice.type, ExerciseType.grammarChoice);
      expect(choice.prompt, 'negation');
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

    test('a cloze for a Chinese word keeps the text without spaces', () {
      final word = UserVocabulary.of(word: '电脑', at: _now, language: 'zh');
      final fix = LearningError(
        id: 'zh:我用打字机 -> 我用电脑',
        language: 'zh',
        category: LearningErrorCategory.vocabulary,
        original: '我用打字机',
        corrected: '我用电脑',
        firstSeenAt: _now,
        lastSeenAt: _now,
        confidence: 0.9,
        frequency: 2,
      );
      const generator = DefaultExerciseGenerator(
        learningLanguage: AppLanguage.mandarin,
      );
      final ex = _ok(
        generator.generate(
          ReviewItem.discovered(ReviewItemType.vocabulary, word.id, _now),
          LearnerLearningSummary(errors: [fix], vocabularyItems: [word]),
        ),
      );
      expect(ex.type, ExerciseType.vocabularyContext);
      expect(ex.prompt, '我用${Exercise.blank}');
      expect(ex.correctAnswer, '电脑');
    });
  });

  test(
    'the teacher prompt for Mandarin: language names and the writing note',
    () {
      final text = buildTeacherInstruction(
        profile: const UserLearningProfile(
          learningLanguage: AppLanguage.mandarin,
          level: LanguageLevel.a1,
          goals: {LearningGoal.work},
          focusAreas: {LearningFocus.conversation},
        ),
        correctionMode: false,
        learningContext: const LearningContext(
          priorityTopics: [GrammarTopic.measureWords],
        ),
      );
      expect(text, contains('Support language: Spanish'));
      expect(text, contains('Learning language: Mandarin Chinese'));
      expect(text, contains('study Mandarin Chinese'));
      expect(text, contains('simplified characters'));
      expect(text, contains('pinyin'));
      expect(text, contains('- measure words (量词)'));
      // Other languages get no such note.
      final italian = buildTeacherInstruction(
        profile: UserLearningProfile.empty,
        correctionMode: false,
      );
      expect(italian, isNot(contains('pinyin')));
    },
  );

  test('the Mandarin rules name no other language', () {
    final text = File(
      'lib/features/learning/domain/mandarin_learning_rules.dart',
    ).readAsStringSync().toLowerCase();
    for (final other in [
      'italian',
      'english',
      'french',
      'portuguese',
      'german',
      'spanish',
    ]) {
      expect(text, isNot(contains(other)), reason: other);
    }
  });
}
