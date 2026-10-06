/// How fast to read a text aloud. Slow is for listening to how something is
/// pronounced or spelled.
enum SpeechPace { normal, slow }

/// What happened when asked to speak.
enum SpeechOutcome {
  /// It was read to the end (or stopped by the learner).
  done,

  /// The device has no voice for that language installed.
  noVoice,

  /// Anything else; never an exception.
  failed,
}

/// Reads text aloud. Provider-agnostic: today the device's text-to-speech
/// engine; the features depend on this interface only.
abstract interface class SpeechService {
  /// Reads [text] with a voice for [localeTag] (BCP-47, e.g. `it-IT`).
  /// Completes when the reading ends. Reading something else first stops what
  /// is being read.
  Future<SpeechOutcome> speak(
    String text, {
    required String localeTag,
    SpeechPace pace = SpeechPace.normal,
  });

  Future<void> stop();
}
