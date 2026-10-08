import 'package:parla_con_me/features/learning/domain/practice_evidence.dart';
import 'package:parla_con_me/features/learning/domain/language_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/domain/conversation.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/conversation/presentation/conversation_controller.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';

/// Counts memory reads, delegating to the real local repository.
class _CountingRepository implements LearningRepository {
  _CountingRepository(this._inner);
  final LearningRepository _inner;
  int summaryReads = 0;

  @override
  Future<Result<LearnerLearningSummary>> getLearningSummary() {
    summaryReads++;
    return _inner.getLearningSummary();
  }

  @override
  Future<Result<void>> recordError(LearningError o) => _inner.recordError(o);
  @override
  Future<Result<void>> recordVocabulary(UserVocabulary o) =>
      _inner.recordVocabulary(o);
  @override
  Future<Result<void>> recordGrammarTopicExposure(
    GrammarTopic t, {
    required DateTime at,
    bool wasError = false,
    String language = legacyLanguageCode,
  }) => _inner.recordGrammarTopicExposure(
    t,
    at: at,
    wasError: wasError,
    language: language,
  );
  @override
  Future<Result<void>> recordSuccessfulGrammarUse(
    GrammarTopic t, {
    required DateTime at,
    String language = legacyLanguageCode,
  }) => _inner.recordSuccessfulGrammarUse(t, at: at, language: language);
  @override
  Future<Result<bool>> applyPracticeEvidence(PracticeEvidence e) =>
      _inner.applyPracticeEvidence(e);
  @override
  Future<Result<void>> clearLearningData() => _inner.clearLearningData();
}

/// A memory the context builder will want to share: a recurring mistake in an
/// area still being reinforced, plus a word to reinforce. Dates are "now"
/// because the controller reads the real clock.
Future<void> _seedMemory(LocalLearningRepository repo) async {
  final now = DateTime.now();
  for (var i = 0; i < 2; i++) {
    await repo.recordError(
      LearningError(
        id: 'ho andato -> sono andato',
        category: LearningErrorCategory.grammar,
        original: 'ho andato',
        corrected: 'sono andato',
        grammarTopic: GrammarTopic.essereVsAvere,
        firstSeenAt: now,
        lastSeenAt: now,
        confidence: 0.9,
      ),
    );
    await repo.recordGrammarTopicExposure(
      GrammarTopic.essereVsAvere,
      at: now,
      wasError: true,
    );
  }
  await repo.recordVocabulary(UserVocabulary.of(word: 'prenotazione', at: now));
}

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

final _plainInstruction = buildTeacherInstruction(
  profile: UserLearningProfile.empty,
  correctionMode: false,
);

