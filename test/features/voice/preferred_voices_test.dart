import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_controller.dart';
import 'package:parla_con_me/features/voice/domain/speech_text.dart';
import 'package:parla_con_me/features/voice/presentation/speech_controller.dart';
import 'package:parla_con_me/services/speech/flutter_tts_speech_service.dart';
import 'package:parla_con_me/services/speech/speech_service.dart';
import 'package:parla_con_me/services/speech/voice_resolver.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

// Phase 16: the Italian voices a person chose by listening (Phase 15.1), the
// server voice first and its installed twin as a fallback, for each gender.

const _itbNetwork = 'it-it-x-itb-network';
const _itbLocal = 'it-it-x-itb-local';
const _itdNetwork = 'it-it-x-itd-network';
const _itdLocal = 'it-it-x-itd-local';

/// The Italian voices of the test phone (Phase 15.1 inventory).
DeviceVoice _it(String name, {bool network = false}) => DeviceVoice(
  name: name,
  locale: 'it-IT',
  quality: 3,
  networkRequired: network,
);

final _phone = <DeviceVoice>[
  _it('it-IT-language'),
  _it(_itbLocal),
  _it('it-it-x-itc-local'),
  _it(_itdLocal),
  _it('it-it-x-kda-local'),
  _it(_itbNetwork, network: true),
  _it('it-it-x-itc-network', network: true),
  _it(_itdNetwork, network: true),
  _it('it-it-x-kda-network', network: true),
];

List<String?> _names(List<ResolvedVoice> chain) => [
  for (final r in chain) r.voice?.name,
];

/// A text-to-speech engine that behaves as Android's does: setVoice picks by
/// name, `speak` waits for the end, an error is reported by a callback and
/// never completes `speak`, and `stop` completes a pending `speak`.
class _Engine extends FlutterTts {
  final calls = <String>[];
  List<Map<String, String>> voices = [];
  String? voice;

  /// How the speech of a voice goes: by default it is read at once.
  final behavior = <String, _Speech>{};
  int setVoiceResult = 1;
  Completer<void>? _pending;

  Map<String, String> map(String name, {bool network = false}) => {
    'name': name,
    'locale': 'it-IT',
    'quality': 'high',
    'latency': 'low',
    'network_required': network ? '1' : '0',
    'features': '',
  };

  @override
  Future<dynamic> get getVoices async => voices;
  @override
  Future<dynamic> isLanguageAvailable(String language) async => 1;
  @override
  Future<dynamic> setLanguage(String language) async {
    // As on Android: choosing a language puts back that language's default
    // voice, forgetting any voice chosen before.
    voice = null;
    calls.add('language:$language');
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {}
  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {}
  @override
  Future<dynamic> setPitch(double pitch) async => calls.add('pitch:$pitch');
  @override
  Future<dynamic> setVoice(Map<String, String> v) async {
    calls.add('voice:${v['name']}');
    if (setVoiceResult == 1) voice = v['name'];
    return setVoiceResult;
  }

  @override
  Future<dynamic> stop() async {
    calls.add('stop');
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    calls.add('speak:${voice ?? 'default'}:$text');
    final how = behavior[voice ?? 'default'] ?? _Speech.reads;
    switch (how) {
      case _Speech.reads:
        startHandler?.call();
      case _Speech.errors:
        unawaited(
          Future<void>.microtask(
            () => errorHandler?.call('Synthesis failure - -7'),
          ),
        );
        return _hang();
      case _Speech.neverStarts:
        return _hang();
      case _Speech.slowButStarts:
        startHandler?.call();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      case _Speech.dies:
        // Starts, then the engine process is gone: nothing is ever reported.
        startHandler?.call();
        return _hang();
    }
  }

  Future<void> _hang() {
    final c = _pending = Completer<void>();
    return c.future;
  }
}

enum _Speech { reads, errors, neverStarts, slowButStarts, dies }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the voices chosen by listening', () {
    test('Italian + female: the server voice, then its installed twin', () {
      final chain = resolveVoiceChain(
        voices: _phone,
        localeTag: 'it-IT',
        gender: VoiceGender.female,
      );
      expect(_names(chain).take(2), [_itbNetwork, _itbLocal]);
      expect(chain.first.pitch, 1.0);
      expect(
        resolveVoice(
          voices: _phone,
          localeTag: 'it-IT',
          gender: VoiceGender.female,
        ).voice?.name,
        _itbNetwork,
      );
    });

