import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/data/local_conversation_repository.dart';
import 'package:parla_con_me/features/conversation/domain/conversation.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/conversation/presentation/conversation_controller.dart';
import 'package:parla_con_me/features/conversation/presentation/widgets/message_bubble.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/default_learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/italian_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/learning_state.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_controller.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/services/ai/gemini_ai_service.dart';
import 'package:parla_con_me/services/ai/gemini_response_parser.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

// Phase 13: the teacher and the corrections, in the language being learned
// with their meaning in the support language underneath. A comprehension aid:
// learning never sees it.

/// (language being learned, support language). Nothing in the app branches on
/// any of them: they only travel as parameters.
const _pairs = <(AppLanguage, AppLanguage)>[
  (AppLanguage.italian, AppLanguage.spanish),
  (AppLanguage.english, AppLanguage.spanish),
  (AppLanguage.french, AppLanguage.italian),
  (AppLanguage.german, AppLanguage.spanish),
  (AppLanguage.spanish, AppLanguage.english),
  (AppLanguage.mandarin, AppLanguage.italian),
];

const _correction = Correction(
  original: 'Ieri ho andato al lavoro.',
  corrected: 'Ieri sono andato al lavoro.',
  correctedTranslation: 'Ayer fui al trabajo.',
  explanation: 'Con "andare" si usa "essere".',
  category: CorrectionCategory.grammar,
);

const _plainCorrection = Correction(
  original: 'Ieri ho andato al lavoro.',
  corrected: 'Ieri sono andato al lavoro.',
  explanation: 'Con "andare" si usa "essere".',
  category: CorrectionCategory.grammar,
);

String _json(Object value) => jsonEncode(value);

