import '../../../core/result/result.dart';
import '../../../shared/models/correction.dart';

/// `system` exists for completeness but is never sent to the AI as history
/// nor shown in the UI: the teacher instruction is built per request.
enum MessageRole { user, assistant, system }

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.corrections = const <Correction>[],
    this.isVoice = false,
  });

  final String id;
  final MessageRole role;

  /// What the message says. For a voice message it is the transcript the AI
  /// heard (empty until the reply arrives, or when nothing was understood);
  /// the recording itself is never stored.
  final String content;
  final DateTime createdAt;

  /// Only assistant messages carry corrections (of the preceding user turn).
  final List<Correction> corrections;

  /// The learner spoke this message instead of typing it.
  final bool isVoice;

  ConversationMessage withContent(String text) => ConversationMessage(
    id: id,
    role: role,
    content: text,
    createdAt: createdAt,
    corrections: corrections,
    isVoice: isVoice,
  );
}

class Conversation {
  const Conversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const <ConversationMessage>[],
  });

  /// A fresh, empty conversation.
  factory Conversation.start({required String id, required DateTime now}) =>
      Conversation(id: id, createdAt: now, updatedAt: now);

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ConversationMessage> messages;

  bool get isEmpty => messages.isEmpty;

  /// The same conversation without its last message.
  Conversation withoutLast() => Conversation(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    messages: messages.sublist(0, messages.length - 1),
  );

  /// The same conversation with its last message replaced.
  Conversation withLast(ConversationMessage message) => Conversation(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    messages: [...messages.sublist(0, messages.length - 1), message],
  );

  Conversation addMessage(ConversationMessage message) => Conversation(
    id: id,
    createdAt: createdAt,
    updatedAt: message.createdAt,
    messages: [...messages, message],
  );
}

/// Persistence boundary for conversations. The local implementation uses
/// [LocalStorage]; a database or remote store can replace it without UI
/// changes.
abstract interface class ConversationRepository {
  /// All stored conversations, most recently updated first. Corrupt entries
  /// are skipped, never fatal.
  Future<Result<List<Conversation>>> loadAll();

  /// Inserts or replaces the conversation with the same id.
  Future<Result<void>> save(Conversation conversation);
}
