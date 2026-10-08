import 'dart:convert';

import '../../core/errors/failure.dart';
import '../../core/result/result.dart';
import '../../shared/models/correction.dart';
import 'ai_service.dart';

/// Turns a raw Gemini `generateContent` response body into an [AIResponse].
///
/// Everything here treats the provider output as untrusted: invalid JSON,
/// missing fields, blocked prompts and truncated output all become an
/// [AIFailure] (or a degraded-but-usable response), never an exception.
Result<AIResponse> parseGeminiResponse(String body) {
  final Object? envelope;
  try {
    envelope = jsonDecode(body);
  } on FormatException {
    return const Failure(
      AIFailure(
        'Gemini returned a non-JSON body',
        kind: AIFailureKind.invalidResponse,
      ),
    );
  }
  if (envelope is! Map) {
    return const Failure(
      AIFailure(
        'Unexpected Gemini response shape',
        kind: AIFailureKind.invalidResponse,
      ),
    );
  }

  final candidates = envelope['candidates'];
  final candidate = candidates is List && candidates.isNotEmpty
      ? candidates.first
      : null;
  final text = candidate is Map ? _candidateText(candidate) : '';

  if (text.isEmpty) {
    final feedback = envelope['promptFeedback'];
    final blocked = feedback is Map && feedback['blockReason'] != null;
    final finish = candidate is Map ? candidate['finishReason'] : null;
    final safety =
        finish is String && finish != 'STOP' && finish != 'MAX_TOKENS';
    return Failure(
      blocked || safety
          ? const AIFailure(
              'Gemini declined to answer',
              kind: AIFailureKind.blocked,
            )
          : const AIFailure(
              'Gemini returned no text',
              kind: AIFailureKind.invalidResponse,
            ),
    );
  }
  return parseAssistantPayload(text);
}

String _candidateText(Map<dynamic, dynamic> candidate) {
  final content = candidate['content'];
  final parts = content is Map ? content['parts'] : null;
  if (parts is! List) return '';
  final buffer = StringBuffer();
  for (final part in parts) {
    // Skip "thought" parts; only the final answer is shown to the learner.
    if (part is Map && part['thought'] != true && part['text'] is String) {
      buffer.write(part['text']);
    }
  }
  return buffer.toString().trim();
}

/// Parses the model's text, which should be a JSON object
/// `{"message": ..., "corrections": [...]}`.
///
/// - Valid JSON: strict about `message`, lenient about each correction
///   (unusable ones are dropped).
/// - Not JSON and not JSON-looking: the plain text is used as the message
///   (the model ignored the format but still answered).
/// - JSON-looking but broken/truncated: invalid response, so the learner
///   never sees raw braces.
Result<AIResponse> parseAssistantPayload(String text) {
  final cleaned = _stripCodeFence(text.trim());
  try {
    final json = jsonDecode(cleaned);
    if (json is Map) {
      final message = json['message'];
      if (message is String && message.trim().isNotEmpty) {
        final transcript = json['transcript'];
        return Success(
          AIResponse(
            message: message.trim(),
            corrections: _corrections(json['corrections']),
            transcript: transcript is String ? transcript.trim() : null,
            translation: _translation(json['translation']),
          ),
        );
      }
    }
    return const Failure(
      AIFailure(
        'Gemini JSON had no usable message',
        kind: AIFailureKind.invalidResponse,
      ),
    );
  } on FormatException {
    if (cleaned.isEmpty || cleaned.startsWith('{') || cleaned.startsWith('[')) {
      return const Failure(
        AIFailure(
          'Gemini output was invalid or truncated JSON',
          kind: AIFailureKind.invalidResponse,
        ),
      );
    }
    return Success(AIResponse(message: cleaned));
  }
}

/// The translation of the message: a non-empty string, or nothing. Never an
/// error: a reply without a usable translation is still a usable reply.
String? _translation(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<Correction> _corrections(Object? raw) {
  if (raw is! List) return const [];
  return [for (final item in raw) ?Correction.tryFromJson(item)];
}

String _stripCodeFence(String text) {
  final fence = RegExp(r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$');
  return fence.firstMatch(text)?.group(1) ?? text;
}
