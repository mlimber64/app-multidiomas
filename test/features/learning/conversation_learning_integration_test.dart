import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/data/local_conversation_repository.dart';
import 'package:parla_con_me/features/conversation/domain/conversation.dart';
import 'package:parla_con_me/features/conversation/presentation/conversation_controller.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';

const _correction = Correction(
  original: 'Ieri ho andato al supermercato.',
  corrected: 'Ieri sono andato al supermercato.',
  explanation: 'Con "andare" si usa "essere".',
  category: CorrectionCategory.grammar,
);

FakeAIService _aiWithCorrection() => FakeAIService(
  onRequest: (_) async => const Success(
    AIResponse(message: 'Quasi! 😊', corrections: [_correction]),
  ),
);

ProviderContainer _container(
  InMemoryLocalStorage storage,
  FakeAIService ai, {
  LearningEngine? engine,
  LearningRepository? repository,
}) {
  final c = ProviderContainer(
    overrides: [
      localStorageProvider.overrideWithValue(storage),
      aiServiceProvider.overrideWithValue(ai),
      if (engine != null) learningEngineProvider.overrideWithValue(engine),
      if (repository != null)
        learningRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<ConversationController> _ready(ProviderContainer c) async {
  c.read(conversationControllerProvider);
  while (c.read(conversationControllerProvider).status ==
      ConversationStatus.loading) {
    await Future<void>.delayed(Duration.zero);
  }
  return c.read(conversationControllerProvider.notifier);
}

Future<LearnerLearningSummary> _memory(InMemoryLocalStorage storage) async =>
    (await LocalLearningRepository(
      storage,
    ).getLearningSummary()).when(success: (s) => s, failure: (f) => fail('$f'));

void main() {
  test('error -> recovery through the chat: one AI call per message, success '
      'detected from the learner\'s next message', () async {
    final storage = InMemoryLocalStorage();
    var calls = 0;
    final ai = FakeAIService(
      onRequest: (_) async {
        calls++;
        // Only the first reply corrects; later replies are plain.
        return Success(
          calls == 1
              ? const AIResponse(
                  message: 'Quasi! 😊',
                  corrections: [_correction],
                )
              : const AIResponse(message: 'Bene! E poi?'),
        );
      },
    );
    final c = _container(storage, ai);
    final controller = await _ready(c);

    await controller.send('Ieri ho andato al supermercato.');
    await pumpEventQueue();
    await controller.send('Ieri sono andato al lavoro.');
    await pumpEventQueue();
    await controller.send('Ieri sono andato a scuola.');
    await pumpEventQueue();

    expect(calls, 3, reason: 'learning never makes an extra AI call');
    final memory = await _memory(storage);
    final topic = memory.grammarTopics.firstWhere(
      (t) => t.topic == GrammarTopic.essereVsAvere,
    );
    expect(topic.errorCount, 1);
    expect(topic.successfulUseCount, 2);
    expect(topic.exposureCount, 3);
    expect(memory.errors.single.frequency, 1);
  });

  test('a broken learning repository never breaks the chat', () async {
    final storage = InMemoryLocalStorage();
    final repository = FailingLearningRepository();
    final c = _container(storage, _aiWithCorrection(), repository: repository);
    final controller = await _ready(c);

    await controller.send('Ieri ho andato al supermercato.');
    await pumpEventQueue();
    await controller.send('Ieri sono andato al lavoro.');
    await pumpEventQueue();

    expect(repository.calls, greaterThan(0), reason: 'the engine did try');
    final state = c.read(conversationControllerProvider);
    expect(state.status, ConversationStatus.idle);
    expect(state.failure, isNull);
    expect(state.conversation.messages, hasLength(4));
    final stored = (await LocalConversationRepository(
      storage,
    ).loadAll()).when(success: (l) => l, failure: (_) => <Conversation>[]);
    expect(stored.single.messages, hasLength(4));
  });

  test(
    'Gemini correction -> engine -> repository -> persisted memory',
    () async {
      final storage = InMemoryLocalStorage();
      final c = _container(storage, _aiWithCorrection());
      final controller = await _ready(c);

      await controller.send('Ieri ho andato al supermercato.');
      await pumpEventQueue();

      // The chat shows the reply and its correction card data.
      final messages = c
          .read(conversationControllerProvider)
          .conversation
          .messages;
      expect(
        messages.last.corrections.single.corrected,
        contains('sono andato'),
      );

      final memory = await _memory(storage);
      expect(memory.totalErrors, 1);
      expect(
        memory.grammarTopics.map((t) => t.topic),
        containsAll([GrammarTopic.essereVsAvere, GrammarTopic.passatoProssimo]),
      );
    },
  );

  test(
    'the memory survives a restart and a repeated mistake raises the frequency',
    () async {
      final storage = InMemoryLocalStorage();

      var c = _container(storage, _aiWithCorrection());
      await (await _ready(c)).send('Ieri ho andato al supermercato.');
      await pumpEventQueue();
      c.dispose();

      // "Reopen the app": new container, same storage.
      c = _container(storage, _aiWithCorrection());
      expect(
        (await _memory(storage)).totalErrors,
        1,
        reason: 'memory persisted',
      );
      await (await _ready(c)).send('Oggi ho andato a scuola.');
      await pumpEventQueue();

      final memory = await _memory(storage);
      expect(memory.totalErrors, 2);
      final error = memory.recurringErrors.single;
      expect(error.id, 'ho andato -> sono andato');
      expect(error.frequency, 2, reason: 'one record, not a duplicate');
      for (final t in memory.grammarTopics) {
        expect(t.exposureCount, 2);
      }
    },
  );

  test('a reply without corrections leaves the memory untouched', () async {
    final storage = InMemoryLocalStorage();
    final c = _container(storage, FakeAIService());
    await (await _ready(c)).send('Ciao!');
    await pumpEventQueue();
    expect((await _memory(storage)).totalErrors, 0);
    expect(
      storage.data.containsKey(LocalLearningRepository.storageKey),
      isFalse,
    );
  });

  group('the learning layer never breaks the conversation', () {
    Future<void> expectChatIntact(
      ProviderContainer c,
      InMemoryLocalStorage storage,
    ) async {
      final state = c.read(conversationControllerProvider);
      expect(state.status, ConversationStatus.idle);
      expect(state.failure, isNull);
      expect(state.conversation.messages.map((m) => m.role), [
        MessageRole.user,
        MessageRole.assistant,
      ]);
      // And it was saved: a later message still works.
      final stored = (await LocalConversationRepository(
        storage,
      ).loadAll()).when(success: (l) => l, failure: (_) => <Conversation>[]);
      expect(stored.single.messages, hasLength(2));
    }

    test('when the engine returns a failure', () async {
      final storage = InMemoryLocalStorage();
      final engine = FailingLearningEngine();
      final c = _container(storage, _aiWithCorrection(), engine: engine);
      final controller = await _ready(c);

      await controller.send('Ieri ho andato al supermercato.');
      await pumpEventQueue();

      expect(engine.calls, 1);
      await expectChatIntact(c, storage);
      await controller.send('Un altro messaggio.');
      await pumpEventQueue();
      expect(
        c.read(conversationControllerProvider).conversation.messages,
        hasLength(4),
      );
    });

    test('when the engine throws', () async {
      final storage = InMemoryLocalStorage();
      final engine = ThrowingLearningEngine();
      final c = _container(storage, _aiWithCorrection(), engine: engine);
      final controller = await _ready(c);

      await controller.send('Ieri ho andato al supermercato.');
      await pumpEventQueue();

      expect(engine.calls, 1);
      await expectChatIntact(c, storage);
      await controller.send('Un altro messaggio.');
      await pumpEventQueue();
      expect(engine.calls, 2);
      expect(
        c.read(conversationControllerProvider).conversation.messages,
        hasLength(4),
      );
    });

    test('when the learning storage is broken but chat storage works', () async {
      final storage = InMemoryLocalStorage();
      // A corrupt-but-newer learning document makes every learning write fail.
      storage.data[LocalLearningRepository.storageKey] = '{"version": 99}';
      final c = _container(storage, _aiWithCorrection());
      await (await _ready(c)).send('Ieri ho andato al supermercato.');
      await pumpEventQueue();

      await expectChatIntact(c, storage);
      expect(
        storage.data[LocalLearningRepository.storageKey],
        '{"version": 99}',
      );
    });
  });
}
