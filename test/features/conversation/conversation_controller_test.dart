import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/data/local_conversation_repository.dart';
import 'package:parla_con_me/features/conversation/domain/conversation.dart';
import 'package:parla_con_me/features/conversation/presentation/conversation_controller.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_controller.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';

class _Harness {
  _Harness({FakeAIService? ai, UserLearningProfile? profile})
    : storage = InMemoryLocalStorage(),
      ai = ai ?? FakeAIService(),
      engine = RecordingLearningEngine() {
    container = _build(profile);
  }

  final InMemoryLocalStorage storage;
  final FakeAIService ai;
  final RecordingLearningEngine engine;
  late ProviderContainer container;
  UserLearningProfile? _profile;

  ProviderContainer _build(UserLearningProfile? profile) {
    _profile = profile;
    final c = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        aiServiceProvider.overrideWithValue(ai),
        learningEngineProvider.overrideWithValue(engine),
        if (profile != null)
          userLearningProfileProvider.overrideWith(
            () => PreloadedUserLearningProfileController(profile),
          ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Simulates closing and reopening the app: new container, same storage.
  void restart() => container = _build(_profile);

  ConversationController get controller =>
      container.read(conversationControllerProvider.notifier);
  ConversationState get state => container.read(conversationControllerProvider);

  /// Waits for the initial load from storage.
  Future<void> ready() async {
    container.read(conversationControllerProvider);
    while (state.status == ConversationStatus.loading) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  test('loads empty, then send -> reply -> history, persisted', () async {
    final h = _Harness();
    await h.ready();
    expect(h.state.status, ConversationStatus.idle);
    expect(h.state.conversation.isEmpty, isTrue);

    await h.controller.send('  Ciao!  ');

    expect(h.state.status, ConversationStatus.idle);
    expect(h.state.failure, isNull);
    final messages = h.state.conversation.messages;
    expect(messages.map((m) => m.role), [
      MessageRole.user,
      MessageRole.assistant,
    ]);
    expect(messages.first.content, 'Ciao!', reason: 'trimmed');
    expect(messages.last.content, 'Bene! E poi?');

    final stored = (await LocalConversationRepository(
      h.storage,
    ).loadAll()).when(success: (c) => c, failure: (_) => <Conversation>[]);
    expect(stored.single.messages, hasLength(2));
  });

  test('the AI receives the full history and the learner profile', () async {
    final h = _Harness(
      profile: const UserLearningProfile(
        level: LanguageLevel.b1,
        goals: {LearningGoal.work},
        onboardingCompleted: true,
      ),
    );
    await h.ready();
    await h.controller.send('Ciao');
    await h.controller.send('Come stai?');

    final second = h.ai.requests.last;
    expect(second.messages.map((m) => (m.role, m.text)), [
      (AIRole.user, 'Ciao'),
      (AIRole.assistant, 'Bene! E poi?'),
      (AIRole.user, 'Come stai?'),
    ]);
    expect(second.systemInstruction, contains('Level B1'));
    expect(second.systemInstruction, contains('use Italian at work'));
    expect(second.systemInstruction, isNot(contains('CORRECTION MODE')));
  });

  test('Correggimi mode changes the instruction', () async {
    final h = _Harness();
    await h.ready();
    h.controller.setCorrectionMode(enabled: true);
    await h.controller.send('Ieri ho andato al supermercato.');
    expect(
      h.ai.requests.single.systemInstruction,
      contains('CORRECTION MODE is ON'),
    );
  });

  test(
    'corrections are kept on the assistant message and reported to the engine',
    () async {
      const correction = Correction(
        original: 'ho andato',
        corrected: 'sono andato',
        explanation: 'Con "andare" si usa "essere".',
        category: CorrectionCategory.grammar,
      );
      final h = _Harness(
        ai: FakeAIService(
          onRequest: (_) async => const Success(
            AIResponse(message: 'Quasi! 😊', corrections: [correction]),
          ),
        ),
      );
      await h.ready();
      await h.controller.send('Ieri ho andato al supermercato.');

      expect(h.state.conversation.messages.last.corrections, [correction]);
      await Future<void>.delayed(Duration.zero);
      expect(
        h.engine.analyzed.single.userMessage,
        'Ieri ho andato al supermercato.',
      );
      expect(h.engine.analyzed.single.response.corrections, [correction]);

      h.restart();
      await h.ready();
      expect(h.state.conversation.messages.last.corrections, [correction]);
    },
  );

  test(
    'a failure keeps the user message, shows an error, and retry recovers',
    () async {
      var fail = true;
      final h = _Harness(
        ai: FakeAIService(
          onRequest: (_) async => fail
              ? const Failure(AIFailure('boom', kind: AIFailureKind.network))
              : const Success(AIResponse(message: 'Eccomi!')),
        ),
      );
      await h.ready();
      await h.controller.send('Ciao');

      expect(h.state.status, ConversationStatus.error);
      expect((h.state.failure)!.kind, AIFailureKind.network);
      expect(h.state.conversation.messages.single.content, 'Ciao');
      expect(h.state.canRetry, isTrue);
      expect(h.engine.analyzed, isEmpty);

      fail = false;
      await h.controller.retry();

      expect(h.state.status, ConversationStatus.idle);
      expect(h.state.failure, isNull);
      expect(h.state.conversation.messages.map((m) => m.content), [
        'Ciao',
        'Eccomi!',
      ]);
      expect(
        h.ai.requests.last.messages.single.text,
        'Ciao',
        reason: 'retry did not duplicate the message',
      );
    },
  );

  test('duplicate sends while a reply is pending are ignored', () async {
    final gate = Completer<Result<AIResponse>>();
    final h = _Harness(ai: FakeAIService(onRequest: (_) => gate.future));
    await h.ready();

    final first = h.controller.send('Ciao');
    await Future<void>.delayed(Duration.zero);
    expect(h.state.status, ConversationStatus.sending);
    await h.controller.send('Ciao ciao');
    await h.controller.send('   ');
    h.controller.startNewConversation();

    gate.complete(const Success(AIResponse(message: 'Ciao!')));
    await first;

    expect(h.ai.requests, hasLength(1));
    expect(h.state.conversation.messages, hasLength(2));
  });

  test(
    'new conversation starts empty and keeps the previous one stored',
    () async {
      final h = _Harness();
      await h.ready();
      await h.controller.send('Prima');
      final firstId = h.state.conversation.id;

      h.controller.startNewConversation();
      expect(h.state.conversation.isEmpty, isTrue);
      expect(h.state.conversation.id, isNot(firstId));

      // Starting again while empty does nothing.
      final emptyId = h.state.conversation.id;
      h.controller.startNewConversation();
      expect(h.state.conversation.id, emptyId);

      await h.controller.send('Seconda');
      // The AI only sees the new conversation.
      expect(h.ai.requests.last.messages.map((m) => m.text), ['Seconda']);

      final all = (await LocalConversationRepository(
        h.storage,
      ).loadAll()).when(success: (c) => c, failure: (_) => <Conversation>[]);
      expect(
        all.map((c) => c.id),
        containsAll([firstId, h.state.conversation.id]),
      );
      expect(all, hasLength(2));
    },
  );

  test('reopening the app restores the most recent conversation', () async {
    final h = _Harness();
    await h.ready();
    await h.controller.send('Ciao');
    final id = h.state.conversation.id;

    h.restart();
    await h.ready();

    expect(h.state.conversation.id, id);
    expect(h.state.conversation.messages.map((m) => m.content), [
      'Ciao',
      'Bene! E poi?',
    ]);
    expect(h.state.status, ConversationStatus.idle);
  });

  test('reopening on an unanswered message offers retry', () async {
    var failing = true;
    final h = _Harness(
      ai: FakeAIService(
        onRequest: (_) async => failing
            ? const Failure(AIFailure('down', kind: AIFailureKind.network))
            : const Success(AIResponse(message: 'Eccomi!')),
      ),
    );
    await h.ready();
    await h.controller.send('Ciao');

    h.restart();
    await h.ready();
    expect(h.state.status, ConversationStatus.error);
    expect(h.state.canRetry, isTrue);

    failing = false;
    await h.controller.retry();
    expect(h.state.status, ConversationStatus.idle);
    expect(h.state.conversation.messages.last.content, 'Eccomi!');
  });

  test(
    'only the most recent messages are sent as context, starting with a user turn',
    () async {
      final h = _Harness();
      await h.ready();
      for (var i = 0; i < 20; i++) {
        await h.controller.send('msg $i');
      }
      final context = h.ai.requests.last.messages;
      expect(
        context.length,
        lessThanOrEqualTo(ConversationController.maxContextMessages),
      );
      expect(context.first.role, AIRole.user);
      expect(context.last.text, 'msg 19');
    },
  );
}
