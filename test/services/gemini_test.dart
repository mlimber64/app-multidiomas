import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parla_con_me/app/config/app_config.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/services/ai/gemini_ai_service.dart';
import 'package:parla_con_me/services/ai/gemini_response_parser.dart';
import 'package:parla_con_me/shared/models/correction.dart';

const _secret = 'SECRET-TEST-KEY';

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

AIResponse _ok(Result<AIResponse> r) =>
    r.when(success: (v) => v, failure: (f) => fail('unexpected $f'));

AIFailure _err(Result<AIResponse> r) => r.when(
  success: (v) => fail('expected a failure, got ${v.message}'),
  failure: (f) => f as AIFailure,
);

void main() {
  group('response parser', () {
    test('parses message and structured corrections', () {
      final r = _ok(
        parseGeminiResponse(
          _envelope(
            jsonEncode({
              'message': 'Quasi! 😊 E com\'è andata?',
              'corrections': [
                {
                  'original': 'ho andato',
                  'corrected': 'sono andato',
                  'explanation': 'Con "andare" si usa "essere".',
                  'naturalAlternative': null,
                  'category': 'grammar',
                },
              ],
            }),
          ),
        ),
      );
      expect(r.message, contains('Quasi'));
      expect(r.corrections.single.corrected, 'sono andato');
      expect(r.corrections.single.category, CorrectionCategory.grammar);
    });

    test('a reply without corrections is valid', () {
      final r = _ok(
        parseAssistantPayload('{"message":"Ciao!","corrections":[]}'),
      );
      expect(r.corrections, isEmpty);
      expect(
        _ok(parseAssistantPayload('{"message":"Ciao!"}')).corrections,
        isEmpty,
      );
    });

    test('handles code fences and drops unusable corrections', () {
      final r = _ok(
        parseAssistantPayload(
          '```json\n{"message":"Ok","corrections":[{"original":"x"},"junk",'
          '{"original":"a","corrected":"b","category":"???"}]}\n```',
        ),
      );
      expect(r.message, 'Ok');
      expect(r.corrections, hasLength(1));
      expect(r.corrections.single.category, CorrectionCategory.other);
    });

    test('plain text (format ignored) is used as the message', () {
      expect(
        _ok(parseAssistantPayload('Ciao, come stai?')).message,
        'Ciao, come stai?',
      );
    });

    test(
      'broken or truncated JSON is an invalid response, never raw braces',
      () {
        for (final bad in [
          '{"message": "Cia',
          '{',
          '[1,2',
          '{"corrections": []}',
          '{"message": ""}',
          '',
        ]) {
          expect(
            _err(parseAssistantPayload(bad)).kind,
            AIFailureKind.invalidResponse,
            reason: bad,
          );
        }
      },
    );

    test('envelope problems map to failures without throwing', () {
      expect(
        _err(parseGeminiResponse('not json')).kind,
        AIFailureKind.invalidResponse,
      );
      expect(
        _err(parseGeminiResponse('[]')).kind,
        AIFailureKind.invalidResponse,
      );
      expect(
        _err(parseGeminiResponse('{}')).kind,
        AIFailureKind.invalidResponse,
      );
      expect(
        _err(
          parseGeminiResponse(
            jsonEncode({
              'candidates': [
                {
                  'content': {'parts': []},
                },
              ],
            }),
          ),
        ).kind,
        AIFailureKind.invalidResponse,
      );
      expect(
        _err(
          parseGeminiResponse(
            jsonEncode({
              'promptFeedback': {'blockReason': 'SAFETY'},
            }),
          ),
        ).kind,
        AIFailureKind.blocked,
      );
      expect(
        _err(
          parseGeminiResponse(
            jsonEncode({
              'candidates': [
                {'finishReason': 'SAFETY'},
              ],
            }),
          ),
        ).kind,
        AIFailureKind.blocked,
      );
    });

    test('thought parts are ignored', () {
      final body = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'internal reasoning', 'thought': true},
                {'text': '{"message":"Ciao"}'},
              ],
            },
          },
        ],
      });
      expect(_ok(parseGeminiResponse(body)).message, 'Ciao');
    });
  });

  group('GeminiAIService', () {
    const config = AppConfig(
      environment: AppEnvironment.development,
      geminiApiKey: _secret,
      geminiModel: 'test-model',
    );
    const request = AIRequest(
      systemInstruction: 'Be a teacher.',
      messages: [
        AIMessage(role: AIRole.user, text: 'Ciao'),
        AIMessage(role: AIRole.assistant, text: 'Ciao! Come stai?'),
        AIMessage(role: AIRole.user, text: 'Bene'),
      ],
    );

    GeminiAIService service(http.Client client, {AppConfig cfg = config}) =>
        GeminiAIService(
          cfg,
          client,
          timeout: const Duration(milliseconds: 200),
        );

    test(
      'builds the request: key only in header, roles, instruction, JSON mode',
      () async {
        late http.Request sent;
        final client = MockClient((r) async {
          sent = r;
          return http.Response(_envelope('{"message":"Bene!"}'), 200);
        });

        final result = _ok(await service(client).sendConversation(request));

        expect(result.message, 'Bene!');
        expect(sent.url.host, 'generativelanguage.googleapis.com');
        expect(sent.url.path, '/v1beta/models/test-model:generateContent');
        expect(sent.headers['x-goog-api-key'], _secret);
        expect(sent.url.toString(), isNot(contains(_secret)));
        expect(sent.body, isNot(contains(_secret)));

        final body = jsonDecode(sent.body) as Map<String, dynamic>;
        final roles = [
          for (final c in body['contents'] as List) (c as Map)['role'],
        ];
        expect(roles, ['user', 'model', 'user']);
        final instruction =
            (((body['systemInstruction'] as Map)['parts'] as List).first
                    as Map)['text']
                as String;
        expect(instruction, startsWith('Be a teacher.'));
        expect(instruction, contains('OUTPUT FORMAT'));
        expect(
          (body['generationConfig'] as Map)['responseMimeType'],
          'application/json',
        );
      },
    );

    test(
      'without a key it fails as notConfigured and never calls the network',
      () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response('', 200);
        });
        final failure = _err(
          await service(
            client,
            cfg: const AppConfig(environment: AppEnvironment.development),
          ).sendConversation(request),
        );
        expect(failure.kind, AIFailureKind.notConfigured);
        expect(calls, 0);
      },
    );

    test('HTTP errors map to kinds and never leak the key or body', () async {
      final cases = <int, AIFailureKind>{
        400: AIFailureKind.unknown,
        401: AIFailureKind.notConfigured,
        403: AIFailureKind.notConfigured,
        429: AIFailureKind.rateLimited,
        500: AIFailureKind.network,
        503: AIFailureKind.network,
      };
      for (final entry in cases.entries) {
        final client = MockClient(
          (_) async => http.Response(
            '{"error":{"message":"detail $_secret"}}',
            entry.key,
          ),
        );
        final failure = _err(await service(client).sendConversation(request));
        expect(failure.kind, entry.value, reason: '${entry.key}');
        expect(failure.message, isNot(contains(_secret)));
      }

      final badKey = MockClient(
        (_) async => http.Response(
          '{"error":{"details":[{"reason":"API_KEY_INVALID"}]}}',
          400,
        ),
      );
      expect(
        _err(await service(badKey).sendConversation(request)).kind,
        AIFailureKind.notConfigured,
      );
    });

    test('network exceptions and timeouts become network failures', () async {
      final socket = MockClient(
        (_) async => throw const SocketException('down'),
      );
      final client = MockClient(
        (_) async => throw http.ClientException('boom'),
      );
      final slow = MockClient((_) => Completer<http.Response>().future);

      for (final c in [socket, client, slow]) {
        expect(
          _err(await service(c).sendConversation(request)).kind,
          AIFailureKind.network,
        );
      }
    });

    test('a 200 with garbage never throws', () async {
      final client = MockClient((_) async => http.Response('<html>', 200));
      expect(
        _err(await service(client).sendConversation(request)).kind,
        AIFailureKind.invalidResponse,
      );
    });
  });
}
