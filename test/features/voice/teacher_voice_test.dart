import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/conversation/presentation/widgets/message_bubble.dart';
import 'package:parla_con_me/shared/ui/app_bottom_nav.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/profile/data/local_user_learning_profile_repository.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_controller.dart';
import 'package:parla_con_me/features/voice/domain/speech_text.dart';
import 'package:parla_con_me/features/voice/presentation/speech_controller.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/services/speech/flutter_tts_speech_service.dart';
import 'package:parla_con_me/services/speech/speech_service.dart';
import 'package:parla_con_me/services/speech/voice_resolver.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/fake_ai_service.dart';
import '../../support/fake_voice.dart';
import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

// Phase 14: the teacher's voice, female or male, in the language being
// learned. Presentation only: nothing here is learning.

/// A voice as an engine that DOES say its gender would describe it.
DeviceVoice _voice(
  String name,
  String locale, {
  int quality = 2,
  bool network = false,
  String features = '',
}) => DeviceVoice(
  name: name,
  locale: locale,
  quality: quality,
  networkRequired: network,
  features: features,
);

/// Every language the app can read aloud, with one voice of each gender.
final _declared = <DeviceVoice>[
  for (final tag in [
    'it-IT',
    'en-US',
    'fr-FR',
    'de-DE',
    'es-ES',
    'pt-BR',
    'zh-CN',
  ]) ...[_voice('$tag-female-local', tag), _voice('$tag-male-local', tag)],
];

class _FakeTts extends FlutterTts {
  final calls = <String>[];
  List<Map<String, String>>? voices;
  bool failVoices = false;
  bool languageAvailable = true;
  int setVoiceResult = 1;
  int voiceReads = 0;

  /// The engine fails the reading: it reports an error and never completes
  /// `speak`, as the Android plugin does.
  bool failSynthesis = false;

  @override
  Future<dynamic> get getVoices async {
    voiceReads++;
    if (failVoices) throw StateError('no voices');
    return voices;
  }

  @override
  Future<dynamic> isLanguageAvailable(String language) async =>
      languageAvailable ? 1 : 0;
  @override
  Future<dynamic> stop() async => calls.add('stop');
  @override
  Future<dynamic> setLanguage(String language) async =>
      calls.add('language:$language');
  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    calls.add('voice:${voice['name']}|${voice['locale']}');
    return setVoiceResult;
  }

  @override
  Future<dynamic> setPitch(double pitch) async => calls.add('pitch:$pitch');
  @override
  Future<dynamic> setSpeechRate(double rate) async => calls.add('rate:$rate');
  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async =>
      calls.add('await');
  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    calls.add('speak:$text');
    if (failSynthesis) {
      unawaited(
        Future<void>.microtask(
          () => errorHandler?.call('Error from TextToSpeech (speak) - -7'),
        ),
      );
      return Completer<void>().future;
    }
  }
}

