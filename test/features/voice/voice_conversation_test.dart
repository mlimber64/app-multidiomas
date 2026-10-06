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
import '../../support/fake_voice.dart';
import '../../support/in_memory_local_storage.dart';

const _baseProfile = UserLearningProfile(
  level: LanguageLevel.a2,
  goals: {LearningGoal.work},
  focusAreas: {LearningFocus.conversation},
  onboardingCompleted: true,
);

class _Harness {
  _Harness({FakeAIService? ai, UserLearningProfile profile = _baseProfile})
    : ai = ai ?? FakeAIService(),
      _profile = profile,
      storage = InMemoryLocalStorage(),
      engine = RecordingLearningEngine(),
      speech = FakeSpeechService() {
    container = _build();
  }

  final InMemoryLocalStorage storage;
  final FakeAIService ai;
  final RecordingLearningEngine engine;
  final FakeSpeechService speech;
  final UserLearningProfile _profile;
  late ProviderContainer container;

  ProviderContainer _build() {
    final c = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        aiServiceProvider.overrideWithValue(ai),
        learningEngineProvider.overrideWithValue(engine),
        speechServiceProvider.overrideWithValue(speech),
        userLearningProfileProvider.overrideWith(
          () => PreloadedUserLearningProfileController(_profile),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Closing and reopening the app: new container, same storage.
  void restart() => container = _build();

  ConversationController get controller =>
      container.read(conversationControllerProvider.notifier);
  ConversationState get state => container.read(conversationControllerProvider);

  Future<void> ready() async {
    container.read(conversationControllerProvider);
    while (state.status == ConversationStatus.loading) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

FakeAIService _aiHearing(String transcript, {String reply = 'Bene! E poi?'}) =>
    FakeAIService(
      onRequest: (request) async => Success(
        AIResponse(
          message: reply,
          transcript: transcript,
          corrections: const [
            Correction(
              original: 'ho andato',
              corrected: 'sono andato',
              explanation: 'Con "andare" si usa "essere".',
              category: CorrectionCategory.grammar,
            ),
          ],
        ),
      ),
    );

void main() {
  test(
    'a voice message: the AI hears it, the transcript becomes its text',
    () async {
      final h = _Harness(ai: _aiHearing('Ieri ho andato al mare'));
      await h.ready();
      final clip = fakeClip();

      await h.controller.sendVoice(clip);

      final request = h.ai.requests.single;
      expect(request.messages.single.audio, same(clip));
      expect(request.messages.single.text, isEmpty);
      expect(request.systemInstruction, contains('VOICE MESSAGE'));

      final messages = h.state.conversation.messages;
      expect(messages.map((m) => m.role), [
        MessageRole.user,
        MessageRole.assistant,
      ]);
      expect(messages.first.isVoice, isTrue);
      expect(messages.first.content, 'Ieri ho andato al mare');
      expect(messages.last.corrections.single.corrected, 'sono andato');
      expect(h.state.status, ConversationStatus.idle);

      // The learning system works on what was said.
      expect(h.engine.analyzed.single.userMessage, 'Ieri ho andato al mare');
    },
  );

  test(
    'the reply to a voice message is read aloud, in the language learned',
    () async {
      final h = _Harness(ai: _aiHearing('Ciao', reply: 'Ciao! Come stai?'));
      await h.ready();
      await h.controller.sendVoice(fakeClip());
      await Future<void>.delayed(Duration.zero);

      expect(h.speech.spoken.single.text, 'Ciao! Come stai?');
      expect(h.speech.spoken.single.localeTag, 'it-IT');
    },
  );

  test(
    'a typed message is answered in silence, unless replies are read',
    () async {
      final quiet = _Harness();
      await quiet.ready();
      await quiet.controller.send('Ciao');
      await Future<void>.delayed(Duration.zero);
      expect(quiet.speech.spoken, isEmpty);

      final loud = _Harness(profile: _baseProfile.copyWith(speakReplies: true));
      await loud.ready();
      await loud.controller.send('Ciao');
      await Future<void>.delayed(Duration.zero);
      expect(loud.speech.spoken.single.text, 'Bene! E poi?');
    },
  );

  test(
    'nothing understood: the message stays empty and the teacher asks again',
    () async {
      final h = _Harness(ai: _aiHearing('', reply: 'Puoi ripetere?'));
      await h.ready();
      await h.controller.sendVoice(fakeClip());

      final voice = h.state.conversation.messages.first;
      expect(voice.isVoice, isTrue);
      expect(voice.content, isEmpty);
      expect(h.state.conversation.messages.last.content, 'Puoi ripetere?');

      // The next turn still takes the empty voice message as a turn.
      await h.controller.send('Sì, certo');
      final history = h.ai.requests.last.messages;
      expect(history.first.text, '(voice message)');
      expect(history.first.audio, isNull);
    },
  );

  test('the recording is sent once: later turns carry only text', () async {
    final h = _Harness(ai: _aiHearing('Ciao'));
    await h.ready();
    await h.controller.sendVoice(fakeClip());
    await h.controller.send('E tu?');

    final second = h.ai.requests.last.messages;
    expect(second.every((m) => m.audio == null), isTrue);
    expect(second.first.text, 'Ciao', reason: 'the transcript, not the audio');
    expect(
      h.ai.requests.last.systemInstruction,
      isNot(contains('VOICE MESSAGE')),
    );
  });

  test(
    'a failed voice message can be sent again with the same recording',
    () async {
      var calls = 0;
      final h = _Harness(
        ai: FakeAIService(
          onRequest: (request) async {
            calls++;
            return calls == 1
                ? const Failure(
                    AIFailure('offline', kind: AIFailureKind.network),
                  )
                : const Success(
                    AIResponse(message: 'Bene!', transcript: 'Ciao'),
                  );
          },
        ),
      );
      await h.ready();
      final clip = fakeClip();
      await h.controller.sendVoice(clip);

      expect(h.state.status, ConversationStatus.error);
      expect(h.state.canRetry, isTrue);
      expect(h.state.conversation.messages.single.content, isEmpty);

      await h.controller.retry();
      expect(h.ai.requests.last.messages.last.audio, same(clip));
      expect(h.state.status, ConversationStatus.idle);
      expect(h.state.conversation.messages.first.content, 'Ciao');
    },
  );

  test(
    'a voice message never answered is gone after the app restarts',
    () async {
      final h = _Harness(
        ai: FakeAIService(
          onRequest: (_) async =>
              const Failure(AIFailure('offline', kind: AIFailureKind.network)),
        ),
      );
      await h.ready();
      await h.controller.sendVoice(fakeClip());
      expect(h.state.status, ConversationStatus.error);

      h.restart();
      await h.ready();
      // The recording was never stored, so it cannot be sent again.
      expect(h.state.conversation.isEmpty, isTrue);
      expect(h.state.status, ConversationStatus.idle);
    },
  );

  test(
    'only the voice flag and the transcript are stored, never the audio',
    () async {
      final h = _Harness(ai: _aiHearing('Ciao'));
      await h.ready();
      await h.controller.sendVoice(fakeClip());

      final stored = (await LocalConversationRepository(
        h.storage,
      ).loadAll()).when(success: (c) => c, failure: (_) => <Conversation>[]);
      final first = stored.single.messages.first;
      expect(first.isVoice, isTrue);
      expect(first.content, 'Ciao');
      expect(h.storage.data['conversations'], isNot(contains('audio')));
      expect(h.storage.data['conversations'], isNot(contains('inlineData')));

      h.restart();
      await h.ready();
      expect(h.state.conversation.messages.first.isVoice, isTrue);
    },
  );

  test('a second voice message while one is pending is ignored', () async {
    final gate = Completer<void>();
    final h = _Harness(
      ai: FakeAIService(
        onRequest: (_) async {
          await gate.future;
          return const Success(AIResponse(message: 'Bene!', transcript: 'x'));
        },
      ),
    );
    await h.ready();
    final first = h.controller.sendVoice(fakeClip());
    await h.controller.sendVoice(fakeClip());
    gate.complete();
    await first;
    expect(h.ai.requests, hasLength(1));
  });
}
