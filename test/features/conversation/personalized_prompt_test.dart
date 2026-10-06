import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parla_con_me/app/config/app_config.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_context_builder.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/services/ai/gemini_ai_service.dart';

const _profile = UserLearningProfile(
  level: LanguageLevel.a2,
  goals: {LearningGoal.speakConfidently},
  focusAreas: {LearningFocus.grammar},
  onboardingCompleted: true,
);

const _full = LearningContext(
  priorityTopics: [GrammarTopic.essereVsAvere, GrammarTopic.passatoProssimo],
  recurringErrors: [
    ContextError(incorrect: 'ho andato', correct: 'sono andato'),
  ],
  vocabularyToReinforce: ['prenotazione'],
  positiveSignals: [GrammarTopic.articles],
);

String _instruction(LearningContext context, {bool correction = false}) =>
    buildTeacherInstruction(
      profile: _profile,
      correctionMode: correction,
      learningContext: context,
    );

void main() {
  group('teacher instruction', () {
    test('with no memory it is exactly what it was before personalization', () {
      final before = buildTeacherInstruction(
        profile: _profile,
        correctionMode: false,
      );
      expect(_instruction(LearningContext.empty), before);
      expect(before, isNot(contains('LEARNING CONTEXT')));
      // Nothing artificial either.
      expect(before.toLowerCase(), isNot(contains('no learning context')));
      expect(before.toLowerCase(), isNot(contains('memory')));
    });

    test('with a context it adds the section with the selected content', () {
      final text = _instruction(_full);
      expect(text, contains('LEARNING CONTEXT'));
      expect(text, contains('choosing essere or avere as the auxiliary verb'));
      expect(text, contains('the passato prossimo (past tense)'));
      expect(text, contains('"ho andato" instead of "sono andato"'));
      expect(text, contains('- prenotazione'));
      expect(
        text,
        contains('Improving (no need to simplify or over-correct here):'),
      );
      expect(text, contains('- articles'));
    });

    test('only the sections that have content are written', () {
      final text = _instruction(
        const LearningContext(vocabularyToReinforce: ['prenotazione']),
      );
      expect(text, contains('Words to reinforce naturally:'));
      expect(text, isNot(contains('Areas to reinforce gently:')));
      expect(text, isNot(contains('Mistakes the learner tends to make')));
      expect(text, isNot(contains('Improving (no need')));
    });

    test('it tells the AI never to reveal or announce the memory', () {
      final text = _instruction(_full);
      expect(text, contains('Never mention this guidance'));
      expect(text, contains('"you made this mistake before"'));
      expect(text, contains('"you have difficulty with..."'));
      expect(text, contains('"I noticed that..."'));
      expect(text, contains('Never force a topic'));
      expect(text, contains('never repeat the same exercise'));
      expect(text, contains('does not change when you correct or praise'));
      expect(text, contains('Natural communication comes first'));
      expect(text, contains('gradually use richer or less simple language'));
    });

    test('no ids, timestamps, counts, json or storage details leak in', () {
      final text = _instruction(_full);
      expect(
        text,
        isNot(contains('ho andato -> sono andato')),
        reason: 'internal id format',
      );
      expect(text, isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}'))));
      for (final forbidden in [
        'frequency',
        'exposure',
        'firstSeen',
        'lastSeen',
        'successfulUse',
        'errorCount',
        'learning_memory',
        'version',
        '{',
        '}',
        '[',
      ]) {
        expect(text, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test(
      'the declared profile and Correggimi keep their own, separate places',
      () {
        final text = _instruction(_full, correction: true);
        final about = text.indexOf('About this learner:');
        final context = text.indexOf('LEARNING CONTEXT');
        final mode = text.indexOf('CORRECTION MODE is ON');
        expect(about, greaterThan(0));
        expect(context, greaterThan(about));
        expect(mode, greaterThan(context));
        expect(text, contains('Level A2'));
        expect(text, contains('Learning focus: grammar'));

        expect(
          _instruction(_full),
          isNot(contains('CORRECTION MODE')),
          reason: 'the memory never turns Correggimi on',
        );
      },
    );

    test('the added text stays small even with a full context', () {
      final extra =
          _instruction(_full).length -
          buildTeacherInstruction(
            profile: _profile,
            correctionMode: false,
          ).length;
      expect(extra, lessThan(2500));
    });
  });

  group('what Gemini receives', () {
    test(
      'the request carries only the selected context, next to the real history',
      () async {
        final now = DateTime.utc(2026, 10, 20);
        // A memory far bigger than what may be sent, with internal data.
        final summary = LearnerLearningSummary(
          errors: [
            for (var i = 0; i < 8; i++)
              LearningError(
                id: 'secret-id-$i',
                category: LearningErrorCategory.grammar,
                original: 'sbaglio${String.fromCharCode(97 + i)}',
                corrected: 'giusto${String.fromCharCode(97 + i)}',
                frequency: 9,
                firstSeenAt: DateTime.utc(2026, 9, 1),
                lastSeenAt: now,
                confidence: 0.9,
              ),
          ],
          grammarTopics: [
            for (final t in GrammarTopic.values)
              GrammarTopicProgress(
                topic: t,
                exposureCount: 12,
                errorCount: 7,
                lastSeenAt: now,
              ),
          ],
          vocabularyItems: [
            for (var i = 0; i < 12; i++)
              UserVocabulary.of(
                word: 'parola${String.fromCharCode(97 + i)}',
                at: now,
              ),
          ],
        );
        final context = buildLearningContext(summary, now: now, language: 'it');

        late Map<String, dynamic> body;
        final client = MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"message":"Bene!","corrections":[]}'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });
        final service = GeminiAIService(
          const AppConfig(
            environment: AppEnvironment.development,
            geminiApiKey: 'TEST-KEY-123',
            geminiModel: 'test-model',
          ),
          client,
        );

        final result = await service.sendConversation(
          AIRequest(
            systemInstruction: _instruction(context),
            messages: const [
              AIMessage(role: AIRole.user, text: 'Ciao'),
              AIMessage(role: AIRole.assistant, text: 'Ciao! Come va?'),
              AIMessage(role: AIRole.user, text: 'Cosa hai fatto ieri?'),
            ],
          ),
        );
        expect(result, isA<Success<AIResponse>>());

        final sent =
            (((body['systemInstruction'] as Map)['parts'] as List).first
                    as Map)['text']
                as String;

        // Exactly the capped subset made it in: 3 topics, 3 errors, 5 words.
        final lines = sent.split('\n');
        final errorLines = lines
            .where((l) => l.contains(' instead of '))
            .toList();
        expect(errorLines, hasLength(3));
        // All eight tie on priority, so which three are kept is arbitrary;
        // what matters is the cap and that each pair is intact.
        for (final line in errorLines) {
          expect(
            line,
            matches(RegExp(r'^- "sbaglio(\w)" instead of "giusto\1"$')),
          );
        }
        expect(sent, isNot(contains('secret-id')));
        expect(sent, isNot(contains('TEST-KEY-123')));
        expect(
          RegExp(r'^- parola\w$', multiLine: true).allMatches(sent),
          hasLength(5),
        );
        final topicLines = lines
            .skipWhile((l) => !l.startsWith('Areas to reinforce gently:'))
            .skip(1)
            .takeWhile((l) => l.startsWith('- '))
            .toList();
        expect(topicLines, hasLength(3));
        expect(sent, isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}'))));

        // The conversation history is untouched by personalization.
        final contents = body['contents'] as List;
        expect(contents, hasLength(3));
        expect(((contents.last as Map)['parts'] as List).first, {
          'text': 'Cosa hai fatto ieri?',
        });
        // And the provider-side output contract is still appended.
        expect(sent, contains('OUTPUT FORMAT'));
      },
    );

    test(
      'with no memory the request is byte-for-byte what it was before',
      () async {
        late String plainBody;
        late String personalizedBody;
        MockClient capture(void Function(String) save) => MockClient((r) async {
          save(r.body);
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"message":"Ok"}'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });
        const config = AppConfig(
          environment: AppEnvironment.development,
          geminiApiKey: 'K',
          geminiModel: 'm',
        );
        const messages = [AIMessage(role: AIRole.user, text: 'Ciao')];

        await GeminiAIService(
          config,
          capture((b) => plainBody = b),
        ).sendConversation(
          AIRequest(
            systemInstruction: buildTeacherInstruction(
              profile: _profile,
              correctionMode: false,
            ),
            messages: messages,
          ),
        );
        await GeminiAIService(
          config,
          capture((b) => personalizedBody = b),
        ).sendConversation(
          AIRequest(
            systemInstruction: _instruction(LearningContext.empty),
            messages: messages,
          ),
        );
        expect(personalizedBody, plainBody);
      },
    );
  });
}
