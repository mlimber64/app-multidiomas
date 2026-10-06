import 'dart:io';

import 'package:record/record.dart';

import 'audio_clip.dart';
import 'voice_recorder.dart';

/// [VoiceRecorder] on the `record` package: 16 kHz mono WAV, which the AI
/// understands directly (about 2 MB per minute). The file only exists while
/// recording: it is read into memory and deleted when the recording ends.
class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder([AudioRecorder? recorder])
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final _watch = Stopwatch();

  /// Shorter than this is a stray tap, not a message.
  static const minDuration = Duration(milliseconds: 600);

  @override
  Future<RecordingStart> start() async {
    try {
      if (!await _recorder.hasPermission()) {
        return RecordingStart.permissionDenied;
      }
      final path =
          '${Directory.systemTemp.path}/voice_${DateTime.now().microsecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _watch
        ..reset()
        ..start();
      return RecordingStart.started;
    } catch (_) {
      return RecordingStart.failed;
    }
  }

  @override
  Future<AudioClip?> stop() async {
    _watch.stop();
    final duration = _watch.elapsed;
    try {
      final path = await _recorder.stop();
      if (path == null) return null;
      final file = File(path);
      try {
        if (duration < minDuration) return null;
        return AudioClip(
          bytes: await file.readAsBytes(),
          mimeType: 'audio/wav',
          duration: duration,
        );
      } finally {
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    _watch.stop();
    try {
      final path = await _recorder.stop();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {}
  }
}
