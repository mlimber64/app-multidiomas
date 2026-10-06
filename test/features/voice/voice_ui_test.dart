import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/services/audio/voice_recorder.dart';
import 'package:parla_con_me/services/speech/speech_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/fake_ai_service.dart';
import '../../support/fake_voice.dart';
import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

class _Chat {
  _Chat({String? transcript})
    : ai = FakeAIService(
        onRequest: (request) async => Success(
          AIResponse(
            message: 'Quasi! Dove sei andato?',
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

  final FakeAIService ai;
  final speech = FakeSpeechService();
  final recorder = FakeVoiceRecorder();
  final storage = InMemoryLocalStorage();

  Future<void> open(WidgetTester tester) async {
    await pumpApp(
      tester,
      storage,
      profile: onboardedProfile,
      overrides: [
        aiServiceProvider.overrideWithValue(ai),
        learningEngineProvider.overrideWithValue(RecordingLearningEngine()),
        speechServiceProvider.overrideWithValue(speech),
        voiceRecorderProvider.overrideWithValue(recorder),
      ],
    );
    // A tall screen: correction cards with their buttons are long, and these
    // tests are about the buttons, not about scrolling.
    tester.view.physicalSize = const Size(1080, 3600);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Parla'),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Sends a typed message so there is a reply with a correction on screen.
  Future<void> exchange(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'Ieri ho andato al mare');
    await tester.pump();
    await tester.tap(find.byTooltip('Invia'));
    await tester.pumpAndSettle();
  }
}

Finder _textButton(String label) => find.widgetWithText(TextButton, label);

void main() {
  group('listening to the teacher and to the corrections', () {
    testWidgets('a correction offers to hear how it is said and written', (
      tester,
    ) async {
      final chat = _Chat();
      await chat.open(tester);
      await chat.exchange(tester);

      expect(
        find.text('Ascolta come si dice e si scrive correttamente:'),
        findsOneWidget,
      );
      expect(_textButton('Ascolta'), findsOneWidget);
      expect(_textButton('Piano'), findsOneWidget);
      expect(_textButton('Compita'), findsOneWidget);
    });

    testWidgets('each button reads the corrected text its own way', (
      tester,
    ) async {
      final chat = _Chat();
      await chat.open(tester);
      await chat.exchange(tester);

      for (final label in ['Ascolta', 'Piano', 'Compita']) {
        await tester.ensureVisible(_textButton(label));
        await tester.tap(_textButton(label));
        await tester.pumpAndSettle();
      }

      final spoken = chat.speech.spoken;
      expect(spoken, hasLength(3));
      expect(spoken[0].text, 'sono andato');
      expect(spoken[0].pace, SpeechPace.normal);
      expect(spoken[1].text, 'sono andato');
      expect(spoken[1].pace, SpeechPace.slow);
      expect(spoken[2].text, 's, o, n, o. a, n, d, a, t, o');
      expect(spoken[2].pace, SpeechPace.slow);
      // The voice is the one of the language being learned.
      expect(spoken.map((s) => s.localeTag).toSet(), {'it-IT'});
    });

    testWidgets('the teacher\'s message can be heard, and stopped', (
      tester,
    ) async {
      final chat = _Chat()..speech.hold = Completer<void>();
      await chat.open(tester);
      await chat.exchange(tester);

      await tester.tap(find.byTooltip('Ascolta il messaggio'));
      await tester.pump();
      expect(chat.speech.spoken.single.text, 'Quasi! Dove sei andato?');
      // While it is read the button offers to stop, and only that one.
      expect(find.byTooltip('Ferma'), findsOneWidget);

      await tester.tap(find.byTooltip('Ferma'));
      await tester.pumpAndSettle();
      expect(chat.speech.stops, greaterThan(0));
      expect(find.byTooltip('Ferma'), findsNothing);
      expect(find.byTooltip('Ascolta il messaggio'), findsOneWidget);
    });

    testWidgets('a phone with no voice for the language says what to do', (
      tester,
    ) async {
      final chat = _Chat();
      chat.speech.outcome = SpeechOutcome.noVoice;
      await chat.open(tester);
      await chat.exchange(tester);

      await tester.ensureVisible(_textButton('Ascolta'));
      await tester.tap(_textButton('Ascolta'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Il telefono non ha una voce installata'),
        findsOneWidget,
      );
    });

    testWidgets('a failure to play is friendly', (tester) async {
      final chat = _Chat();
      chat.speech.outcome = SpeechOutcome.failed;
      await chat.open(tester);
      await chat.exchange(tester);

      await tester.ensureVisible(_textButton('Ascolta'));
      await tester.tap(_textButton('Ascolta'));
      await tester.pumpAndSettle();
      expect(
        find.text('Non sono riuscito a riprodurre l’audio.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'replies read aloud: a switch in the chat, kept in the profile',
      (tester) async {
        final chat = _Chat();
        await chat.open(tester);

        await chat.exchange(tester);
        await tester.pump();
        expect(chat.speech.spoken, isEmpty, reason: 'off by default');

        await tester.tap(find.byTooltip('Leggi le risposte ad alta voce'));
        await tester.pumpAndSettle();
        final stored =
            jsonDecode(chat.storage.data['user_learning_profile']!)
                as Map<String, dynamic>;
        expect(stored['speakReplies'], isTrue);

        await chat.exchange(tester);
        await tester.pump();
        expect(chat.speech.spoken.single.text, 'Quasi! Dove sei andato?');
      },
    );
  });

  group('speaking to the teacher', () {
    testWidgets('the microphone is offered while nothing is typed', (
      tester,
    ) async {
      final chat = _Chat();
      await chat.open(tester);
      expect(find.byTooltip('Registra un messaggio vocale'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Ciao');
      await tester.pump();
      expect(find.byTooltip('Registra un messaggio vocale'), findsNothing);
    });

    testWidgets('record, send: the teacher hears it and the words appear', (
      tester,
    ) async {
      final chat = _Chat(transcript: 'Ieri ho andato al mare');
      await chat.open(tester);

      await tester.tap(find.byTooltip('Registra un messaggio vocale'));
      await tester.pump();
      expect(chat.recorder.starts, 1);
      expect(find.textContaining('Registrazione in corso'), findsOneWidget);
      expect(find.byTooltip('Invia'), findsNothing, reason: 'recording bar');

      await tester.tap(find.byTooltip('Invia il messaggio vocale'));
      await tester.pumpAndSettle();

      expect(chat.recorder.stops, 1);
      expect(chat.ai.requests.single.messages.single.audio, isNotNull);
      // What was heard is the text of the message, with a microphone.
      expect(find.text('Ieri ho andato al mare'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      // The reply is spoken because the learner spoke.
      expect(chat.speech.spoken.single.text, 'Quasi! Dove sei andato?');
      // Back to typing.
      expect(find.byTooltip('Invia'), findsOneWidget);
    });

    testWidgets('cancelling throws the recording away', (tester) async {
      final chat = _Chat();
      await chat.open(tester);

      await tester.tap(find.byTooltip('Registra un messaggio vocale'));
      await tester.pump();
      await tester.tap(find.byTooltip('Annulla la registrazione'));
      await tester.pumpAndSettle();

      expect(chat.recorder.cancels, 1);
      expect(chat.ai.requests, isEmpty);
      expect(find.byTooltip('Registra un messaggio vocale'), findsOneWidget);
    });

    testWidgets('starting to record silences the teacher', (tester) async {
      final chat = _Chat();
      await chat.open(tester);
      await tester.tap(find.byTooltip('Registra un messaggio vocale'));
      await tester.pump();
      expect(chat.speech.stops, greaterThan(0));
    });

    testWidgets('without the microphone permission, it is explained', (
      tester,
    ) async {
      final chat = _Chat();
      chat.recorder.startOutcome = RecordingStart.permissionDenied;
      await chat.open(tester);

      await tester.tap(find.byTooltip('Registra un messaggio vocale'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mi serve il permesso'), findsOneWidget);
      expect(find.byTooltip('Registra un messaggio vocale'), findsOneWidget);
      expect(chat.ai.requests, isEmpty);
    });

    testWidgets('a recording that could not start says so', (tester) async {
      final chat = _Chat();
      chat.recorder.startOutcome = RecordingStart.failed;
      await chat.open(tester);

      await tester.tap(find.byTooltip('Registra un messaggio vocale'));
      await tester.pumpAndSettle();
      expect(
        find.text('Non sono riuscito a iniziare a registrare.'),
        findsOneWidget,
      );
    });

    testWidgets('a recording that is too short is not sent', (tester) async {
      final chat = _Chat();
      chat.recorder.clip = null;
      await chat.open(tester);

      await tester.tap(find.byTooltip('Registra un messaggio vocale'));
      await tester.pump();
      await tester.tap(find.byTooltip('Invia il messaggio vocale'));
      await tester.pumpAndSettle();

      expect(find.textContaining('troppo breve'), findsOneWidget);
      expect(chat.ai.requests, isEmpty);
    });

    testWidgets('pronunciation corrections can be heard like any other', (
      tester,
    ) async {
      final chat = _Chat(transcript: 'Vado al mare');
      chat.ai.onRequest = (_) async => const Success(
        AIResponse(
          message: 'Bene!',
          transcript: 'Vado al mare',
          corrections: [
            Correction(
              original: 'mari',
              corrected: 'mare',
              explanation: 'La e finale è una e, non una i.',
              category: CorrectionCategory.pronunciation,
            ),
          ],
        ),
      );
      await chat.open(tester);
      await tester.tap(find.byTooltip('Registra un messaggio vocale'));
      await tester.pump();
      await tester.tap(find.byTooltip('Invia il messaggio vocale'));
      await tester.pumpAndSettle();

      expect(find.text('Pronuncia'), findsOneWidget);
      await tester.ensureVisible(_textButton('Compita'));
      await tester.tap(_textButton('Compita'));
      await tester.pumpAndSettle();
      expect(chat.speech.spoken.last.text, 'm, a, r, e');
    });
  });

  group('limits and housekeeping', () {
    testWidgets('a recording ends and is sent by itself after a minute', (
      tester,
    ) async {
      final chat = _Chat(transcript: 'Una storia lunga');
      await chat.open(tester);
      await tester.tap(find.byTooltip('Registra un messaggio vocale'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 59));
      expect(chat.ai.requests, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(chat.recorder.stops, 1);
      expect(chat.ai.requests.single.messages.single.audio, isNotNull);
    });

    testWidgets('leaving the chat while recording throws the recording away', (
      tester,
    ) async {
      final chat = _Chat();
      await chat.open(tester);
      await tester.tap(find.byTooltip('Registra un messaggio vocale'));
      await tester.pump();
      expect(chat.recorder.cancels, 0);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(chat.recorder.cancels, 1);
      expect(chat.ai.requests, isEmpty);
    });
  });

  testWidgets('the Profile switch for reading replies aloud is saved', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await pumpApp(tester, storage, profile: onboardedProfile);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profilo'),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(
      SwitchListTile,
      'Leggi le risposte ad alta voce',
    );
    await tester.ensureVisible(tile);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    expect(
      (jsonDecode(storage.data['user_learning_profile']!)
          as Map<String, dynamic>)['speakReplies'],
      isTrue,
    );
  });
}