    test('Italian + male: a real voice by id, not a lowered pitch', () {
      final chain = resolveVoiceChain(
        voices: _phone,
        localeTag: 'it-IT',
        gender: VoiceGender.male,
      );
      expect(_names(chain).take(2), [_itdNetwork, _itdLocal]);
      expect(chain.take(2).every((r) => r.pitch == 1.0), isTrue);
      expect(
        resolveVoice(
          voices: _phone,
          localeTag: 'it-IT',
          gender: VoiceGender.male,
        ).voice?.name,
        _itdNetwork,
      );
    });

    test('the last resort is always the engine\'s own voice, so a pitch is '
        'only ever the very last thing tried', () {
      final male = resolveVoiceChain(
        voices: _phone,
        localeTag: 'it-IT',
        gender: VoiceGender.male,
      );
      expect(male.last.voice, isNull);
      expect(male.last.pitch, maleFallbackPitch);
      final female = resolveVoiceChain(
        voices: _phone,
        localeTag: 'it-IT',
        gender: VoiceGender.female,
      );
      expect(female.last.voice, isNull);
      expect(female.last.pitch, 1.0);
    });

    test('without the server voice, the installed twin comes first', () {
      final noNetwork = [
        for (final v in _phone)
          if (!v.networkRequired) v,
      ];
      expect(
        resolveVoice(
          voices: noNetwork,
          localeTag: 'it-IT',
          gender: VoiceGender.female,
        ).voice?.name,
        _itbLocal,
      );
      expect(
        resolveVoice(
          voices: noNetwork,
          localeTag: 'it-IT',
          gender: VoiceGender.male,
        ).voice?.name,
        _itdLocal,
      );
    });

    test('a phone without any of them keeps the generic resolution', () {
      final other = [_it('it-it-x-aaa-local'), _it('it-it-x-bbb-local')];
      for (final gender in VoiceGender.values) {
        final chain = resolveVoiceChain(
          voices: other,
          localeTag: 'it-IT',
          gender: gender,
        );
        expect(chain, hasLength(1));
        expect(chain.single.voice, isNull);
        expect(chain.single.pitch, fallbackPitch(gender));
      }
    });

    test('the voices are never taken from their name: the table says which '
        'is which', () {
      final female = resolveVoiceChain(
        voices: _phone,
        localeTag: 'it-IT',
        gender: VoiceGender.female,
      );
      final male = resolveVoiceChain(
        voices: _phone,
        localeTag: 'it-IT',
        gender: VoiceGender.male,
      );
      expect(_names(female), isNot(contains(_itdNetwork)));
      expect(_names(female), isNot(contains('it-it-x-itc-network')));
      expect(_names(male), isNot(contains(_itbNetwork)));
      expect(_names(male), isNot(contains('it-it-x-kda-network')));
    });

    test('the locale is matched however it is written; a voice of another '
        'locale with the same name is not used', () {
      expect(
        resolveVoice(
          voices: _phone,
          localeTag: 'it_IT',
          gender: VoiceGender.male,
        ).voice?.name,
        _itdNetwork,
      );
      final wrongLocale = [
        const DeviceVoice(
          name: _itbNetwork,
          locale: 'en-US',
          networkRequired: true,
        ),
      ];
      expect(
        resolveVoice(
          voices: wrongLocale,
          localeTag: 'it-IT',
          gender: VoiceGender.female,
        ).voice,
        isNull,
      );
    });

