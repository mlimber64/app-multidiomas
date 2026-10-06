import '../../core/result/result.dart';
import '../audio/audio_clip.dart';
import '../../shared/models/correction.dart';

enum AIRole { user, assistant }

/// A single turn in a provider-agnostic conversation.
class AIMessage {
  const AIMessage({required this.role, required this.text, this.audio});
  final AIRole role;
  final String text;

  /// A voice message: the learner spoke instead of typing. Only the latest
  /// learner message carries it; earlier voice messages are sent as the
  /// transcript the AI gave back.
  final AudioClip? audio;
}

/// What the app asks the AI to do. The app (not the provider) owns the
/// behavior: [systemInstruction] is built by the app from the learner's
/// profile and mode, [messages] is the relevant history ending with the
/// learner's latest message.
class AIRequest {
  const AIRequest({required this.messages, this.systemInstruction});
  final List<AIMessage> messages;
  final String? systemInstruction;
}

/// The assistant's reply: a conversational [message] plus zero or more
/// structured [corrections] of what the learner wrote.
class AIResponse {
  const AIResponse({
    required this.message,
    this.corrections = const <Correction>[],
    this.transcript,
  });
  final String message;
  final List<Correction> corrections;

  /// What the learner said, when their message was a recording (`null` for a
  /// typed message; empty when nothing intelligible was heard).
  final String? transcript;
}

/// Provider-agnostic AI boundary. Features and the Learning Engine depend on
/// this interface only; no provider types may appear in its signatures.
/// Implementations never throw: every failure is an `AIFailure`.
abstract interface class AIService {
  Future<Result<AIResponse>> sendConversation(AIRequest request);
}
