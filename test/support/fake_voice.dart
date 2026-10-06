import 'dart:async';
import 'dart:typed_data';

import 'package:parla_con_me/services/audio/audio_clip.dart';
import 'package:parla_con_me/services/audio/voice_recorder.dart';
import 'package:parla_con_me/services/speech/speech_service.dart';

/// A [SpeechService] that speaks to nobody: it records what it was asked to
/// read. With [hold] set, reading lasts until the completer completes (so a
/// test can look at the "playing" state).
class FakeSpeechService implements SpeechService {
  final spoken = <({String text, String localeTag, SpeechPace pace})>[];
  SpeechOutcome outcome = SpeechOutcome.done;
  Completer<void>? hold;
  int stops = 0;

  @override
  Future<SpeechOutcome> speak(
    String text, {
    required String localeTag,
    SpeechPace pace = SpeechPace.normal,
  }) async {
    spoken.add((text: text, localeTag: localeTag, pace: pace));
    await hold?.future;
    return outcome;
  }

  @override
  Future<void> stop() async {
    stops++;
    final h = hold;
    if (h != null && !h.isCompleted) h.complete();
  }
}

AudioClip fakeClip({Duration duration = const Duration(seconds: 3)}) =>
    AudioClip(
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      mimeType: 'audio/wav',
      duration: duration,
    );

/// A [VoiceRecorder] without a microphone.
class FakeVoiceRecorder implements VoiceRecorder {
  RecordingStart startOutcome = RecordingStart.started;
  AudioClip? clip = fakeClip();
  int starts = 0;
  int stops = 0;
  int cancels = 0;

  @override
  Future<RecordingStart> start() async {
    starts++;
    return startOutcome;
  }

  @override
  Future<AudioClip?> stop() async {
    stops++;
    return clip;
  }

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<void> dispose() async {}
}
