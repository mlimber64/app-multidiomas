import 'package:flutter_tts/flutter_tts.dart';

import 'speech_service.dart';

/// [SpeechService] on the device's text-to-speech engine (`flutter_tts`).
/// Needs no network and no key; the voices are the ones installed on the
/// phone.
class FlutterTtsSpeechService implements SpeechService {
  FlutterTtsSpeechService([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  /// Android's speech rate: 0.5 is the normal pace of the engine.
  static const _normalRate = 0.5;
  static const _slowRate = 0.25;

  @override
  Future<SpeechOutcome> speak(
    String text, {
    required String localeTag,
    SpeechPace pace = SpeechPace.normal,
  }) async {
    if (text.trim().isEmpty) return SpeechOutcome.done;
    try {
      final available = await _tts.isLanguageAvailable(localeTag);
      if (available != true && available != 1) return SpeechOutcome.noVoice;
      await _tts.stop();
      await _tts.setLanguage(localeTag);
      await _tts.setSpeechRate(
        pace == SpeechPace.slow ? _slowRate : _normalRate,
      );
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text);
      return SpeechOutcome.done;
    } catch (_) {
      return SpeechOutcome.failed;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