void main() {
  group('what the AI sends', () {
    test('the translation of the message and of each corrected sentence are '
        'read', () {
      final result = parseAssistantPayload(
        _json({
          'message': 'Certo! Come stai oggi?',
          'translation': '¡Claro! ¿Cómo estás hoy?',
          'corrections': [
            {
              'original': 'Ieri ho andato al lavoro.',
              'corrected': 'Ieri sono andato al lavoro.',
              'correctedTranslation': 'Ayer fui al trabajo.',
              'explanation': 'x',
            },
          ],
        }),
      );
      final response = (result as Success<AIResponse>).value;
      expect(response.message, 'Certo! Come stai oggi?');
      expect(response.translation, '¡Claro! ¿Cómo estás hoy?');
      expect(response.corrections.single.original, 'Ieri ho andato al lavoro.');
      expect(
        response.corrections.single.corrected,
        'Ieri sono andato al lavoro.',
      );
      expect(
        response.corrections.single.correctedTranslation,
        'Ayer fui al trabajo.',
      );
    });

    test('a missing, null, blank or malformed translation is just no '
        'translation, never a failed reply', () {
      for (final translation in [
        null,
        '',
        '   ',
        3,
        true,
        ['a'],
        {'a': 1},
      ]) {
        final result = parseAssistantPayload(
          _json({
            'message': 'Ciao!',
            'translation': translation,
            'corrections': [
              {
                'original': 'a',
                'corrected': 'b',
                'correctedTranslation': translation,
              },
            ],
          }),
        );
        final response = (result as Success<AIResponse>).value;
        expect(response.message, 'Ciao!', reason: '$translation');
        expect(response.translation, isNull, reason: '$translation');
        expect(response.corrections.single.correctedTranslation, isNull);
        expect(response.corrections.single.corrected, 'b');
      }
      final absent = parseAssistantPayload(_json({'message': 'Ciao!'}));
      expect((absent as Success<AIResponse>).value.translation, isNull);
    });

    test('an answer that is not JSON is still shown, without translation', () {
      final response =
          (parseAssistantPayload('Ciao, come stai?') as Success<AIResponse>)
              .value;
      expect(response.message, 'Ciao, come stai?');
      expect(response.translation, isNull);
    });

    test('the output contract asks for both translations', () {
      expect(
        GeminiAIService.outputFormatInstruction,
        contains('"translation"'),
      );
      expect(
        GeminiAIService.outputFormatInstruction,
        contains('"correctedTranslation"'),
      );
    });
  });

  group('the teacher is asked, for any pair of languages', () {
    for (final (learning, support) in _pairs) {
      test('${learning.name} -> ${support.name}', () {
        final profile = UserLearningProfile(
          learningLanguage: learning,
          supportLanguage: support,
          level: LanguageLevel.b1,
        );
        final instruction = buildTeacherInstruction(
          profile: profile,
          correctionMode: false,
        );
        expect(
          instruction,
          contains('translated faithfully into ${support.englishName}'),
        );
        expect(instruction, contains('"correctedTranslation"'));
        expect(instruction, contains('CORRECTED sentence'));
        expect(
          instruction,
          contains("Never translate the learner's mistaken sentence"),
        );
        // The teaching language is still the one being learned.
        expect(instruction, contains('Talk in ${learning.englishName}'));
        // No other language is named by the translation rules.
        final rules = instruction.substring(
          instruction.indexOf('Translation (a comprehension aid'),
        );
        for (final other in AppLanguage.values) {
          if (other == support || other == learning) continue;
          expect(rules, isNot(contains(other.englishName)), reason: other.name);
        }
      });
    }

    test('with a single language there is nothing to translate', () {
      final instruction = buildTeacherSystemPrompt(
        learning: AppLanguage.italian,
        support: AppLanguage.italian,
      );
      expect(instruction, isNot(contains('"translation"')));
    });

    test('no code decides by language: the pieces know no language', () {
      for (final path in [
        'lib/features/conversation/presentation/widgets/message_bubble.dart',
        'lib/services/ai/gemini_response_parser.dart',
        'lib/services/ai/gemini_ai_service.dart',
        'lib/features/conversation/data/local_conversation_repository.dart',
        'lib/features/conversation/domain/teacher_prompt.dart',
      ]) {
        final source = _read(path);
        expect(source, isNot(contains('AppLanguage.')), reason: path);
        expect(source, isNot(contains("== 'it'")), reason: path);
        expect(source, isNot(contains("== 'es'")), reason: path);
      }
    });
  });

  group('stored conversations', () {
    final at = DateTime.utc(2026, 10, 8, 9);

    test('translations survive saving and loading', () async {
      final storage = InMemoryLocalStorage();
      final repo = LocalConversationRepository(storage);
      final conversation = Conversation.start(id: 'c1', now: at)
          .addMessage(
            ConversationMessage(
              id: 'm1',
              role: MessageRole.user,
              content: 'Ieri ho andato al lavoro.',
              createdAt: at,
            ),
          )
          .addMessage(
            ConversationMessage(
              id: 'm2',
              role: MessageRole.assistant,
              content: 'Certo! Ieri sono andato al lavoro.',
              translation: '¡Claro! Ayer fui al trabajo.',
              createdAt: at,
              corrections: const [_correction],
            ),
          );
      await repo.save(conversation);
      final loaded =
          ((await repo.loadAll()) as Success<List<Conversation>>).value.single;
      expect(loaded.messages[0].translation, isNull);
      expect(loaded.messages[1].translation, '¡Claro! Ayer fui al trabajo.');
      expect(
        loaded.messages[1].corrections.single.correctedTranslation,
        'Ayer fui al trabajo.',
      );
      expect(loaded.messages[1].corrections.single, _correction);
    });

    test('a message without translation is not stored with one', () async {
      final storage = InMemoryLocalStorage();
      await LocalConversationRepository(storage).save(
        Conversation.start(id: 'c1', now: at).addMessage(
          ConversationMessage(
            id: 'm',
            role: MessageRole.assistant,
            content: 'Ciao',
            createdAt: at,
            corrections: const [_plainCorrection],
          ),
        ),
      );
      final stored = storage.data['conversations']!;
      expect(stored, isNot(contains('translation')));
      expect(stored, isNot(contains('correctedTranslation')));
    });

    test(
      'a conversation saved before translations existed still loads',
      () async {
        final storage = InMemoryLocalStorage();
        storage.data['conversations'] = _oldConversation(at);
        final loaded =
            ((await LocalConversationRepository(storage).loadAll())
                    as Success<List<Conversation>>)
                .value
                .single;
        expect(loaded.messages, hasLength(2));
        expect(loaded.messages.last.content, 'Bene! E poi?');
        expect(loaded.messages.last.translation, isNull);
        expect(loaded.messages.last.corrections.single, _plainCorrection);
        expect(
          loaded.messages.last.corrections.single.correctedTranslation,
          isNull,
        );
      },
    );
  });

  group('the learner sees both', () {
    for (final (learning, support) in _pairs.take(4)) {
      testWidgets('${learning.name} -> ${support.name}: the language being '
          'learned first, its meaning under it, in one bubble', (tester) async {
        final ai = FakeAIService(
          onRequest: (_) async => Success(
            AIResponse(
              message: 'Target ${learning.code}',
              translation: 'Meaning ${support.code}',
              corrections: [
                _correction.copyWithTexts(
                  corrected: 'Corrected ${learning.code}',
                  translation: 'Corrected meaning ${support.code}',
                ),
              ],
            ),
          ),
        );
        await _openParla(
          tester,
          ai,
          profile: onboardedProfile.copyWith(
            learningLanguage: learning,
            supportLanguage: support,
          ),
        );
        await _send(tester, 'Ieri ho andato al lavoro.');

        final target = find.text('Target ${learning.code}');
        final meaning = find.text('Meaning ${support.code}');
        expect(target, findsOneWidget);
        expect(meaning, findsOneWidget);
        // One bubble: the translation is inside the bubble of the message.
        final bubble = find.ancestor(
          of: target,
          matching: find.byType(MessageBubble),
        );
        expect(
          find.descendant(of: bubble, matching: meaning),
          findsOneWidget,
          reason: 'the translation belongs to the same message',
        );
        // The language being learned first, visually dominant.
        expect(
          tester.getTopLeft(target).dy,
          lessThan(tester.getTopLeft(meaning).dy),
        );
        expect(
          tester.getSize(target).height,
          greaterThanOrEqualTo(tester.getSize(meaning).height / 2),
        );
        TextStyle? styleOf(Finder text) => tester
            .widget<SelectableText>(
              find.ancestor(of: text, matching: find.byType(SelectableText)),
            )
            .style;
        final targetStyle = styleOf(target);
        final meaningStyle = styleOf(meaning);
        expect(meaningStyle?.fontStyle, FontStyle.italic);
        expect(targetStyle?.fontStyle, isNot(FontStyle.italic));
        expect(meaningStyle?.color, isNot(targetStyle?.color));
        expect(find.bySemanticsLabel('Traduzione'), findsWidgets);

        // The correction: what was written, the right sentence, its meaning.
        final original = find.textContaining(
          'Ieri ho andato',
          findRichText: true,
        );
        final corrected = find.textContaining(
          'Corrected ${learning.code}',
          findRichText: true,
        );
        final correctedMeaning = find.text('Corrected meaning ${support.code}');
        expect(original, findsWidgets);
        expect(corrected, findsOneWidget);
        expect(correctedMeaning, findsOneWidget);
        final card = find.ancestor(
          of: corrected,
          matching: find.byType(CorrectionCard),
        );
        expect(
          find.descendant(of: card, matching: correctedMeaning),
          findsOneWidget,
        );
        final originalInCard = find.descendant(
          of: card,
          matching: find.textContaining('Ieri ho andato', findRichText: true),
        );
        expect(
          tester.getTopLeft(originalInCard).dy,
          lessThan(tester.getTopLeft(corrected).dy),
        );
        expect(
          tester.getTopLeft(corrected).dy,
          lessThan(tester.getTopLeft(correctedMeaning).dy),
        );

        // The teacher was asked for the translation in THIS support language.
        expect(
          ai.requests.single.systemInstruction,
          contains('translated faithfully into ${support.englishName}'),
        );
      });
    }

    testWidgets('no translation: the reply is whole and nothing is invented', (
      tester,
    ) async {
      final ai = FakeAIService(
        onRequest: (_) async => const Success(
          AIResponse(message: 'Bene! E poi?', corrections: [_plainCorrection]),
        ),
      );
      await _openParla(tester, ai);
      await _send(tester, 'Ieri ho andato al lavoro.');

      expect(find.text('Bene! E poi?'), findsOneWidget);
      expect(
        find.textContaining('Ieri sono andato al lavoro.', findRichText: true),
        findsOneWidget,
        reason: 'the correction is complete',
      );
      expect(find.byIcon(Icons.translate), findsNothing);
      expect(find.bySemanticsLabel('Traduzione'), findsNothing);
    });

    testWidgets('old stored messages render, and a translation stored on a '
        'learner message is never shown', (tester) async {
      final storage = InMemoryLocalStorage();
      storage.data['conversations'] = _oldConversation(
        DateTime.utc(2026, 10, 8, 9),
        learnerTranslation: 'NO DEBE VERSE',
      );
      await _openParla(tester, FakeAIService(), storage: storage);

      expect(find.text('Bene! E poi?'), findsOneWidget);
      expect(find.text('Ieri ho andato al lavoro.'), findsOneWidget);
      expect(find.text('NO DEBE VERSE'), findsNothing);
      expect(find.byIcon(Icons.translate), findsNothing);
    });
  });

  group('the translation is not learning', () {
    final fixed = DateTime.utc(2026, 10, 8, 9);

    Future<({String? memory, int changes})> analyze(AIResponse response) async {
      final storage = InMemoryLocalStorage();
      var changes = 0;
      final engine = DefaultLearningEngine(
        LocalLearningRepository(storage),
        rules: const ItalianLearningRules(),
        clock: () => fixed,
        onMemoryChanged: () => changes++,
      );
      await engine.analyze(
        userMessage: 'Ieri ho andato al lavoro.',
        response: response,
        contextId: 'conversation:c1',
      );
      return (memory: storage.data['learning_memory'], changes: changes);
    }

    test('the same exchange with and without translations leaves exactly the '
        'same learning memory', () async {
      final without = await analyze(
        const AIResponse(message: 'Quasi!', corrections: [_plainCorrection]),
      );
      final withTranslation = await analyze(
        const AIResponse(
          message: 'Quasi!',
          translation: '¡Casi!',
          corrections: [_correction],
        ),
      );
      expect(without.memory, isNotNull);
      expect(withTranslation.memory, without.memory);
      expect(withTranslation.changes, without.changes);
      expect(withTranslation.memory, isNot(contains('Ayer fui')));
    });

    test('a reply that only has a translation creates no evidence and no '
        'revision', () async {
      final result = await analyze(
        const AIResponse(message: 'Bene!', translation: '¡Bien!'),
      );
      expect(result.memory, isNull);
      expect(result.changes, 0);
    });

    test('through the real chat: stored, shown, never sent back, never '
        'learned, and the level is untouched', () async {
      const profile = UserLearningProfile(
        level: LanguageLevel.b1,
        goals: {LearningGoal.work},
        focusAreas: {LearningFocus.conversation},
        onboardingCompleted: true,
      );
      final storage = InMemoryLocalStorage();
      var calls = 0;
      final ai = FakeAIService(
        onRequest: (_) async {
          calls++;
          return Success(
            AIResponse(
              message: 'Risposta $calls',
              translation: 'TRADUZIONE-$calls',
              corrections: calls == 1 ? const [_correction] : const [],
            ),
          );
        },
      );
      final c = ProviderContainer(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(storage),
          aiServiceProvider.overrideWithValue(ai),
          userLearningProfileProvider.overrideWith(
            () => PreloadedUserLearningProfileController(profile),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(learningRevisionProvider, (_, _) {});
      c.read(conversationControllerProvider);
      while (c.read(conversationControllerProvider).status ==
          ConversationStatus.loading) {
        await Future<void>.delayed(Duration.zero);
      }
      final chat = c.read(conversationControllerProvider.notifier);

      await chat.send('Ieri ho andato al lavoro.');
      await pumpEventQueue();
      await chat.send('Ieri sono andato al mare.');
      await pumpEventQueue();

      // Stored with the message, and read back.
      final stored =
          ((await LocalConversationRepository(storage).loadAll())
                  as Success<List<Conversation>>)
              .value
              .single;
      final teacher = stored.messages
          .where((m) => m.role == MessageRole.assistant)
          .toList();
      expect(teacher.map((m) => m.translation), [
        'TRADUZIONE-1',
        'TRADUZIONE-2',
      ]);
      expect(
        teacher.first.corrections.single.correctedTranslation,
        'Ayer fui al trabajo.',
      );

      // Never sent back to the AI as history.
      for (final request in ai.requests) {
        for (final message in request.messages) {
          expect(message.text, isNot(contains('TRADUZIONE')));
        }
      }

      // Learning saw the Italian only.
      final memory =
          ((await LocalLearningRepository(storage).getLearningSummary())
                  as Success<LearnerLearningSummary>)
              .value;
      expect(memory.errors.single.corrected, 'sono andato');
      final topic = memory.grammarTopics.firstWhere(
        (t) => t.topic == GrammarTopic.essereVsAvere,
      );
      expect(topic.proof.productionFailures, 1);
      expect(topic.proof.productionSuccesses, 1);
      expect(topic.learningState, LearningState.weak);
      expect(storage.data['learning_memory'], isNot(contains('Ayer')));
      expect(storage.data['learning_memory'], isNot(contains('TRADUZIONE')));

      // The declared level did not move.
      expect(c.read(userLearningProfileProvider), profile);
      expect(c.read(userLearningProfileProvider).level, LanguageLevel.b1);
    });
  });
}

extension on Correction {
  Correction copyWithTexts({
    required String corrected,
    required String translation,
  }) => Correction(
    original: original,
    corrected: corrected,
    explanation: explanation,
    category: category,
    correctedTranslation: translation,
  );
}

String _read(String path) => File(path).readAsStringSync();

/// A conversation as the app stored it before translations existed.
String _oldConversation(DateTime at, {String? learnerTranslation}) => _json({
  'v': 1,
  'conversations': [
    {
      'id': 'old',
      'createdAt': at.toIso8601String(),
      'updatedAt': at.toIso8601String(),
      'messages': [
        {
          'id': 'u1',
          'role': 'user',
          'content': 'Ieri ho andato al lavoro.',
          'createdAt': at.toIso8601String(),
          'corrections': <Object>[],
          'translation': ?learnerTranslation,
        },
        {
          'id': 'a1',
          'role': 'assistant',
          'content': 'Bene! E poi?',
          'createdAt': at.toIso8601String(),
          'corrections': [_plainCorrection.toJson()],
        },
      ],
    },
  ],
});

Future<void> _openParla(
  WidgetTester tester,
  FakeAIService ai, {
  InMemoryLocalStorage? storage,
  UserLearningProfile profile = onboardedProfile,
}) async {
  await pumpApp(
    tester,
    storage ?? InMemoryLocalStorage(),
    profile: profile,
    overrides: [
      aiServiceProvider.overrideWithValue(ai),
      learningEngineProvider.overrideWithValue(RecordingLearningEngine()),
    ],
  );
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Parla'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(
    find.ancestor(
      of: find.byTooltip('Invia'),
      matching: find.byType(IconButton),
    ),
  );
  await tester.pumpAndSettle();
}
