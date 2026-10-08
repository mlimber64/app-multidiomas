import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../../shared/models/voice_gender.dart';
import 'speech_service.dart';
import 'voice_resolver.dart';

/// [SpeechService] on the device's text-to-speech engine (`flutter_tts`).
/// It needs no key and works without network with the voices installed on the
/// phone; a preferred voice that is a server voice (see `preferredVoiceNames`)
/// is tried first and its installed twin, then the engine's own voice, take over
/// if it fails.
class FlutterTtsSpeechService implements SpeechService {
  FlutterTtsSpeechService([
    FlutterTts? tts,
    this.networkStartTimeout = const Duration(seconds: 8),
    this.readingCap = defaultReadingCap,
  ]) : _tts = tts ?? FlutterTts() {
    // When the engine fails to produce the speech (a network voice that times
    // out, for example) the plugin reports it here but never completes the
    // pending `speak`, so the reading would wait forever.
    _tts.setErrorHandler((_) => _settle(_Reading.tryNext));
    _tts.setStartHandler(_started);
  }

  final FlutterTts _tts;

  /// The longest a reading of the text at the pace may take before it is
  /// given up. It is the last defence against an engine that dies without a
  /// word (the system killing it mid-speech reports neither an error nor an
  /// end), so the button is never left on "stop". Generous on purpose: a
  /// reading that really is slow must not be cut.
  final Duration Function(String text, SpeechPace pace) readingCap;

  /// 15 seconds, plus 120 ms per character (twice that when reading slowly);
  /// a real reading takes about 70 ms per character.
  static Duration defaultReadingCap(String text, SpeechPace pace) => Duration(
    milliseconds: 15000 + text.length * 120 * (pace == SpeechPace.slow ? 2 : 1),
  );

  /// How long a voice that needs the network may take to start speaking before
  /// the next voice is tried. Installed voices start at once and are not timed.
  final Duration networkStartTimeout;

  /// How the attempt in progress ends.
  Completer<_Reading>? _attempt;
  Timer? _startTimer;
  Timer? _capTimer;

  void _settle(_Reading how) {
    _startTimer?.cancel();
    final attempt = _attempt;
    if (attempt != null && !attempt.isCompleted) attempt.complete(how);
  }

  void _started() => _startTimer?.cancel();

  /// The engine's voices, read once (they only change when the learner
  /// installs a language pack, which is rare).
  List<DeviceVoice>? _voices;

  /// Android's speech rate: 0.5 is the normal pace of the engine.
  static const _normalRate = 0.5;
  static const _slowRate = 0.25;

  @override
  Future<SpeechOutcome> speak(
    String text, {
    required String localeTag,
    SpeechPace pace = SpeechPace.normal,
    VoiceGender gender = VoiceGender.female,
  }) async {
    if (text.trim().isEmpty) return SpeechOutcome.done;
    try {
      final available = await _tts.isLanguageAvailable(localeTag);
      if (available != true && available != 1) return SpeechOutcome.noVoice;
      // Each voice of the chain is tried until one reads: the preferred ones,
      // then the engine's own. Only a failure moves on; a reading stopped by
      // the learner counts as read.
      for (final voice in await _voiceChain(localeTag, gender)) {
        var how = _Reading.tryNext;
        try {
          how = await _read(text, localeTag, pace, voice);
        } catch (_) {
          // This voice broke the engine call: try the next one.
        }
        if (how == _Reading.read) return SpeechOutcome.done;
        // An engine that went silent is not asked again: another voice would
        // either fail the same way or read over the first.
        if (how == _Reading.giveUp) return SpeechOutcome.failed;
      }
      return SpeechOutcome.failed;
    } catch (_) {
      return SpeechOutcome.failed;
    }
  }

  /// One attempt with one voice. [_Reading.tryNext] when the engine refuses
  /// the voice, reports an error or (for a network voice) does not start in
  /// time; [_Reading.giveUp] when the whole reading outlasts [readingCap]. The
  /// engine is left idle unless it was read.
  Future<_Reading> _read(
    String text,
    String localeTag,
    SpeechPace pace,
    ResolvedVoice resolved,
  ) async {
    await _tts.stop();
    await _tts.setLanguage(localeTag);
    final voice = resolved.voice;
    if (voice != null) {
      final set = await _tts.setVoice({
        'name': voice.name,
        'locale': voice.locale,
      });
      // Refused: on to the next voice (the last one is the engine's own).
      if (set != true && set != 1) return _Reading.tryNext;
    }
    // Always set, so the pitch of one reading never leaks into the next.
    await _tts.setPitch(resolved.pitch);
    await _tts.setSpeechRate(pace == SpeechPace.slow ? _slowRate : _normalRate);
    await _tts.awaitSpeakCompletion(true);

    final attempt = _attempt = Completer<_Reading>();
    if (voice != null && voice.networkRequired) {
      _startTimer = Timer(networkStartTimeout, () => _settle(_Reading.tryNext));
    }
    _capTimer = Timer(readingCap(text, pace), () => _settle(_Reading.giveUp));
    unawaited(_tts.speak(text).then((_) => _settle(_Reading.read)));
    final how = await attempt.future;
    _startTimer?.cancel();
    _capTimer?.cancel();
    if (how != _Reading.read) await _tts.stop();
    return how;
  }

  /// Every voice to try for [gender], best first (see `resolveVoiceChain`).
  /// If the engine's voices cannot be read there is still one thing to try:
  /// its own voice at the natural pitch.
  Future<List<ResolvedVoice>> _voiceChain(
    String localeTag,
    VoiceGender gender,
  ) async {
    try {
      return resolveVoiceChain(
        voices: await _deviceVoices(),
        localeTag: localeTag,
        gender: gender,
      );
    } catch (_) {
      return [
        const ResolvedVoice(voice: null, pitch: 1.0, genderMatched: false),
      ];
    }
  }

  Future<List<DeviceVoice>> _deviceVoices() async {
    final known = _voices;
    if (known != null) return known;
    final raw = await _tts.getVoices;
    final voices = raw is List
        ? [for (final v in raw) ?DeviceVoice.tryFromMap(v)]
        : <DeviceVoice>[];
    // An empty answer may be the engine not being ready yet: ask again later.
    if (voices.isNotEmpty) _voices = voices;
    return voices;
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// How one attempt with one voice ended.
enum _Reading { read, tryNext, giveUp }
