import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../services/ai/ai_service.dart';
import '../../../services/audio/audio_clip.dart';
import '../../learning/domain/learning_context.dart';
import '../../learning/presentation/learning_providers.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../voice/presentation/speech_controller.dart';
import '../data/local_conversation_repository.dart';
import '../domain/conversation.dart';
import '../domain/conversation_scenario.dart';
import '../domain/teacher_prompt.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => LocalConversationRepository(ref.watch(localStorageProvider)),
);

final conversationControllerProvider =
    NotifierProvider<ConversationController, ConversationState>(
      ConversationController.new,
    );

enum ConversationStatus { loading, idle, sending, error }

class ConversationState {
  const ConversationState({
    required this.conversation,
    this.status = ConversationStatus.loading,
    this.correctionMode = false,
    this.failure,
    this.scenario,
    this.scenarioTurns = 0,
  });

  final Conversation conversation;
  final ConversationStatus status;

  /// "Correggimi": asks the teacher to correct more carefully. Per session,
  /// not persisted.
  final bool correctionMode;

  /// Set only while [status] is `error`.
  final AIFailure? failure;

  /// The situation this conversation is playing out (a daily-routine mission),
  /// if any, and how many messages the learner has written in it.
  final ConversationScenario? scenario;
  final int scenarioTurns;

  /// The learner has written enough for the scenario to be finished.
  bool get scenarioReady =>
      scenario != null && scenarioTurns >= scenario!.minTurns;

  bool get canSend =>
      status == ConversationStatus.idle || status == ConversationStatus.error;

  /// The last user message is still unanswered (an error happened), so
  /// retrying makes sense.
  bool get canRetry =>
      status == ConversationStatus.error &&
      conversation.messages.isNotEmpty &&
      conversation.messages.last.role == MessageRole.user;

  ConversationState copyWith({
    Conversation? conversation,
    ConversationStatus? status,
    bool? correctionMode,
    AIFailure? failure,
    ConversationScenario? scenario,
    bool clearScenario = false,
    int? scenarioTurns,
  }) => ConversationState(
    conversation: conversation ?? this.conversation,
    status: status ?? this.status,
    correctionMode: correctionMode ?? this.correctionMode,
    failure: failure,
    scenario: clearScenario ? null : (scenario ?? this.scenario),
    scenarioTurns: scenarioTurns ?? this.scenarioTurns,
  );
}

/// Orchestrates a conversation: it owns the state, history, persistence and
/// the teacher's behavior (through the prompt builder), and uses [AIService]
/// only as a text-in/reply-out capability.
class ConversationController extends Notifier<ConversationState> {
  /// How many recent messages are sent to the AI as context.
  static const maxContextMessages = 24;

  int _idCounter = 0;

  /// The recording of the voice message waiting for its reply. Kept only in
  /// memory so a failed request can be retried; never stored.
  AudioClip? _pendingAudio;

  @override
  ConversationState build() {
    _initialLoad = Future.microtask(_loadLatest);
    return ConversationState(conversation: _newConversation());
  }

  /// The first read of the stored conversation, started with the controller.
  Future<void>? _initialLoad;

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  Conversation _newConversation() =>
      Conversation.start(id: _newId(), now: DateTime.now());

  Future<void> _loadLatest() async {
    final loaded = await ref.read(conversationRepositoryProvider).loadAll();
    // Ignore a late result if the user already started typing/sending.
    if (state.status != ConversationStatus.loading) return;
    final latest = loaded.when(
      success: (all) => all.where((c) => !c.isEmpty).firstOrNull,
      failure: (_) => null,
    );
    // A voice message that never got its reply cannot be sent again once the
    // app was closed (the recording was never stored): it is dropped.
    var restored = latest;
    if (restored != null &&
        restored.messages.last.role == MessageRole.user &&
        restored.messages.last.isVoice &&
        restored.messages.last.content.isEmpty) {
      restored = restored.messages.length == 1 ? null : restored.withoutLast();
    }
    // A conversation that ended on an unanswered user message (the reply
    // failed, or the app closed mid-request) offers retry on reopening.
    final unanswered =
        restored != null && restored.messages.last.role == MessageRole.user;
    state = state.copyWith(
      conversation: restored,
      status: unanswered ? ConversationStatus.error : ConversationStatus.idle,
      failure: unanswered
          ? const AIFailure('The last message never received a reply')
          : null,
    );
  }

