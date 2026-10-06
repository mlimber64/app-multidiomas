import 'dart:typed_data';

/// A short recording: the bytes and what they are. Provider-agnostic and
/// ephemeral: it is sent to the AI with one message and never stored.
class AudioClip {
  const AudioClip({
    required this.bytes,
    required this.mimeType,
    required this.duration,
  });

  final Uint8List bytes;

  /// For example `audio/wav`.
  final String mimeType;
  final Duration duration;
}