Map<String, String> _map(
  String name,
  String locale, {
  String quality = 'normal',
  String network = '0',
}) => {
  'name': name,
  'locale': locale,
  'quality': quality,
  'latency': 'normal',
  'network_required': network,
  'features': '',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('voice resolution', () {
    test('every supported language: a female and a male voice, of that '
        'language, according to what the engine declares', () {
      for (final language in AppLanguage.values) {
        final tag = speechLocaleTag(language);
        final female = resolveVoice(
          voices: _declared,
          localeTag: tag,
          gender: VoiceGender.female,
        );
        final male = resolveVoice(
          voices: _declared,
          localeTag: tag,
          gender: VoiceGender.male,
        );
        expect(female.voice?.name, '$tag-female-local', reason: language.name);
        expect(male.voice?.name, '$tag-male-local', reason: language.name);
        expect(female.genderMatched, isTrue);
        expect(male.genderMatched, isTrue);
        expect(male.pitch, 1.0, reason: 'a real male voice needs no pitch');
        expect(male.voice!.locale, tag);
      }
    });

    test('gender is read from whole words only: "female" is not "male"', () {
      expect(_voice('x-female-1', 'it-IT').declaredGender, VoiceGender.female);
      expect(
        _voice('x', 'it-IT', features: 'male').declaredGender,
        VoiceGender.male,
      );
      expect(
        _voice('Female_Voice', 'it-IT').declaredGender,
        VoiceGender.female,
      );
      expect(_voice('it-it-x-itb-local', 'it-IT').declaredGender, isNull);
      expect(_voice('tamale', 'it-IT').declaredGender, isNull);
    });

    test('the best voice of the gender wins: exact locale, quality, installed '
        'over network', () {
      final voices = [
        _voice('en-gb-male', 'en-GB', quality: 4),
        _voice('en-us-male-network', 'en-US', quality: 3, network: true),
        _voice('en-us-male-local', 'en-US', quality: 3),
        _voice('en-us-male-low', 'en-US', quality: 1),
      ];
      final resolved = resolveVoice(
        voices: voices,
        localeTag: 'en-US',
        gender: VoiceGender.male,
      );
      expect(resolved.voice?.name, 'en-us-male-local');
      // A regional variant of the same language is used when it is all there is.
      final onlyGb = resolveVoice(
        voices: [_voice('en-gb-male', 'en-GB')],
        localeTag: 'en-US',
        gender: VoiceGender.male,
      );
      expect(onlyGb.voice?.name, 'en-gb-male');
    });

    test('an engine that says nothing about gender: its own voice, female at '
        'the natural pitch, male approximated with a lower one', () {
      final voices = [
        _voice('it-it-x-aaa-local', 'it-IT'),
        _voice('it-it-x-bbb-local', 'it-IT'),
      ];
      final female = resolveVoice(
        voices: voices,
        localeTag: 'it-IT',
        gender: VoiceGender.female,
      );
      final male = resolveVoice(
        voices: voices,
        localeTag: 'it-IT',
        gender: VoiceGender.male,
      );
      expect(female.voice, isNull);
      expect(female.pitch, 1.0);
      expect(male.voice, isNull);
      expect(male.pitch, maleFallbackPitch);
      expect(male.pitch, lessThan(1.0));
      expect(male.genderMatched, isFalse);
    });

    test('a language with no voice at all, or a voice of another language, '
        'still resolves safely and never crosses languages', () {
      final none = resolveVoice(
        voices: const [],
        localeTag: 'fr-FR',
        gender: VoiceGender.male,
      );
      expect(none.voice, isNull);
      expect(none.pitch, maleFallbackPitch);

      final other = resolveVoice(
        voices: [_voice('de-de-male', 'de-DE')],
        localeTag: 'fr-FR',
        gender: VoiceGender.male,
      );
      expect(other.voice, isNull, reason: 'never a German voice for French');
    });

    test('genders are declared but not the wanted one: a neutral voice is '
        'preferred to the other gender', () {
      final voices = [
        _voice('it-female', 'it-IT'),
        _voice('it-plain', 'it-IT'),
      ];
      final male = resolveVoice(
        voices: voices,
        localeTag: 'it-IT',
        gender: VoiceGender.male,
      );
      expect(male.voice?.name, 'it-plain');
      expect(male.pitch, maleFallbackPitch);
      final onlyFemale = resolveVoice(
        voices: [_voice('it-female', 'it-IT')],
        localeTag: 'it-IT',
        gender: VoiceGender.male,
      );
      expect(onlyFemale.voice, isNull, reason: 'the engine default, lowered');
    });

    test('device voices that make no sense are ignored', () {
      expect(DeviceVoice.tryFromMap(null), isNull);
      expect(DeviceVoice.tryFromMap('x'), isNull);
      expect(DeviceVoice.tryFromMap({'name': '', 'locale': 'it-IT'}), isNull);
      expect(DeviceVoice.tryFromMap({'name': 'a'}), isNull);
      final ok = DeviceVoice.tryFromMap(
        _map('a', 'it-IT', quality: 'very high', network: '1'),
      )!;
      expect(ok.quality, 4);
      expect(ok.networkRequired, isTrue);
    });
  });

  group('the device speech service', () {
    late _FakeTts tts;
    late FlutterTtsSpeechService service;

    setUp(() {
      tts = _FakeTts();
      service = FlutterTtsSpeechService(tts);
    });

    Future<void> speak(String tag, VoiceGender gender) async {
      final outcome = await service.speak(
        'Ciao',
        localeTag: tag,
        gender: gender,
      );
      expect(outcome, SpeechOutcome.done);
    }

    test('a declared voice of the wanted gender is set, after the language, '
        'at the natural pitch', () async {
      tts.voices = [
        _map('it-male-local', 'it-IT'),
        _map('it-female-local', 'it-IT'),
      ];
      await speak('it-IT', VoiceGender.male);
      expect(
        tts.calls,
        containsAllInOrder([
          'language:it-IT',
          'voice:it-male-local|it-IT',
          'pitch:1.0',
          'speak:Ciao',
        ]),
      );
    });

    test('no declared gender: no voice is forced; male is a lower pitch and '
        'the next female reading goes back to the natural one', () async {
      tts.voices = [_map('it-it-x-aaa-local', 'it-IT')];
      await speak('it-IT', VoiceGender.male);
      expect(tts.calls.where((c) => c.startsWith('voice:')), isEmpty);
      expect(tts.calls, contains('pitch:$maleFallbackPitch'));

      tts.calls.clear();
      await speak('it-IT', VoiceGender.female);
      expect(tts.calls, contains('pitch:1.0'));
      expect(tts.calls, isNot(contains('pitch:$maleFallbackPitch')));
    });

    test('it always speaks the language it was asked for', () async {
      tts.voices = [
        for (final tag in ['it-IT', 'es-ES', 'en-US']) _map('$tag-male', tag),
      ];
      for (final tag in ['it-IT', 'es-ES', 'en-US']) {
        tts.calls.clear();
        await speak(tag, VoiceGender.male);
        expect(tts.calls, contains('language:$tag'));
        expect(tts.calls, contains('voice:$tag-male|$tag'));
      }
    });

    test('a voice the engine refuses falls back, and still speaks', () async {
      tts.voices = [_map('it-male', 'it-IT')];
      tts.setVoiceResult = 0;
      await speak('it-IT', VoiceGender.male);
      expect(tts.calls, contains('pitch:$maleFallbackPitch'));
      expect(tts.calls, contains('speak:Ciao'));
    });

    test('voices that cannot be read never stop the reading', () async {
      tts.failVoices = true;
      await speak('it-IT', VoiceGender.male);
      expect(tts.calls, contains('speak:Ciao'));
      expect(tts.calls, contains('pitch:1.0'));
    });

    test('no voice for the language: said so, nothing is read', () async {
      tts.languageAvailable = false;
      final outcome = await service.speak(
        'Ciao',
        localeTag: 'it-IT',
        gender: VoiceGender.male,
      );
      expect(outcome, SpeechOutcome.noVoice);
      expect(tts.calls.where((c) => c.startsWith('speak:')), isEmpty);
    });

    test('an engine that fails to synthesize ends the reading as failed '
        'instead of waiting for ever, and the next one works', () async {
      tts.voices = [_map('it-it-x-kda-local', 'it-IT')];
      tts.failSynthesis = true;
      final failed = await service
          .speak('Ciao', localeTag: 'it-IT')
          .timeout(const Duration(seconds: 2));
      expect(failed, SpeechOutcome.failed);
      expect(tts.calls.last, 'stop', reason: 'the engine is left idle');

      tts.failSynthesis = false;
      tts.calls.clear();
      expect(
        await service.speak('Ciao', localeTag: 'it-IT'),
        SpeechOutcome.done,
      );
      expect(tts.calls, contains('speak:Ciao'));
    });

    test('the voices are asked of the engine once', () async {
      tts.voices = [_map('it-male', 'it-IT')];
      await speak('it-IT', VoiceGender.male);
      await speak('it-IT', VoiceGender.female);
      expect(tts.voiceReads, 1);
    });
  });

  group('the preference', () {
    test('the default is the voice the app always had', () {
      expect(UserLearningProfile.empty.teacherVoice, VoiceGender.female);
      expect(onboardedProfile.teacherVoice, VoiceGender.female);
    });

    test('both can be chosen, and it is part of the profile\'s identity', () {
      final male = onboardedProfile.copyWith(teacherVoice: VoiceGender.male);
      expect(male.teacherVoice, VoiceGender.male);
      expect(male, isNot(onboardedProfile));
      expect(male.copyWith(teacherVoice: VoiceGender.female), onboardedProfile);
      expect(
        male.copyWith(level: LanguageLevel.b1).teacherVoice,
        VoiceGender.male,
      );
    });

    test('it persists, and restores', () async {
      final storage = InMemoryLocalStorage();
      final repo = LocalUserLearningProfileRepository(storage);
      await repo.save(
        onboardedProfile.copyWith(teacherVoice: VoiceGender.male),
      );
      expect(
        jsonDecode(storage.data['user_learning_profile']!)['teacherVoice'],
        'male',
      );
      final loaded = (await LocalUserLearningProfileRepository(
        storage,
      ).load()).when(success: (p) => p, failure: (f) => fail('$f'));
      expect(loaded.teacherVoice, VoiceGender.male);
    });

    test('a profile stored before it existed, or with a value that means '
        'nothing, keeps the usual voice', () async {
      for (final extra in [
        <String, Object?>{},
        {'teacherVoice': 'robot'},
        {'teacherVoice': 3},
      ]) {
        final storage = InMemoryLocalStorage();
        storage.data['user_learning_profile'] = jsonEncode({
          'v': 2,
          'supportLanguage': 'spanish',
          'learningLanguage': 'italian',
          'level': 'a2',
          'goals': ['speakConfidently'],
          'focusAreas': ['conversation'],
          'onboardingCompleted': true,
          ...extra,
        });
        final loaded = (await LocalUserLearningProfileRepository(
          storage,
        ).load()).when(success: (p) => p, failure: (f) => fail('$f'));
        expect(loaded.teacherVoice, VoiceGender.female, reason: '$extra');
        expect(loaded.onboardingCompleted, isTrue);
      }
    });

    testWidgets('Profile: choose the voice, it is saved, and it is still '
        'there after a restart', (tester) async {
      final storage = InMemoryLocalStorage();
      await LocalUserLearningProfileRepository(storage).save(onboardedProfile);
      await pumpApp(tester, storage);
      await _openTab(tester, 'Profilo');

      expect(find.text("Voce dell'insegnante"), findsOneWidget);
      final segments = tester.widget<SegmentedButton<VoiceGender>>(
        find.byType(SegmentedButton<VoiceGender>),
      );
      expect(segments.selected, {VoiceGender.female});

      await tester.ensureVisible(find.text('Maschile'));
      await tester.tap(find.text('Maschile'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<VoiceGender>>(
              find.byType(SegmentedButton<VoiceGender>),
            )
            .selected,
        {VoiceGender.male},
      );
      expect(
        jsonDecode(storage.data['user_learning_profile']!)['teacherVoice'],
        'male',
      );

      // A new run of the app over the same storage.
      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, storage);
      await _openTab(tester, 'Profilo');
      expect(
        tester
            .widget<SegmentedButton<VoiceGender>>(
              find.byType(SegmentedButton<VoiceGender>),
            )
            .selected,
        {VoiceGender.male},
      );
    });
  });

  group('what is spoken', () {
    final target = 'Come stai oggi?';
    final translation = '¿Cómo estás hoy?';

    Future<({FakeSpeechService speech, ProviderContainer? c})> chat(
      WidgetTester tester,
      InMemoryLocalStorage storage, {
      UserLearningProfile profile = onboardedProfile,
    }) async {
      final speech = FakeSpeechService();
      final ai = FakeAIService(
        onRequest: (_) async => Success(
          AIResponse(
            message: target,
            translation: translation,
            corrections: const [
              Correction(
                original: 'ho andato',
                corrected: 'sono andato',
                correctedTranslation: 'fui',
                explanation: 'x',
                category: CorrectionCategory.grammar,
              ),
            ],
          ),
        ),
      );
      await pumpApp(
        tester,
        storage,
        profile: profile,
        overrides: [
          aiServiceProvider.overrideWithValue(ai),
          speechServiceProvider.overrideWithValue(speech),
          learningEngineProvider.overrideWithValue(RecordingLearningEngine()),
        ],
      );
      tester.view.physicalSize = const Size(1080, 3600);
      await tester.pumpAndSettle();
      await _openTab(tester, 'Parla');
      await tester.enterText(find.byType(TextField), 'Ieri ho andato.');
      await tester.pump();
      await tester.tap(find.byTooltip('Invia'));
      await tester.pumpAndSettle();
      return (speech: speech, c: null);
    }

    testWidgets('playing the teacher\'s message reads the target language '
        'only, never the translation, with the chosen voice', (tester) async {
      for (final gender in VoiceGender.values) {
        final storage = InMemoryLocalStorage();
        final run = await chat(
          tester,
          storage,
          profile: onboardedProfile.copyWith(teacherVoice: gender),
        );
        expect(find.text(translation), findsOneWidget, reason: 'still shown');

        await tester.tap(find.byTooltip('Ascolta il messaggio'));
        await tester.pumpAndSettle();

        expect(run.speech.spoken.map((s) => s.text), [target]);
        expect(run.speech.spoken.single.localeTag, 'it-IT');
        expect(run.speech.spoken.single.gender, gender);
        expect(run.speech.spoken.any((s) => s.text.contains('Cómo')), isFalse);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the correction is read in the target language too, with the '
        'same voice', (tester) async {
      final run = await chat(
        tester,
        InMemoryLocalStorage(),
        profile: onboardedProfile.copyWith(teacherVoice: VoiceGender.male),
      );
      await tester.tap(
        find
            .descendant(
              of: find.byType(CorrectionCard),
              matching: find.text('Ascolta'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(run.speech.spoken.single.text, 'sono andato');
      expect(run.speech.spoken.single.gender, VoiceGender.male);
      expect(run.speech.spoken.single.text, isNot(contains('fui')));
    });

    testWidgets('changing the voice applies to the next reading', (
      tester,
    ) async {
      final storage = InMemoryLocalStorage();
      final run = await chat(tester, storage);
      await tester.tap(find.byTooltip('Ascolta il messaggio'));
      await tester.pumpAndSettle();

      await _openTab(tester, 'Profilo');
      await tester.ensureVisible(find.text('Maschile'));
      await tester.tap(find.text('Maschile'));
      await tester.pumpAndSettle();
      await _openTab(tester, 'Parla');
      await tester.tap(find.byTooltip('Ascolta il messaggio'));
      await tester.pumpAndSettle();

      expect(run.speech.spoken.map((s) => s.gender), [
        VoiceGender.female,
        VoiceGender.male,
      ]);
      expect(run.speech.spoken.map((s) => s.text), [target, target]);
    });
  });

  group('the voice is not learning', () {
    testWidgets('playing a message, or changing the voice, changes no '
        'conversation, no learning memory, no review memory, no revision', (
      tester,
    ) async {
      final storage = InMemoryLocalStorage();
      final speech = FakeSpeechService();
      var calls = 0;
      final ai = FakeAIService(
        onRequest: (_) async {
          calls++;
          return Success(
            AIResponse(
              message: 'Quasi! Dove sei andato?',
              translation: '¡Casi!',
              corrections: calls == 1
                  ? const [
                      Correction(
                        original: 'Ieri ho andato al mare.',
                        corrected: 'Ieri sono andato al mare.',
                        explanation: 'x',
                        category: CorrectionCategory.grammar,
                      ),
                    ]
                  : const [],
            ),
          );
        },
      );
      await pumpApp(
        tester,
        storage,
        profile: onboardedProfile,
        overrides: [
          aiServiceProvider.overrideWithValue(ai),
          speechServiceProvider.overrideWithValue(speech),
        ],
      );
      tester.view.physicalSize = const Size(1080, 3600);
      await tester.pumpAndSettle();
      await _openTab(tester, 'Parla');
      await tester.enterText(find.byType(TextField), 'Ieri ho andato al mare.');
      await tester.pump();
      await tester.tap(find.byTooltip('Invia'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      container.listen(learningRevisionProvider, (_, _) {});
      final learning = storage.data['learning_memory'];
      expect(learning, isNotNull, reason: 'the mistake was learned');
      final before = (
        learning: learning,
        review: storage.data['review_memory'],
        conversations: storage.data['conversations'],
        revision: container.read(learningRevisionProvider),
      );

      // Play it, play it again, stop it, change the voice and play again.
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byTooltip('Ascolta il messaggio'));
        await tester.pumpAndSettle();
      }
      await _openTab(tester, 'Profilo');
      await tester.ensureVisible(find.text('Maschile'));
      await tester.tap(find.text('Maschile'));
      await tester.pumpAndSettle();
      await _openTab(tester, 'Parla');
      await tester.tap(find.byTooltip('Ascolta il messaggio'));
      await tester.pumpAndSettle();

      expect(speech.spoken, hasLength(3));
      expect(storage.data['learning_memory'], before.learning);
      expect(storage.data['review_memory'], before.review);
      expect(storage.data['conversations'], before.conversations);
      expect(container.read(learningRevisionProvider), before.revision);
    });

    test('a reading that fails leaves everything as it was', () async {
      final speech = FakeSpeechService()..outcome = SpeechOutcome.failed;
      final storage = InMemoryLocalStorage();
      storage.data['learning_memory'] = '{"version":1}';
      final c = ProviderContainer(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(storage),
          speechServiceProvider.overrideWithValue(speech),
          userLearningProfileProvider.overrideWith(
            () => PreloadedUserLearningProfileController(onboardedProfile),
          ),
        ],
      );
      addTearDown(c.dispose);
      final outcome = await c
          .read(speechControllerProvider.notifier)
          .speak(key: 'k', text: 'Ciao', language: AppLanguage.italian);
      expect(outcome, SpeechOutcome.failed);
      expect(storage.data.keys, ['learning_memory']);
      expect(storage.data['learning_memory'], '{"version":1}');
    });
  });
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(AppBottomNav), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}