  void setCorrectionMode({required bool enabled}) =>
      state = state.copyWith(correctionMode: enabled, failure: state.failure);

  /// Starts a fresh conversation. Previous ones stay stored. Ignored while a
  /// reply is pending and when the current conversation is already empty.
  void startNewConversation() {
    if (state.status == ConversationStatus.sending ||
        state.status == ConversationStatus.loading ||
        state.conversation.isEmpty) {
      return;
    }
    _pendingAudio = null;
    state = ConversationState(
      conversation: _newConversation(),
      status: ConversationStatus.idle,
      correctionMode: state.correctionMode,
    );
  }

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || !state.canSend) return;

    final conversation = state.conversation.addMessage(
      ConversationMessage(
        id: _newId(),
        role: MessageRole.user,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
    state = state.copyWith(
      conversation: conversation,
      status: ConversationStatus.sending,
      scenarioTurns: state.scenario == null ? null : state.scenarioTurns + 1,
    );
    await _persist(conversation);
    await _requestReply(conversation);
  }

  /// Starts a fresh conversation that plays out [scenario]: the teacher sets
  /// the scene and speaks first. Everything else is the usual conversation
  /// (corrections, learning, voice). Returns `false` when it cannot start now
  /// or when this same scenario is already under way (nothing is lost).
  Future<bool> startScenario(ConversationScenario scenario) async {
    // The conversation may not have been opened yet since the app started:
    // let it finish reading what is stored before replacing it.
    await _initialLoad;
    if (!ref.mounted) return false;
    if (state.status == ConversationStatus.sending ||
        state.status == ConversationStatus.loading) {
      return false;
    }
    if (state.scenario?.id == scenario.id) return false;
    _pendingAudio = null;
    final conversation = _newConversation();
    state = ConversationState(
      conversation: conversation,
      status: ConversationStatus.sending,
      correctionMode: state.correctionMode,
      scenario: scenario,
    );
    await _requestReply(conversation, opening: true);
    return true;
  }

  /// The scenario is over: the conversation goes on as a normal one.
  void finishScenario() =>
      state = state.copyWith(clearScenario: true, scenarioTurns: 0);

  /// Sends a recorded voice message: the AI listens to it, answers, and tells
  /// what it heard (the transcript becomes the message's text). The recording
  /// is sent once and not kept.
  Future<void> sendVoice(AudioClip clip) async {
    if (!state.canSend) return;
    final conversation = state.conversation.addMessage(
      ConversationMessage(
        id: _newId(),
        role: MessageRole.user,
        content: '',
        createdAt: DateTime.now(),
        isVoice: true,
      ),
    );
    _pendingAudio = clip;
    state = state.copyWith(
      conversation: conversation,
      status: ConversationStatus.sending,
      scenarioTurns: state.scenario == null ? null : state.scenarioTurns + 1,
    );
    await _persist(conversation);
    await _requestReply(conversation, audio: clip);
  }

  /// Re-asks for a reply to the last unanswered user message.
  Future<void> retry() async {
    if (!state.canRetry) return;
    final conversation = state.conversation;
    state = state.copyWith(status: ConversationStatus.sending);
    await _requestReply(conversation, audio: _pendingAudio);
  }

  Future<void> _requestReply(
    Conversation conversation, {
    AudioClip? audio,
    bool opening = false,
  }) async {
    final profile = ref.read(userLearningProfileProvider);
    final request = AIRequest(
      messages: opening
          ? const [AIMessage(role: AIRole.user, text: scenarioOpeningTrigger)]
          : _contextFor(conversation, audio: audio),
      systemInstruction: buildTeacherInstruction(
        profile: profile,
        correctionMode: state.correctionMode,
        learningContext: await _learningContextOrEmpty(),
        voiceMessage: audio != null,
        scenario: state.scenario?.instruction,
      ),
    );
    final result = await ref.read(aiServiceProvider).sendConversation(request);

    switch (result) {
      case Failure() when opening:
        // The teacher could not open the scene: the learner can just write
        // the first message, and the scenario still guides every reply.
        state = state.copyWith(status: ConversationStatus.idle);
      case Failure(:final failure):
        state = state.copyWith(
          status: ConversationStatus.error,
          failure: failure is AIFailure ? failure : AIFailure(failure.message),
        );
      case Success(value: final response):
        _pendingAudio = null;
        // What the AI heard becomes the text of the voice message.
        final heard = response.transcript;
        final asked = audio != null && heard != null
            ? conversation.withLast(
                conversation.messages.last.withContent(heard),
              )
            : conversation;
        final updated = asked.addMessage(
          ConversationMessage(
            id: _newId(),
            role: MessageRole.assistant,
            content: response.message,
            createdAt: DateTime.now(),
            corrections: response.corrections,
            translation: response.translation,
          ),
        );
        state = state.copyWith(
          conversation: updated,
          status: ConversationStatus.idle,
        );
        await _persist(updated);
        // The opening is the teacher's alone: there is nothing of the learner's
        // to learn from yet.
        if (!opening) {
          unawaited(
            _learnFrom(
              asked.messages.last.content,
              response,
              contextId: 'conversation:${conversation.id}',
            ),
          );
        }
        // A reply to a voice message is spoken; a typed one only if the
        // learner asked for replies to be read aloud.
        if (audio != null || profile.speakReplies) {
          unawaited(
            ref
                .read(speechControllerProvider.notifier)
                .speak(
                  key: speechKeyOf(updated.messages.last.id),
                  text: response.message,
                  language: profile.learningLanguage,
                ),
          );
        }
    }
  }

  /// The slice of learner memory to personalize this request: one memory read.
  /// Personalization is an optional layer, so if the memory cannot be read (a
  /// failed result or an unexpected exception) the request simply goes without
  /// it, exactly like a learner with no memory, and the user never sees an
  /// error.
  Future<LearningContext> _learningContextOrEmpty() async {
    try {
      final result = await ref.read(learningEngineProvider).learningContext();
      switch (result) {
        case Success(value: final context):
          return context;
        case Failure(:final failure):
          _logLearningFailure(failure.runtimeType);
      }
    } catch (error) {
      _logLearningFailure(error.runtimeType);
    }
    return LearningContext.empty;
  }

  /// Learning is a secondary layer: whatever happens here (a failed result or
  /// an unexpected exception) must never affect the conversation, which is
  /// already updated and shown by the time this runs. Only the kind of
  /// failure is logged, in debug builds, never message content.
  Future<void> _learnFrom(
    String userMessage,
    AIResponse response, {
    required String contextId,
  }) async {
    try {
      final result = await ref
          .read(learningEngineProvider)
          .analyze(
            userMessage: userMessage,
            response: response,
            contextId: contextId,
          );
      if (result case Failure(:final failure)) {
        _logLearningFailure(failure.runtimeType);
      }
    } catch (error) {
      _logLearningFailure(error.runtimeType);
    }
    // The learning engine moves `learningRevisionProvider` itself when it
    // really changes the memory.
  }

  void _logLearningFailure(Type kind) {
    if (kDebugMode) debugPrint('Learning analysis failed: $kind');
  }

  /// The most recent messages as AI context. Must start with a user turn.
  List<AIMessage> _contextFor(Conversation conversation, {AudioClip? audio}) {
    final recent = conversation.messages
        .where((m) => m.role != MessageRole.system)
        .toList();
    final window = recent.length > maxContextMessages
        ? recent.sublist(recent.length - maxContextMessages)
        : recent;
    final firstUser = window.indexWhere((m) => m.role == MessageRole.user);
    // A conversation the teacher opened (a scenario) starts with the teacher:
    // the request still has to start with a learner turn.
    final teacherOpened =
        recent.isNotEmpty &&
        window.length == recent.length &&
        window.first.role == MessageRole.assistant;
    return [
      if (teacherOpened)
        const AIMessage(role: AIRole.user, text: scenarioOpeningTrigger),
      for (final m
          in teacherOpened
              ? window
              : (firstUser < 0
                    ? <ConversationMessage>[]
                    : window.skip(firstUser)))
        AIMessage(
          role: m.role == MessageRole.user ? AIRole.user : AIRole.assistant,
          // A voice message whose words were never understood still takes
          // its turn, but says nothing.
          text: m.content.isEmpty && m.isVoice && m != window.last
              ? '(voice message)'
              : m.content,
          audio: m == window.last ? audio : null,
        ),
    ];
  }

  /// Persistence problems must not interrupt the chat: the conversation stays
  /// usable in memory and is saved again after the next turn.
  Future<void> _persist(Conversation conversation) async {
    await ref.read(conversationRepositoryProvider).save(conversation);
  }
}
