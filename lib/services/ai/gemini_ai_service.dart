import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../../app/config/app_config.dart';
import '../../core/errors/failure.dart';
import '../../core/result/result.dart';
import 'ai_service.dart';
import 'gemini_response_parser.dart';

/// Gemini-backed [AIService] using the REST `generateContent` endpoint.
///
/// This class only builds the request, sends it, maps the reply and maps
/// errors. It does not store conversations, touch state, or decide behavior:
/// the app supplies the instruction and history in the [AIRequest].
///
/// SECURITY: the API key is sent in the `x-goog-api-key` header (never in the
/// URL, so it can't leak through logs) and is never logged. A key compiled
/// into a client app is still extractable; see docs/ARCHITECTURE.md.
class GeminiAIService implements AIService {
  GeminiAIService(
    this._config,
    this._client, {
    this.timeout = const Duration(seconds: 30),
    this.audioTimeout = const Duration(seconds: 60),
  });

  static const _host = 'generativelanguage.googleapis.com';

  /// Appended to the app's instruction: this is the provider-side contract
  /// that produces [AIResponse]. Kept here so the app's teacher prompt stays
  /// provider-agnostic.
  static const outputFormatInstruction = '''

OUTPUT FORMAT (mandatory): reply with ONLY one JSON object, no markdown, no code fences:
{"message": string, "transcript": string or null, "corrections": [{"original": string, "corrected": string, "explanation": string, "naturalAlternative": string or null, "category": "grammar"|"vocabulary"|"pronunciation"|"naturalExpression"|"spelling"|"other"}]}
"message" is your conversational reply. "corrections" is [] when there is nothing worth correcting. "transcript" is null unless the learner's latest message is an audio recording, in which case it is what they said.''';

  final AppConfig _config;
  final http.Client _client;
  final Duration timeout;

  /// Longer: a recording has to be uploaded and listened to.
  final Duration audioTimeout;

  @override
  Future<Result<AIResponse>> sendConversation(AIRequest request) async {
    if (_config.geminiApiKey.isEmpty) {
      return const Failure(
        AIFailure(
          'GEMINI_API_KEY is not configured',
          kind: AIFailureKind.notConfigured,
        ),
      );
    }
    if (request.messages.isEmpty) {
      return const Failure(AIFailure('Cannot send an empty conversation'));
    }

    final uri = Uri.https(
      _host,
      '/v1beta/models/${_config.geminiModel}:generateContent',
    );
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              'x-goog-api-key': _config.geminiApiKey,
            },
            body: jsonEncode(_body(request)),
          )
          .timeout(
            request.messages.any((m) => m.audio != null)
                ? audioTimeout
                : timeout,
          );
      if (response.statusCode == 200) {
        return parseGeminiResponse(utf8.decode(response.bodyBytes));
      }
      return Failure(_httpFailure(response));
    } on TimeoutException {
      return const Failure(
        AIFailure('Gemini request timed out', kind: AIFailureKind.network),
      );
    } on SocketException {
      return const Failure(
        AIFailure('No network connection', kind: AIFailureKind.network),
      );
    } on http.ClientException {
      return const Failure(
        AIFailure('Network error calling Gemini', kind: AIFailureKind.network),
      );
    } on FormatException {
      return const Failure(
        AIFailure(
          'Undecodable Gemini response',
          kind: AIFailureKind.invalidResponse,
        ),
      );
    }
  }

  Map<String, Object?> _body(AIRequest request) {
    final instruction =
        '${request.systemInstruction ?? ''}$outputFormatInstruction';
    return {
      'systemInstruction': {
        'parts': [
          {'text': instruction},
        ],
      },
      'contents': [
        for (final m in request.messages)
          {
            'role': m.role == AIRole.user ? 'user' : 'model',
            'parts': [
              if (m.audio case final audio?)
                {
                  'inlineData': {
                    'mimeType': audio.mimeType,
                    'data': base64Encode(audio.bytes),
                  },
                },
              if (m.text.isNotEmpty || m.audio == null) {'text': m.text},
            ],
          },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.7,
      },
    };
  }

  /// Maps HTTP errors to domain failures. The response body is only inspected
  /// to tell a bad key from other 400s; it is never copied into the failure.
  AIFailure _httpFailure(http.Response response) {
    final status = response.statusCode;
    final badKey =
        status == 400 && response.body.contains('API_KEY_INVALID') ||
        status == 401 ||
        status == 403;
    if (badKey) {
      return AIFailure(
        'Gemini rejected the credentials (HTTP $status)',
        kind: AIFailureKind.notConfigured,
      );
    }
    if (status == 429) {
      return const AIFailure(
        'Gemini rate limit reached (HTTP 429)',
        kind: AIFailureKind.rateLimited,
      );
    }
    if (status >= 500) {
      return AIFailure(
        'Gemini unavailable (HTTP $status)',
        kind: AIFailureKind.network,
      );
    }
    return AIFailure('Gemini request failed (HTTP $status)');
  }
}
