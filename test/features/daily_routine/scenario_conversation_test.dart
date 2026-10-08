import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/domain/conversation_scenario.dart';
import 'package:parla_con_me/features/conversation/presentation/conversation_controller.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_controller.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';

const _scenario = ConversationScenario(
  id: 'cafe:',
  title: 'At the café',
  instruction: 'SCENARIO MISSION: play the waiter.',
);

const _profile = UserLearningProfile(
  level: LanguageLevel.a2,
  goals: {LearningGoal.work},
  focusAreas: {LearningFocus.conversation},
  onboardingCompleted: true,
);

void main() {
  late FakeAIService ai;
  late ProviderContainer container;

  ConversationController controller() =>
      container.read(conversationControllerProvider.notifier);
  ConversationState state() => container.read(conversationControllerProvider);

  setUp(() async {
    ai = FakeAIService();
    container = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(InMemoryLocalStorage()),
        aiServiceProvider.overrideWithValue(ai),
        learningEngineProvider.overrideWithValue(RecordingLearningEngine()),
        userLearningProfileProvider.overrideWith(
          () => PreloadedUserLearningProfileController(_profile),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(conversationControllerProvider);
    while (state().status == ConversationStatus.loading) {
      await Future<void>.delayed(Duration.zero);
    }
  });

  test(
    'the teacher speaks first, with the mission in its instruction',
    () async {
      expect(await controller().startScenario(_scenario), isTrue);

      expect(ai.requests, hasLength(1));
      final request = ai.requests.single;
      expect(request.messages.single.text, scenarioOpeningTrigger);
      expect(request.systemInstruction, contains('SCENARIO MISSION'));

      final s = state();
      expect(s.scenario, _scenario);
      expect(s.status, ConversationStatus.idle);
      // The hidden trigger is never shown or stored: only the teacher's line is.
      expect(s.conversation.messages, hasLength(1));
      expect(s.conversation.messages.single.content, 'Bene! E poi?');
    },
  );

  test(
    'it is the usual conversation: one AI call per learner message',
    () async {
      await controller().startScenario(_scenario);
      await controller().send('Un caffè, per favore');

      expect(
        ai.requests,
        hasLength(2),
        reason: 'no extra call for the scenario',
      );
      final reply = ai.requests.last;
      expect(reply.systemInstruction, contains('SCENARIO MISSION'));
      expect(
        reply.messages.map((m) => m.text),
        contains('Un caffè, per favore'),
      );
      // The teacher's opening is context for the reply; the trigger is not.
      expect(reply.messages.first.text, scenarioOpeningTrigger);
    },
  );

  test('it is ready to finish after the minimum number of messages', () async {
    await controller().startScenario(_scenario);
    expect(state().scenarioReady, isFalse);
    await controller().send('Ciao');
    expect(state().scenarioReady, isFalse);
    await controller().send('Un caffè');
    expect(state().scenarioTurns, 2);
    expect(state().scenarioReady, isTrue);
  });

  test('finishing ends the scenario and the chat goes on as usual', () async {
    await controller().startScenario(_scenario);
    await controller().send('Ciao');
    await controller().send('Un caffè');
    controller().finishScenario();
    expect(state().scenario, isNull);
    expect(state().scenarioTurns, 0);
    expect(state().conversation.messages, isNotEmpty, reason: 'nothing lost');

    await controller().send('Grazie');
    expect(ai.requests.last.systemInstruction, isNot(contains('SCENARIO')));
  });

  test('the same scenario under way is not started twice', () async {
    await controller().startScenario(_scenario);
    await controller().send('Ciao');
    expect(await controller().startScenario(_scenario), isFalse);
    expect(ai.requests, hasLength(2));
    expect(state().scenarioTurns, 1, reason: 'progress kept');
  });

  test('a different scenario starts a fresh conversation', () async {
    await controller().startScenario(_scenario);
    await controller().send('Ciao');
    const other = ConversationScenario(
      id: 'shopping:',
      title: 'Shopping',
      instruction: 'SCENARIO MISSION: shop.',
    );
    expect(await controller().startScenario(other), isTrue);
    expect(state().scenario, other);
    expect(state().scenarioTurns, 0);
    expect(state().conversation.messages, hasLength(1));
  });

  test('if the teacher cannot open, the learner can start writing', () async {
    ai.onRequest = (_) async => const Failure(AIFailure('offline'));
    await controller().startScenario(_scenario);
    expect(state().status, ConversationStatus.idle);
    expect(state().scenario, _scenario);
    expect(state().conversation.messages, isEmpty);

    ai.onRequest = (_) async => const Success(AIResponse(message: 'Prego!'));
    await controller().send('Ciao');
    expect(ai.requests.last.systemInstruction, contains('SCENARIO MISSION'));
    expect(state().status, ConversationStatus.idle);
  });
}