    test('no other language ever uses them, even if the phone lists them', () {
      for (final language in AppLanguage.values) {
        if (language == AppLanguage.italian) continue;
        final tag = speechLocaleTag(language);
        for (final gender in VoiceGender.values) {
          final chain = resolveVoiceChain(
            voices: [
              ..._phone,
              DeviceVoice(
                name: '${tag.toLowerCase()}-x-aaa-local',
                locale: tag,
              ),
            ],
            localeTag: tag,
            gender: gender,
          );
          for (final name in [_itbNetwork, _itbLocal, _itdNetwork, _itdLocal]) {
            expect(
              _names(chain),
              isNot(contains(name)),
              reason: '$tag $gender',
            );
          }
          expect(chain.last.voice, isNull);
        }
      }
      expect(preferredVoiceNames.keys, ['it-it']);
    });
  });

  group('the speech service with those voices', () {
    late _Engine tts;
    late FlutterTtsSpeechService service;

    setUp(() {
      tts = _Engine()..voices = [for (final v in _phone) voiceMap(v)];
      service = FlutterTtsSpeechService(tts, const Duration(milliseconds: 80));
    });

    Future<SpeechOutcome> speak(VoiceGender gender, {String tag = 'it-IT'}) =>
        service
            .speak('Ciao', localeTag: tag, gender: gender)
            .timeout(const Duration(seconds: 3));

    List<String> voicesSet() => [
      for (final c in tts.calls)
        if (c.startsWith('voice:')) c.substring(6),
    ];

    test(
      'female online: the server voice reads, at the natural pitch',
      () async {
        expect(await speak(VoiceGender.female), SpeechOutcome.done);
        expect(voicesSet(), [_itbNetwork]);
        expect(tts.calls, contains('speak:$_itbNetwork:Ciao'));
        expect(tts.calls, contains('pitch:1.0'));
      },
    );

    test('male online: a real voice, never the lowered pitch', () async {
      expect(await speak(VoiceGender.male), SpeechOutcome.done);
      expect(voicesSet(), [_itdNetwork]);
      expect(tts.calls, isNot(contains('pitch:$maleFallbackPitch')));
    });

    test('the server voice fails: the installed twin reads instead, for '
        'each gender', () async {
      for (final (gender, network, local) in [
        (VoiceGender.female, _itbNetwork, _itbLocal),
        (VoiceGender.male, _itdNetwork, _itdLocal),
      ]) {
        tts.calls.clear();
        tts.behavior
          ..clear()
          ..[network] = _Speech.errors;
        expect(await speak(gender), SpeechOutcome.done);
        expect(voicesSet(), [network, local]);
        expect(tts.calls.last, 'speak:$local:Ciao');
        expect(
          tts.calls,
          contains('stop'),
          reason: 'the failed one was stopped',
        );
      }
    });

    test('the server voice never starts (no network, no error): after the '
        'time allowed the installed twin reads', () async {
      tts.behavior[_itdNetwork] = _Speech.neverStarts;
      final sw = Stopwatch()..start();
      expect(await speak(VoiceGender.male), SpeechOutcome.done);
      expect(voicesSet(), [_itdNetwork, _itdLocal]);
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('a server voice that starts is not cut short, however long it '
        'takes', () async {
      tts.behavior[_itbNetwork] = _Speech.slowButStarts;
      expect(await speak(VoiceGender.female), SpeechOutcome.done);
      expect(voicesSet(), [_itbNetwork], reason: 'no fallback was needed');
    });

    test('both preferred voices fail: the engine\'s own voice is the last '
        'resort, and for male it is the old pitch', () async {
      tts.behavior
        ..[_itdNetwork] = _Speech.errors
        ..[_itdLocal] = _Speech.errors;
      expect(await speak(VoiceGender.male), SpeechOutcome.done);
      expect(voicesSet(), [_itdNetwork, _itdLocal]);
      expect(tts.calls.last, startsWith('speak:'));
      expect(tts.calls, contains('pitch:$maleFallbackPitch'));
    });

    test('everything fails: the reading ends as failed, quickly, with the '
        'engine idle', () async {
      tts.behavior
        ..[_itbNetwork] = _Speech.errors
        ..[_itbLocal] = _Speech.errors
        ..['default'] = _Speech.errors;
      final sw = Stopwatch()..start();
      expect(await speak(VoiceGender.female), SpeechOutcome.failed);
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(tts.calls.last, 'stop');
    });

    test('a refused voice moves on to the next one', () async {
      tts.setVoiceResult = 0;
      expect(await speak(VoiceGender.female), SpeechOutcome.done);
      expect(voicesSet(), [_itbNetwork, _itbLocal]);
      expect(tts.calls.last, 'speak:default:Ciao');
    });

    test('the learner stopping a slow server voice ends it: no other voice '
        'takes over', () async {
      tts.behavior[_itbNetwork] = _Speech.neverStarts;
      final slow = FlutterTtsSpeechService(tts, const Duration(seconds: 30));
      final reading = slow.speak('Ciao', localeTag: 'it-IT');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await slow.stop();
      expect(
        await reading.timeout(const Duration(seconds: 2)),
        SpeechOutcome.done,
      );
      expect(voicesSet(), [_itbNetwork]);
    });

    test('an engine that dies without a word (no error, no end) cannot leave '
        'the reading waiting: it is given up, and no other voice reads over '
        'it', () async {
      final capped = FlutterTtsSpeechService(
        tts,
        const Duration(seconds: 30),
        (_, _) => const Duration(milliseconds: 150),
      );
      for (final behavior in [_Speech.neverStarts, _Speech.dies]) {
        tts.calls.clear();
        tts.behavior
          ..clear()
          ..[_itbNetwork] = behavior;
        final sw = Stopwatch()..start();
        final outcome = await capped
            .speak('Ciao', localeTag: 'it-IT')
            .timeout(const Duration(seconds: 3));
        expect(outcome, SpeechOutcome.failed, reason: '$behavior');
        expect(sw.elapsedMilliseconds, lessThan(2500));
        expect(voicesSet(), [_itbNetwork], reason: 'no voice read over it');
        expect(tts.calls.last, 'stop', reason: 'the engine is left idle');
      }
    });

    test('the cap grows with the text and with the slow pace, and is never '
        'short for a long reading', () {
      const f = FlutterTtsSpeechService.defaultReadingCap;
      expect(f('Ciao', SpeechPace.normal).inSeconds, greaterThanOrEqualTo(15));
      final long = 'a' * 400;
      expect(f(long, SpeechPace.normal).inSeconds, 63);
      expect(f(long, SpeechPace.slow).inSeconds, 111);
    });

    test('another language is read with the old generic voice and never '
        'with these', () async {
      tts.voices = [
        {...tts.map('en-us-x-sfg-local'), 'locale': 'en-US'},
        for (final v in _phone) voiceMap(v),
      ];
      expect(await speak(VoiceGender.male, tag: 'en-US'), SpeechOutcome.done);
      expect(voicesSet(), isEmpty);
      expect(tts.calls, contains('pitch:$maleFallbackPitch'));
    });
  });

  group('the button is never left on Stop', () {
    ProviderContainer containerFor(_Engine tts) {
      final c = ProviderContainer(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(InMemoryLocalStorage()),
          speechServiceProvider.overrideWithValue(
            FlutterTtsSpeechService(tts, const Duration(milliseconds: 80)),
          ),
          userLearningProfileProvider.overrideWith(
            () => PreloadedUserLearningProfileController(
              onboardedProfile.copyWith(teacherVoice: VoiceGender.male),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a failed synthesis ends the reading, the controller is idle and '
        'Listen works again', () async {
      final tts = _Engine()..voices = [for (final v in _phone) voiceMap(v)];
      tts.behavior
        ..[_itdNetwork] = _Speech.errors
        ..[_itdLocal] = _Speech.errors
        ..['default'] = _Speech.errors;
      final c = containerFor(tts);
      final controller = c.read(speechControllerProvider.notifier);

      final failed = await controller
          .speak(key: 'm1', text: 'Ciao', language: AppLanguage.italian)
          .timeout(const Duration(seconds: 3));
      expect(failed, SpeechOutcome.failed);
      expect(c.read(speechControllerProvider).playingKey, isNull);

      tts.behavior.clear();
      final again = await controller
          .speak(key: 'm1', text: 'Ciao', language: AppLanguage.italian)
          .timeout(const Duration(seconds: 3));
      expect(again, SpeechOutcome.done);
      expect(c.read(speechControllerProvider).playingKey, isNull);
    });

    test('the text is cleaned before any voice gets it', () async {
      final tts = _Engine()..voices = [for (final v in _phone) voiceMap(v)];
      final c = containerFor(tts);
      await c
          .read(speechControllerProvider.notifier)
          .speak(
            key: 'm1',
            text: '**Quasi! 😊**\nCome stai?',
            language: AppLanguage.italian,
          );
      expect(tts.calls.last, 'speak:$_itdNetwork:Quasi! Come stai?');
    });
  });
}

/// A `getVoices` entry for [v].
Map<String, String> voiceMap(DeviceVoice v) => {
  'name': v.name,
  'locale': v.locale,
  'quality': 'high',
  'latency': 'low',
  'network_required': v.networkRequired ? '1' : '0',
  'features': v.features,
};
