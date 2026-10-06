import 'audio_clip.dart';

/// What happened when asked to start recording.
enum RecordingStart {
  started,

  /// The learner did not allow the microphone.
  permissionDenied,

  failed,
}

/// Records the learner's voice. Provider-agnostic: the features depend on this
/// interface only. Nothing is kept: a recording lives in memory until it is
/// sent.
abstract interface class VoiceRecorder {
  Future<RecordingStart> start();

  /// Ends the recording and returns it, or `null` when it was too short to
  /// mean anything or failed.
  Future<AudioClip?> stop();

  /// Ends the recording and throws it away.
  Future<void> cancel();

  Future<void> dispose();
}