void main() {
  late InMemoryLocalStorage storage;

  setUp(() => storage = InMemoryLocalStorage());

  test(
    'with memory, the AI receives the selected context and the real history',
    () async {
      await _seedMemory(LocalLearningRepository(storage));
      final ai = FakeAIService();
      final c = _container(storage, ai);
      final controller = await _ready(c);

      await controller.send('Cosa hai fatto ieri?');
      await pumpEventQueue();

      final request = ai.requests.single;
      final instruction = request.systemInstruction!;
      expect(instruction, contains('LEARNING CONTEXT'));
      expect(
        instruction,
        contains('choosing essere or avere as the auxiliary verb'),
      );
      expect(instruction, contains('"ho andato" instead of "sono andato"'));
      expect(instruction, contains('- prenotazione'));
      expect(
        instruction,
        isNot(contains('ho andato -> sono andato')),
        reason: 'no internal id',
      );

      // Memory never replaces the conversation history.
      expect(request.messages.map((m) => (m.role, m.text)), [
        (AIRole.user, 'Cosa hai fatto ieri?'),
      ]);
    },
  );

  test('without memory it behaves exactly as before personalization', () async {
    final ai = FakeAIService();
    final c = _container(storage, ai);
    await (await _ready(c)).send('Ciao!');
    await pumpEventQueue();

    expect(ai.requests.single.systemInstruction, _plainInstruction);
    expect(
      ai.requests.single.systemInstruction,
      isNot(contains('LEARNING CONTEXT')),
    );
  });

  test('a memory with nothing worth sharing also sends nothing', () async {
    final repo = LocalLearningRepository(storage);
    // A single sighting of one mistake: occasional, no topic evidence yet.
    await repo.recordError(
      LearningError(
        id: 'la problema -> il problema',
        category: LearningErrorCategory.grammar,
        original: 'la problema',
        corrected: 'il problema',
        firstSeenAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
        confidence: 0.9,
      ),
    );
    final ai = FakeAIService();
    final c = _container(storage, ai);
    await (await _ready(c)).send('Ciao!');
    await pumpEventQueue();
    expect(ai.requests.single.systemInstruction, _plainInstruction);
  });

  group('when the memory cannot be read the chat goes on without it', () {
    Future<void> expectPlainChat(ProviderContainer c, FakeAIService ai) async {
      final state = c.read(conversationControllerProvider);
      expect(state.status, ConversationStatus.idle);
      expect(state.failure, isNull);
      expect(state.conversation.messages.map((m) => m.role), [
        MessageRole.user,
        MessageRole.assistant,
      ]);
      expect(ai.requests.single.systemInstruction, _plainInstruction);
    }

    test('repository failure', () async {
      final repository = FailingLearningRepository();
      final ai = FakeAIService();
      final c = _container(storage, ai, repository: repository);
      await (await _ready(c)).send('Ciao!');
      await pumpEventQueue();
      expect(repository.calls, greaterThan(0));
      await expectPlainChat(c, ai);
    });

    test('engine returns a failure', () async {
      final engine = FailingLearningEngine();
      final ai = FakeAIService();
      final c = _container(storage, ai, engine: engine);
      await (await _ready(c)).send('Ciao!');
      await pumpEventQueue();
      expect(engine.contextCalls, 1);
      await expectPlainChat(c, ai);
    });

    test('engine throws', () async {
      final engine = ThrowingLearningEngine();
      final ai = FakeAIService();
      final c = _container(storage, ai, engine: engine);
      await (await _ready(c)).send('Ciao!');
      await pumpEventQueue();
      expect(engine.contextCalls, 1);
      await expectPlainChat(c, ai);
    });

    test('a newer, unreadable memory document', () async {
      storage.data[LocalLearningRepository.storageKey] = '{"version": 99}';
      final ai = FakeAIService();
      final c = _container(storage, ai);
      await (await _ready(c)).send('Ciao!');
      await pumpEventQueue();
      await expectPlainChat(c, ai);
      expect(
        storage.data[LocalLearningRepository.storageKey],
        '{"version": 99}',
      );
    });
  });

  test('exactly one memory read builds the context of each request', () async {
    await _seedMemory(LocalLearningRepository(storage));
    final repository = _CountingRepository(LocalLearningRepository(storage));
    final readsWhenAIWasCalled = <int>[];
    late final FakeAIService ai;
    ai = FakeAIService(
      onRequest: (_) async {
        readsWhenAIWasCalled.add(repository.summaryReads);
        return const Success(AIResponse(message: 'Bene!'));
      },
    );
    final c = _container(storage, ai, repository: repository);
    final controller = await _ready(c);

    await controller.send('Primo messaggio');
    await pumpEventQueue();
    final afterFirst = repository.summaryReads;
    await controller.send('Secondo messaggio');
    await pumpEventQueue();

    expect(
      readsWhenAIWasCalled.first,
      1,
      reason: 'one read before the first AI call',
    );
    // Per turn: one read for the context + one for the learning analysis.
    expect(afterFirst, 2);
    expect(readsWhenAIWasCalled.last, afterFirst + 1);
    expect(repository.summaryReads, afterFirst + 2);
  });

  test(
    'an AI failure behaves as before and retry builds a fresh context',
    () async {
      await _seedMemory(LocalLearningRepository(storage));
      var failing = true;
      final ai = FakeAIService(
        onRequest: (_) async => failing
            ? const Failure(AIFailure('down', kind: AIFailureKind.network))
            : const Success(AIResponse(message: 'Eccomi!')),
      );
      final c = _container(storage, ai);
      final controller = await _ready(c);

      await controller.send('Ciao');
      expect(
        c.read(conversationControllerProvider).status,
        ConversationStatus.error,
      );
      expect(
        ai.requests.single.systemInstruction,
        contains('LEARNING CONTEXT'),
      );

      failing = false;
      await controller.retry();
      await pumpEventQueue();
      expect(
        c.read(conversationControllerProvider).status,
        ConversationStatus.idle,
      );
      expect(ai.requests, hasLength(2));
      expect(ai.requests.last.systemInstruction, contains('LEARNING CONTEXT'));
      expect(
        ai.requests.last.messages,
        hasLength(1),
        reason: 'retry did not duplicate the message',
      );
    },
  );

  test(
    'Correggimi is independent of memory, and the history window is unchanged',
    () async {
      await _seedMemory(LocalLearningRepository(storage));
      final ai = FakeAIService();
      final c = _container(storage, ai);
      final controller = await _ready(c);

      await controller.send('Uno');
      await pumpEventQueue();
      expect(ai.requests.last.systemInstruction, contains('LEARNING CONTEXT'));
      expect(
        ai.requests.last.systemInstruction,
        isNot(contains('CORRECTION MODE')),
      );

      controller.setCorrectionMode(enabled: true);
      await controller.send('Due');
      await pumpEventQueue();
      expect(ai.requests.last.systemInstruction, contains('LEARNING CONTEXT'));
      expect(
        ai.requests.last.systemInstruction,
        contains('CORRECTION MODE is ON'),
      );

      for (var i = 0; i < 20; i++) {
        await controller.send('msg $i');
      }
      await pumpEventQueue();
      expect(
        ai.requests.last.messages.length,
        lessThanOrEqualTo(ConversationController.maxContextMessages),
      );
    },
  );

  test(
    'the engine still learns from the personalized turn (the loop closes)',
    () async {
      await _seedMemory(LocalLearningRepository(storage));
      final engine = RecordingLearningEngine(
        context: const LearningContext(vocabularyToReinforce: ['prenotazione']),
      );
      final ai = FakeAIService();
      final c = _container(storage, ai, engine: engine);
      await (await _ready(c)).send('Ho fatto una prenotazione.');
      await pumpEventQueue();

      expect(engine.contextCalls, 1);
      expect(engine.analyzed.single.userMessage, 'Ho fatto una prenotazione.');
      expect(ai.requests.single.systemInstruction, contains('- prenotazione'));
    },
  );
}
