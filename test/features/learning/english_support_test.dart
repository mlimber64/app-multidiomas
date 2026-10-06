import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/default_learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/english_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/error_pattern.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/italian_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/language_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/profile/data/local_user_learning_profile_repository.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/exercise_generator.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/in_memory_local_storage.dart';

const _en = EnglishLearningRules();
final _now = DateTime.utc(2026, 10, 20, 12);

List<GrammarTopic>? _topics(String original, String corrected) {
  final pattern = ErrorPattern.from(original, corrected);
  return pattern == null ? null : _en.inferGrammarTopics(pattern)?.topics;
}

T _ok<T>(Result<T> r) =>
    r.when(success: (v) => v, failure: (f) => fail('unexpected $f'));

AIResponse _reply(List<Correction> corrections) =>
    AIResponse(message: 'Nice!', corrections: corrections);

Correction _fix(
  String original,
  String corrected, {
  CorrectionCategory category = CorrectionCategory.grammar,
}) => Correction(
  original: original,
  corrected: corrected,
  explanation: 'Because.',
  category: category,
);

void main() {
  group('AppLanguage and capabilities', () {
    test('English has its code and is a supported learning language', () {
      expect(AppLanguage.english.code, 'en');
      expect(AppLanguage.english.englishName, 'English');
      expect(AppLanguage.values.byName('english'), AppLanguage.english);
      // Italian first, then the languages added later, in order.
      expect(
        supportedLearningLanguages,
        containsAllInOrder([AppLanguage.italian, AppLanguage.english]),
      );
      expect(availableSupportLanguages, availableUiLanguages);
      expect(availableUiLanguages, [
        AppLanguage.spanish,
        AppLanguage.english,
        AppLanguage.italian,
      ]);
      expect(
        learningRulesFor(AppLanguage.english)?.language,
        AppLanguage.english,
      );
      // A language is a learning language exactly when it has rules.
      for (final l in AppLanguage.values) {
        expect(
          learningRulesFor(l) != null,
          supportedLearningLanguages.contains(l),
          reason: l.name,
        );
      }
    });

    test('Spanish -> English is a supported pair', () {
      const pair = LanguagePair(
        support: AppLanguage.spanish,
        learning: AppLanguage.english,
      );
      expect(pair.isSupported, isTrue);
      expect(
        UserLearningProfile.empty
            .copyWith(learningLanguage: AppLanguage.english)
            .isValid,
        isFalse,
        reason: 'still needs level, goals and focus',
      );
    });
  });

  group('EnglishLearningRules: topic inference', () {
    test('the precise cases it knows', () {
      expect(_topics('He go to work', 'He goes to work'), [
        GrammarTopic.thirdPersonSingular,
      ]);
      expect(_topics('she study', 'she studies'), [
        GrammarTopic.thirdPersonSingular,
      ]);
      expect(_topics('I am go to school', 'I am going to school'), [
        GrammarTopic.presentContinuous,
      ]);
      expect(_topics('She working now', 'She is working now'), [
        GrammarTopic.presentContinuous,
        GrammarTopic.toBe,
      ]);
      expect(
        _topics('Yesterday I go to the shop', 'Yesterday I went to the shop'),
        [GrammarTopic.pastSimple],
      );
      expect(_topics('I have seen him yesterday', 'I saw him yesterday'), [
        GrammarTopic.pastSimple,
        GrammarTopic.presentPerfect,
      ]);
      expect(_topics('I saw it already', 'I have seen it already'), [
        GrammarTopic.presentPerfect,
        GrammarTopic.pastSimple,
      ]);
      expect(_topics('He are tired', 'He is tired'), [GrammarTopic.toBe]);
      expect(_topics('She tired', 'She is tired'), [GrammarTopic.toBe]);
      expect(_topics('I have car', 'I have a car'), [GrammarTopic.articles]);
      expect(_topics('an car', 'a car'), [GrammarTopic.articles]);
      expect(_topics('I live in Monday', 'I live on Monday'), [
        GrammarTopic.prepositions,
      ]);
      expect(_topics('I always am late', 'I am always late'), [
        GrammarTopic.wordOrder,
      ]);
    });

    test('no evidence, no topic', () {
      expect(_topics('I like pizza', 'I love pizza'), isNull);
      expect(_topics('recieve', 'receive'), isNull, reason: 'spelling');
      expect(_topics('He go', 'He run'), isNull, reason: 'a different verb');
      expect(_topics('I go home', 'I went home'), [GrammarTopic.pastSimple]);
      // "to" added is not safely a preposition issue.
      expect(_topics('I want go', 'I want to go'), isNull);
      // Not a third-person subject.
      expect(_topics('They go', 'They goes'), isNull);
      // Identical texts are not a mistake at all.
      expect(_topics('Same text', 'same text'), isNull);
    });

    test('no Italian topic is ever produced', () {
      const italianOnly = {
        GrammarTopic.essereVsAvere,
        GrammarTopic.passatoProssimo,
        GrammarTopic.gender,
        GrammarTopic.plural,
        GrammarTopic.agreement,
        GrammarTopic.pronouns,
        GrammarTopic.verbConjugation,
      };
      for (final pair in [
        ('He go', 'He goes'),
        ('I have car', 'I have a car'),
        ('I have seen it yesterday', 'I saw it yesterday'),
        ('ho andato', 'sono andato'),
      ]) {
        expect(
          (_topics(pair.$1, pair.$2) ?? const []).toSet().intersection(
            italianOnly,
          ),
          isEmpty,
          reason: pair.toString(),
        );
      }
    });
  });

  group('EnglishLearningRules: success, articles, labels', () {
    LearningError known(
      String original,
      String corrected,
      GrammarTopic topic,
    ) => LearningError(
      id: 'en:$original -> $corrected',
      language: 'en',
      category: LearningErrorCategory.grammar,
      original: original,
      corrected: corrected,
      grammarTopic: topic,
      firstSeenAt: _now,
      lastSeenAt: _now,
      confidence: 0.9,
    );

    Map<GrammarTopic, double> detect(
      String message, {
      Set<String> keys = const {},
      Set<GrammarTopic> topics = const {},
    }) => _en.detectGrammarSuccesses(
      messageTokens: ErrorPattern.tokensOf(message),
      knownErrors: [
        known('he go', 'he goes', GrammarTopic.thirdPersonSingular),
      ],
      errorKeysThisTurn: keys,
      errorTopicsThisTurn: topics,
    );

    test('the corrected wording after a mistake is credited', () {
      expect(detect('He goes to school every day.'), {
        GrammarTopic.thirdPersonSingular: 0.7,
      });
    });

    test('conservative: mistake again, other wording, same turn', () {
      expect(detect('He go to school and he goes home'), isEmpty);
      expect(detect('We like school'), isEmpty);
      expect(
        detect('He goes to school', keys: {'en:he go -> he goes'}),
        isEmpty,
      );
      expect(
        detect('He goes to school', topics: {GrammarTopic.thirdPersonSingular}),
        isEmpty,
      );
    });

    test('articles are exactly a, an and the', () {
      for (final w in ['a', 'an', 'the']) {
        expect(_en.isArticle(w), isTrue, reason: w);
      }
      for (final w in ['il', 'la', 'this', 'some', 'any', 'my', 'one']) {
        expect(_en.isArticle(w), isFalse, reason: w);
      }
      expect(const ItalianLearningRules().isArticle('the'), isFalse);
    });

    test(
      'prompt names are English; other languages topics are not claimed',
      () {
        expect(_en.describeTopic(GrammarTopic.toBe), 'Verb to be');
        expect(_en.describeTopic(GrammarTopic.pastSimple), 'Past simple');
        expect(
          _en.describeTopic(GrammarTopic.presentPerfect),
          'Present perfect',
        );
        expect(
          _en.describeTopic(GrammarTopic.thirdPersonSingular),
          'Third-person singular',
        );
        expect(_en.describeTopic(GrammarTopic.articles), 'Articles');
        expect(_en.describeTopic(GrammarTopic.essereVsAvere), 'essereVsAvere');
      },
    );
  });

  group('learning engine with English rules', () {
    late InMemoryLocalStorage storage;
    late LocalLearningRepository repo;
    late DefaultLearningEngine english;
    late DefaultLearningEngine italian;

    setUp(() {
      storage = InMemoryLocalStorage();
      repo = LocalLearningRepository(storage);
      english = DefaultLearningEngine(repo, rules: _en, clock: () => _now);
      italian = DefaultLearningEngine(
        repo,
        rules: const ItalianLearningRules(),
        clock: () => _now,
      );
    });

    Future<LearnerLearningSummary> all() async =>
        _ok(await repo.getLearningSummary());

    test('mistakes, topics and vocabulary are recorded as English', () async {
      expect(
        await english.analyze(
          userMessage: 'He go to work',
          response: _reply([
            _fix('He go to work', 'He goes to work'),
            _fix(
              'I need a cellphone',
              'I need a mobile phone',
              category: CorrectionCategory.vocabulary,
            ),
          ]),
        ),
        isA<Success<void>>(),
      );
      final s = await all();
      final error = s.errors.firstWhere((e) => e.grammarTopic != null);
      expect(error.language, 'en');
      expect(error.id, startsWith('en:'));
      expect(error.grammarTopic, GrammarTopic.thirdPersonSingular);
      final topic = s.grammarTopics.single;
      expect(topic.topic, GrammarTopic.thirdPersonSingular);
      expect(topic.language, 'en');
      expect(s.vocabularyItems.single.language, 'en');
      expect(s.vocabularyItems.single.id, startsWith('en:'));
    });

    test(
      'English and Italian memory never mix, and survive each other',
      () async {
        await italian.analyze(
          userMessage: 'ho andato',
          response: _reply([_fix('ho andato', 'sono andato')]),
        );
        await english.analyze(
          userMessage: 'I have car',
          response: _reply([_fix('I have car', 'I have a car')]),
        );
        // The same words in both languages are two different mistakes.
        await english.analyze(
          userMessage: 'a il',
          response: _reply([_fix('la problema', 'il problema')]),
        );
        await italian.analyze(
          userMessage: 'la problema',
          response: _reply([_fix('la problema', 'il problema')]),
        );

        final stored = await all();
        expect(stored.errors.map((e) => e.language).toSet(), {'it', 'en'});

        final it = _ok(await italian.summary());
        final en = _ok(await english.summary());
        expect(it.errors.every((e) => e.language == 'it'), isTrue);
        expect(en.errors.every((e) => e.language == 'en'), isTrue);
        expect(
          it.errors.map((e) => e.id),
          contains('ho andato -> sono andato'),
        );
        expect(en.errors.map((e) => e.id), contains('en:car -> a car'));
        expect(en.grammarTopics.every((t) => t.language == 'en'), isTrue);
        expect(it.grammarTopics.every((t) => t.language == 'it'), isTrue);
        // The same topic name exists in both, kept apart.
        expect(
          stored.grammarTopics
              .where((t) => t.topic == GrammarTopic.articles)
              .length,
          greaterThanOrEqualTo(1),
        );

        // Italian behavior is as before: the legacy id is unchanged.
        expect(
          it.errors
              .firstWhere((e) => e.original.contains('ho andato'))
              .grammarTopic,
          GrammarTopic.essereVsAvere,
        );
      },
    );

    test('a correct use of English is detected only for English', () async {
      await english.analyze(
        userMessage: 'He go to work',
        response: _reply([_fix('He go to work', 'He goes to work')]),
      );
      await english.analyze(
        userMessage: 'He goes to the gym',
        response: _reply(const []),
      );
      final topic = _ok(await english.summary()).grammarTopics.single;
      expect(topic.successfulUseCount, 1);
      // An Italian engine sees none of it.
      expect(_ok(await italian.summary()).grammarTopics, isEmpty);
    });

    test('the AI context only carries the current language', () async {
      Future<LearningContext> context(DefaultLearningEngine e) async =>
          _ok(await e.learningContext());
      for (var i = 0; i < 2; i++) {
        await english.analyze(
          userMessage: 'x',
          response: _reply([_fix('He go to work', 'He goes to work')]),
        );
        await italian.analyze(
          userMessage: 'x',
          response: _reply([_fix('ho andato', 'sono andato')]),
        );
      }
      final en = await context(english);
      final it = await context(italian);
      expect(
        en.recurringErrors.map((e) => e.correct),
        isNot(contains('sono andato')),
      );
      expect(
        it.recurringErrors.map((e) => e.correct),
        isNot(contains('goes to work')),
      );
      expect(en.priorityTopics, [GrammarTopic.thirdPersonSingular]);
      expect(it.priorityTopics, contains(GrammarTopic.essereVsAvere));
    });
  });

  group('persistence of the language scope', () {
    test('legacy records without a language are Italian', () async {
      final storage = InMemoryLocalStorage();
      storage.data['learning_memory'] = jsonEncode({
        'version': 1,
        'errors': [
          {
            'id': 'ho andato -> sono andato',
            'category': 'grammar',
            'original': 'ho andato',
            'corrected': 'sono andato',
            'grammarTopic': 'essereVsAvere',
            'frequency': 3,
            'firstSeenAt': _now.toIso8601String(),
            'lastSeenAt': _now.toIso8601String(),
            'confidence': 0.9,
          },
        ],
        'grammarTopics': [
          {
            'topic': 'essereVsAvere',
            'exposureCount': 3,
            'errorCount': 3,
            'successfulUseCount': 0,
            'lastSeenAt': _now.toIso8601String(),
          },
        ],
        'vocabulary': [
          {
            'id': 'it:ciao',
            'word': 'ciao',
            'language': 'it',
            'exposureCount': 1,
            'successfulUseCount': 0,
            'lastSeenAt': _now.toIso8601String(),
          },
        ],
      });
      final repo = LocalLearningRepository(storage);
      final s = _ok(await repo.getLearningSummary());
      expect(s.errors.single.language, 'it');
      expect(s.grammarTopics.single.language, 'it');
      expect(s.forLanguage('it').errors, hasLength(1));
      expect(s.forLanguage('en').errors, isEmpty);
      expect(s.forLanguage('en').grammarTopics, isEmpty);

      // Writing keeps the Italian data and adds English next to it.
      final english = DefaultLearningEngine(
        repo,
        rules: _en,
        clock: () => _now,
      );
      await english.analyze(
        userMessage: 'x',
        response: _reply([_fix('I have car', 'I have a car')]),
      );
      final after = _ok(await repo.getLearningSummary());
      expect(
        after.errors.map((e) => e.id),
        containsAll(['ho andato -> sono andato', 'en:car -> a car']),
      );
      expect(
        after.errors
            .firstWhere((e) => e.id == 'ho andato -> sono andato')
            .frequency,
        3,
      );
    });

    test(
      'an English profile persists and switching keeps the Italian data',
      () async {
        final storage = InMemoryLocalStorage();
        final profiles = LocalUserLearningProfileRepository(storage);
        const italian = UserLearningProfile(
          level: LanguageLevel.a2,
          goals: {LearningGoal.work},
          focusAreas: {LearningFocus.grammar},
          onboardingCompleted: true,
        );
        await profiles.save(italian);
        expect(_ok(await profiles.load()), italian);

        await DefaultLearningEngine(
          LocalLearningRepository(storage),
          rules: const ItalianLearningRules(),
        ).analyze(
          userMessage: 'x',
          response: _reply([_fix('ho andato', 'sono andato')]),
        );
        final learningBefore = storage.data['learning_memory'];

        final english = italian.copyWith(learningLanguage: AppLanguage.english);
        await profiles.save(english);
        final loaded = _ok(await profiles.load());
        expect(loaded.learningLanguage, AppLanguage.english);
        expect(loaded.supportLanguage, AppLanguage.spanish);
        expect(loaded.isValid, isTrue);
        expect(loaded, english);
        expect(storage.data['learning_memory'], learningBefore);

        await profiles.save(
          english.copyWith(learningLanguage: AppLanguage.italian),
        );
        expect(_ok(await profiles.load()), italian);
        expect(storage.data['learning_memory'], learningBefore);
      },
    );
  });

  group('review with English', () {
    late InMemoryLocalStorage storage;
    late LocalLearningRepository learning;
    late LocalReviewRepository reviews;

    DefaultReviewEngine engineFor(AppLanguage language) =>
        DefaultReviewEngine(learning, reviews, learningLanguage: language);

    Future<List<String>> queue(AppLanguage language) async => _ok(
      await engineFor(language).getReviewQueue(now: _now),
    ).map((i) => i.id).toList();

    setUp(() async {
      storage = InMemoryLocalStorage();
      learning = LocalLearningRepository(storage);
      reviews = LocalReviewRepository(storage);
      final italian = DefaultLearningEngine(
        learning,
        rules: const ItalianLearningRules(),
        clock: () => _now,
      );
      final english = DefaultLearningEngine(
        learning,
        rules: _en,
        clock: () => _now,
      );
      for (var i = 0; i < 2; i++) {
        await italian.analyze(
          userMessage: 'x',
          response: _reply([_fix('la problema', 'il problema')]),
        );
        await english.analyze(
          userMessage: 'x',
          response: _reply([_fix('I have car', 'I have a car')]),
        );
      }
    });

    test(
      'grammar ids: Italian ones are unchanged, English ones are scoped',
      () async {
        final it = await queue(AppLanguage.italian);
        final en = await queue(AppLanguage.english);
        expect(it, contains('grammar:articles'));
        expect(en, contains('grammar:en:articles'));
        expect(it.where((id) => id.contains('en:')), isEmpty);
        expect(en, isNot(contains('grammar:articles')));
        expect(
          it.toSet().intersection(en.toSet()),
          isEmpty,
          reason: 'no collisions',
        );
      },
    );

    test(
      'the same topic in two languages has two independent schedules',
      () async {
        final eng = engineFor(AppLanguage.english);
        await queue(AppLanguage.italian);
        await queue(AppLanguage.english);
        _ok(
          await eng.recordReviewResult(
            itemId: 'grammar:en:articles',
            result: ReviewResult.success,
            now: _now,
          ),
        );
        final stored = _ok(await reviews.getItems());
        final enItem = stored.firstWhere((i) => i.id == 'grammar:en:articles');
        final itItem = stored.firstWhere((i) => i.id == 'grammar:articles');
        expect(enItem.successfulReviews, 1);
        expect(itItem.successfulReviews, 0);
        // Stable across a new engine (a restart).
        expect(
          await queue(AppLanguage.english),
          isNot(contains('grammar:en:articles')),
        );
        expect(await queue(AppLanguage.italian), contains('grammar:articles'));
      },
    );

    test('vocabulary of the other language is not reviewed', () async {
      await learning.recordVocabulary(
        UserVocabulary.of(word: 'prenotazione', at: _now, language: 'it'),
      );
      await learning.recordVocabulary(
        UserVocabulary.of(word: 'booking', at: _now, language: 'en'),
      );
      expect(
        await queue(AppLanguage.english),
        contains('vocabulary:en:booking'),
      );
      expect(
        await queue(AppLanguage.english),
        isNot(contains('vocabulary:it:prenotazione')),
      );
      expect(
        await queue(AppLanguage.italian),
        contains('vocabulary:it:prenotazione'),
      );
    });
  });

  group('exercises with English', () {
    const generator = DefaultExerciseGenerator(
      learningLanguage: AppLanguage.english,
    );

    LearningError error(
      String original,
      String corrected, {
      GrammarTopic? topic,
      String language = 'en',
      LearningErrorCategory category = LearningErrorCategory.grammar,
    }) => LearningError(
      id: scopedIdForTest(
        language,
        '${original.toLowerCase()} -> ${corrected.toLowerCase()}',
      ),
      language: language,
      category: category,
      original: original,
      corrected: corrected,
      explanation: 'Because.',
      grammarTopic: topic,
      frequency: 2,
      firstSeenAt: _now,
      lastSeenAt: _now,
      confidence: 0.9,
    );

    Exercise exercise(ReviewItem item, LearnerLearningSummary s) =>
        _ok(generator.generate(item, s));

    test('error correction uses the English texts', () {
      final e = error('He go to work', 'He goes to work');
      final ex = exercise(
        ReviewItem.discovered(ReviewItemType.error, e.id, _now),
        LearnerLearningSummary(errors: [e]),
      );
      expect(ex.type, ExerciseType.errorCorrection);
      expect(ex.prompt, 'He go to work');
      expect(ex.correctAnswer, 'He goes to work');
    });

    test('grammar choice for an English topic, scoped id', () {
      final e = error(
        'He go',
        'He goes',
        topic: GrammarTopic.thirdPersonSingular,
      );
      final summary = LearnerLearningSummary(
        errors: [e],
        grammarTopics: const [
          GrammarTopicProgress(
            topic: GrammarTopic.thirdPersonSingular,
            language: 'en',
            exposureCount: 2,
            errorCount: 2,
          ),
        ],
      );
      final ex = exercise(
        ReviewItem.discovered(
          ReviewItemType.grammar,
          'en:thirdPersonSingular',
          _now,
        ),
        summary,
      );
      expect(ex.type, ExerciseType.grammarChoice);
      expect(ex.prompt, 'thirdPersonSingular');
      expect(ex.options, ['He go', 'He goes']);
      expect(ex.correctAnswer, 'He goes');
      // The Italian-style unscoped id does not match an English topic.
      expect(
        generator.generate(
          ReviewItem.discovered(
            ReviewItemType.grammar,
            'thirdPersonSingular',
            _now,
          ),
          summary,
        ),
        isA<Failure<Exercise>>(),
      );
    });

    test('vocabulary cloze from an English correction, else unavailable', () {
      final word = UserVocabulary.of(
        word: 'mobile phone',
        at: _now,
        language: 'en',
      );
      final fix = error(
        'I need a cellphone',
        'I need a mobile phone',
        category: LearningErrorCategory.vocabulary,
      );
      final item = ReviewItem.discovered(
        ReviewItemType.vocabulary,
        word.id,
        _now,
      );
      final ex = exercise(
        item,
        LearnerLearningSummary(errors: [fix], vocabularyItems: [word]),
      );
      expect(ex.type, ExerciseType.vocabularyContext);
      expect(ex.prompt, 'i need a ${Exercise.blank}');
      expect(ex.correctAnswer, 'mobile phone');
      expect(
        generator.generate(
          item,
          LearnerLearningSummary(vocabularyItems: [word]),
        ),
        isA<Failure<Exercise>>(),
      );
    });

    test('Italian data never becomes an English exercise', () {
      final it = error('ho andato', 'sono andato', language: 'it');
      expect(
        generator.generate(
          ReviewItem.discovered(ReviewItemType.error, it.id, _now),
          LearnerLearningSummary(errors: [it]),
        ),
        isA<Failure<Exercise>>(),
      );
    });
  });

  group('teacher prompt for English', () {
    test('support Spanish, learning English, no Italian teacher', () {
      final text = buildTeacherInstruction(
        profile: const UserLearningProfile(
          learningLanguage: AppLanguage.english,
          level: LanguageLevel.b1,
          goals: {LearningGoal.work},
          focusAreas: {LearningFocus.grammar},
        ),
        correctionMode: false,
        learningContext: const LearningContext(
          priorityTopics: [GrammarTopic.thirdPersonSingular],
        ),
      );
      expect(text, contains('Support language: Spanish'));
      expect(text, contains('Learning language: English'));
      expect(text, contains('study English'));
      expect(text, contains('use English at work'));
      expect(text, contains('- Third-person singular'));
      expect(text, isNot(contains('Italian')));
      expect(text, isNot(contains('essere')));
    });
  });

  group('no hardcoded learning language in the new code', () {
    test('English rules do not name another language', () {
      for (final path in [
        'lib/features/learning/domain/english_learning_rules.dart',
      ]) {
        final text = File(path).readAsStringSync();
        expect(text.toLowerCase(), isNot(contains('italian')), reason: path);
      }
    });
  });
}

String scopedIdForTest(String language, String key) =>
    language == 'it' ? key : '$language:$key';
