import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parla_con_me/app/config/app_config.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/voice/domain/speech_text.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/services/ai/gemini_ai_service.dart';
import 'package:parla_con_me/services/ai/gemini_response_parser.dart';

import '../../support/fake_voice.dart';

AIResponse _ok(Result<AIResponse> r) =>
    r.when(success: (v) => v, failure: (f) => fail('unexpected $f'));

String _envelope(String text) => jsonEncode({
  'candidates': [
    {
      'finishReason': 'STOP',
      'content': {
        'parts': [
          {'text': text},
        ],
      },
    },
  ],
});

void main() {
  group('how things are read aloud', () {
    test('every language has its own voice tag', () {
      final tags = {for (final l in AppLanguage.values) l: speechLocaleTag(l)};
      expect(tags.values.toSet(), hasLength(AppLanguage.values.length));
      expect(tags[AppLanguage.italian], 'it-IT');
      expect(tags[AppLanguage.mandarin], 'zh-CN');
      for (final tag in tags.values) {
        expect(tag, matches(RegExp(r'^[a-z]{2}-[A-Z]{2}$')));
      }
    });

    test('spelling: letters one by one, words apart, punctuation skipped', () {
      expect(spellOut('il computer'), 'i, l. c, o, m, p, u, t, e, r');
      expect(spellOut("l'amico"), 'l, a, m, i, c, o');
      expect(spellOut('  ciao!  '), 'c, i, a, o');
      expect(spellOut('Hello, world.'), 'H, e, l, l, o. w, o, r, l, d');
      expect(spellOut('A1'), 'A, 1');
      expect(spellOut(''), '');
      expect(spellOut('...'), '');
    });

    test('spelling reads accents, other alphabets and Chinese characters', () {
      expect(spellOut('perché'), 'p, e, r, c, h, é');
      expect(spellOut('Straße'), 'S, t, r, a, ß, e');
      expect(spellOut('电脑'), '电, 脑');
    });
  });

  group('the teacher is told when the message is a recording', () {
    const profile = UserLearningProfile(
      level: LanguageLevel.a2,
      goals: {LearningGoal.work},
      focusAreas: {LearningFocus.conversation},
    );

    test('only then does the instruction carry the voice rules', () {
      final typed = buildTeacherInstruction(
        profile: profile,
        correctionMode: false,
      );
      final voice = buildTeacherInstruction(
        profile: profile,
        correctionMode: false,
        voiceMessage: true,
      );
      expect(typed, isNot(contains('VOICE MESSAGE')));
      expect(voice, contains('VOICE MESSAGE'));
      expect(voice, contains('"transcript"'));
      expect(voice, contains('pronunciation'));
      expect(voice, contains('WITHOUT fixing their mistakes'));
      expect(voice, contains('Never invent a pronunciation problem'));
      expect(voice, startsWith(typed.split('\n').first));
    });
  });

  group('the AI hears the recording', () {
    test('the reply carries what the learner said', () {
      final r = _ok(
        parseGeminiResponse(
          _envelope(
            jsonEncode({
              'message': 'Bene! Cosa hai fatto?',
              'transcript': '  Ieri ho andato al mare  ',
              'corrections': [
                {
                  'original': 'ho andato',
                  'corrected': 'sono andato',
                  'explanation': 'Con "andare" si usa "essere".',
                  'category': 'grammar',
                },
                {
                  'original': 'mare',
                  'corrected': 'mare',
                  'explanation': 'La "a" è aperta.',
                  'category': 'pronunciation',
                },
              ],
            }),
          ),
        ),
      );
      expect(r.transcript, 'Ieri ho andato al mare');
      expect(r.corrections, hasLength(2));
    });

    test('a typed message has no transcript; an unheard one is empty', () {
      expect(
        _ok(
          parseGeminiResponse(_envelope(jsonEncode({'message': 'Ciao!'}))),
        ).transcript,
        isNull,
      );
      expect(
        _ok(
          parseGeminiResponse(
            _envelope(jsonEncode({'message': 'Ripeti?', 'transcript': ''})),
          ),
        ).transcript,
        '',
      );
    });

    test('the recording is sent as inline audio, with a longer wait', () async {
      late Map<String, dynamic> body;
      final client = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          _envelope(jsonEncode({'message': 'Bene!', 'transcript': 'ciao'})),
          200,
        );
      });
      final service = GeminiAIService(
        const AppConfig(
          environment: AppEnvironment.development,
          geminiApiKey: 'KEY',
        ),
        client,
      );
      final clip = fakeClip();
      final result = _ok(
        await service.sendConversation(
          AIRequest(
            messages: [
              const AIMessage(role: AIRole.user, text: 'Ciao'),
              const AIMessage(role: AIRole.assistant, text: 'Ciao! Come stai?'),
              AIMessage(role: AIRole.user, text: '', audio: clip),
            ],
            systemInstruction: 'Teach.',
          ),
        ),
      );
      expect(result.transcript, 'ciao');

      final contents = body['contents'] as List<dynamic>;
      final last = (contents.last as Map<String, dynamic>)['parts'] as List;
      expect(last, hasLength(1), reason: 'no empty text next to the audio');
      final inline = (last.single as Map)['inlineData'] as Map;
      expect(inline['mimeType'], 'audio/wav');
      expect(base64Decode(inline['data'] as String), clip.bytes);
      // Earlier turns stay plain text.
      expect(((contents.first as Map)['parts'] as List).single, {
        'text': 'Ciao',
      });
      expect(
        (body['systemInstruction'] as Map)['parts'].toString(),
        contains('"transcript"'),
      );
    });

    test('a request without audio waits the usual time', () {
      final service = GeminiAIService(
        const AppConfig(environment: AppEnvironment.development),
        MockClient((_) async => http.Response('{}', 200)),
      );
      expect(service.audioTimeout, greaterThan(service.timeout));
    });
  });
}
