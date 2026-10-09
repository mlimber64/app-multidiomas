import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/default_learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/error_pattern.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/language_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/quechua_learning_rules.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_labels.dart';
import 'package:parla_con_me/features/voice/domain/speech_text.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/in_memory_local_storage.dart';

const _qu = QuechuaLearningRules();
final _now = DateTime.utc(2026, 10, 20, 12);

List<GrammarTopic>? _topics(String original, String corrected) {
  final pattern = ErrorPattern.from(original, corrected);
  return pattern == null ? null : _qu.inferGrammarTopics(pattern)?.topics;
}

T _ok<T>(Result<T> r) =>
    r.when(success: (v) => v, failure: (f) => fail('unexpected $f'));

AIResponse _reply(List<Correction> corrections) =>
    AIResponse(message: 'Allinmi!', corrections: corrections);

Correction _fix(String original, String corrected) => Correction(
  original: original,
  corrected: corrected,
  explanation: 'Imarayku.',
  category: CorrectionCategory.grammar,
);

void main() {
  group('capabilities', () {
    test('Quechua is a supported learning language, not an interface one', () {
      expect(AppLanguage.quechua.code, 'qu');
      expect(AppLanguage.quechua.englishName, contains('Southern Quechua'));
      expect(supportedLearningLanguages, contains(AppLanguage.quechua));
      expect(availableSupportLanguages, isNot(contains(AppLanguage.quechua)));
      expect(
        learningRulesFor(AppLanguage.quechua)?.language,
        AppLanguage.quechua,
      );
      for (final support in availableSupportLanguages) {
        expect(
          LanguagePair(
            support: support,
            learning: AppLanguage.quechua,
          ).isSupported,
          isTrue,
          reason: support.name,
        );
      }
      // Nobody can pick it as the language they are explained things in.
      expect(
        const LanguagePair(
          support: AppLanguage.quechua,
          learning: AppLanguage.italian,
        ).isSupported,
        isFalse,
      );
    });

    test('shown by its own name, with a sample sentence to hear', () {
      expect(AppLanguage.quechua.label, 'Quechua (Runasimi)');
      expect(voiceSampleText(AppLanguage.quechua), contains('Ñuqaqa'));
    });

    test('Quechua has no articles', () {
      expect(_qu.isArticle('el'), isFalse);
      expect(_qu.isArticle('ta'), isFalse);
    });
  });

  group('reading Quechua', () {
    test(
      'the ejective apostrophe is part of the word, however it is typed',
      () {
        expect(ErrorPattern.tokensOf("Ch'aki"), ["ch'aki"]);
        expect(ErrorPattern.tokensOf('Ch’aki'), ["ch'aki"]);
        expect(ErrorPattern.tokensOf('chʼaki'), ["ch'aki"]);
        expect(ErrorPattern.tokensOf('ch‘aki'), ["ch'aki"]);
        expect(ErrorPattern.tokensOf("Wasiypi ch'aki."), ['wasiypi', "ch'aki"]);
        // Quotes around a word are still only punctuation.
        expect(ErrorPattern.tokensOf('“runa”'), ['runa']);
      },
    );

    test('other languages read exactly as before', () {
      expect(ErrorPattern.tokensOf("L’ho visto, c'è"), [
        "l'ho",
        'visto',
        "c'è",
      ]);
    });
  });

  group('QuechuaLearningRules: topic inference', () {
    test('the precise cases it knows', () {
      // Evidentials.
      expect(_topics('Ñuqam kani', 'Ñuqas kani'), [GrammarTopic.evidentials]);
      expect(_topics('Paymi', 'Paychá'), [GrammarTopic.evidentials]);
      expect(_topics('Wasim', 'Wasimi'), [GrammarTopic.evidentials]);
      // Case suffixes.
      expect(_topics('Wasiman rini', 'Wasipi rini'), [
        GrammarTopic.caseSuffixes,
      ]);
      expect(_topics('Qusqoman', 'Qusqomanta'), [GrammarTopic.caseSuffixes]);
      expect(_topics('Tantata', 'Tantawan'), [GrammarTopic.caseSuffixes]);
      // Plural.
      expect(_topics('Runa hamunku', 'Runakuna hamunku'), [
        GrammarTopic.plural,
      ]);
      // Person endings of the verb.
      expect(_topics('Ñuqa rimanki', 'Ñuqa rimani'), [
        GrammarTopic.verbConjugation,
      ]);
      expect(_topics('Paykuna rimanchis', 'Paykuna rimanku'), [
        GrammarTopic.verbConjugation,
      ]);
      // Word order.
      expect(_topics('Mikuni tantata', 'Tantata mikuni'), [
        GrammarTopic.wordOrder,
      ]);
    });

    test('a suffix added or dropped is only a coarse hint', () {
      final p = ErrorPattern.from('Wasi rini', 'Wasiman rini')!;
      final inference = _qu.inferGrammarTopics(p)!;
      expect(inference.topics, [GrammarTopic.caseSuffixes]);
      expect(inference.confidence, lessThan(0.8));
    });

    test('no evidence, no topic', () {
      // A different word that merely ends like a suffix.
      expect(_topics('papa', 'pata'), isNull);
      expect(_topics('Allin punchaw', 'Allin tuta'), isNull);
      expect(_topics('Wasi', 'Mayu'), isNull);
      expect(_topics('Runa', 'Runa'), isNull);
    });

    test('never produces a topic that belongs to another language', () {
      const other = {
        GrammarTopic.articles,
        GrammarTopic.gender,
        GrammarTopic.essereVsAvere,
        GrammarTopic.serVsEstar,
        GrammarTopic.measureWords,
        GrammarTopic.cases,
      };
      for (final pair in [
        ('Ñuqam kani', 'Ñuqas kani'),
        ('Wasiman rini', 'Wasipi rini'),
        ('Runa hamunku', 'Runakuna hamunku'),
        ('Ñuqa rimanki', 'Ñuqa rimani'),
      ]) {
        expect(
          (_topics(pair.$1, pair.$2) ?? const []).toSet().intersection(other),
          isEmpty,
          reason: pair.toString(),
        );
      }
    });
  });

  group('QuechuaLearningRules: success and labels', () {
    LearningError known() => LearningError(
      id: 'qu:wasiman rini -> wasipi rini',
      language: 'qu',
      category: LearningErrorCategory.grammar,
      original: 'wasiman',
      corrected: 'wasipi',
      grammarTopic: GrammarTopic.caseSuffixes,
      firstSeenAt: _now,
      lastSeenAt: _now,
      confidence: 0.9,
    );

    Map<GrammarTopic, double> detect(String message) =>
        _qu.detectGrammarSuccesses(
          messageTokens: ErrorPattern.tokensOf(message),
          knownErrors: [known()],
          errorKeysThisTurn: const {},
          errorTopicsThisTurn: const {},
        );

    test('the corrected wording after a mistake is credited, literally', () {
      expect(detect('Ñuqa wasipi kani'), {GrammarTopic.caseSuffixes: 0.7});
      expect(detect('Ñuqa wasiman kani'), isEmpty);
      expect(detect('Ñuqa kani'), isEmpty);
    });

    test('prompt names', () {
      expect(
        _qu.describeTopic(GrammarTopic.evidentials),
        contains('-mi / -m, -si / -s and -chá'),
      );
      expect(_qu.describeTopic(GrammarTopic.caseSuffixes), contains('-manta'));
      expect(_qu.describeTopic(GrammarTopic.plural), contains('-kuna'));
      expect(_qu.describeTopic(GrammarTopic.cases), 'cases');
    });
  });

  group('Quechua in the shared memory', () {
    test('mistakes and words are recorded as qu and merge on repeat', () async {
      final repo = LocalLearningRepository(InMemoryLocalStorage());
      final engine = DefaultLearningEngine(repo, rules: _qu, clock: () => _now);
      for (var i = 0; i < 2; i++) {
        await engine.analyze(
          userMessage: 'Ñuqa wasiman kani',
          response: _reply([_fix('wasiman kani', 'wasipi kani')]),
        );
      }
      final summary = _ok(await engine.summary());
      expect(summary.errors.every((e) => e.language == 'qu'), isTrue);
      final error = summary.errors.single;
      expect(error.grammarTopic, GrammarTopic.caseSuffixes);
      expect(error.frequency, 2);
    });
  });

  group('how it is taught and read aloud', () {
    test(
      'the teacher prompt names the variant, the alphabet and the limits',
      () {
        final text = buildTeacherInstruction(
          profile: const UserLearningProfile(
            learningLanguage: AppLanguage.quechua,
            level: LanguageLevel.a1,
            goals: {LearningGoal.speakConfidently},
            focusAreas: {LearningFocus.conversation},
          ),
          correctionMode: false,
          learningContext: const LearningContext(
            priorityTopics: [GrammarTopic.evidentials],
          ),
        );
        expect(text, contains('Support language: Spanish'));
        expect(
          text,
          contains('Learning language: Southern Quechua (Cusco and Bolivia)'),
        );
        expect(text, contains('three-vowel alphabet'));
        expect(text, contains('Never invent'));
        expect(
          text,
          contains('explanations and corrections go in the support language'),
        );
        expect(text, contains('- the evidential suffixes'));
        // Other languages get no such note.
        final italian = buildTeacherInstruction(
          profile: UserLearningProfile.empty,
          correctionMode: false,
        );
        expect(italian, isNot(contains('three-vowel')));
      },
    );

    test('with no Quechua voice in any phone, a Spanish one reads it', () {
      expect(speechLocaleTag(AppLanguage.quechua), 'es-US');
    });

    test('the Quechua rules name no other language', () {
      final text = File(
        'lib/features/learning/domain/quechua_learning_rules.dart',
      ).readAsStringSync().toLowerCase();
      for (final other in [
        'italian',
        'english',
        'french',
        'portuguese',
        'german',
        'spanish',
        'mandarin',
      ]) {
        expect(text, isNot(contains(other)), reason: other);
      }
    });
  });
}
