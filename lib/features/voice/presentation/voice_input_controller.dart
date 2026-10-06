import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../services/audio/audio_clip.dart';
import '../../../services/audio/voice_recorder.dart';

enum VoiceInputStatus { idle, starting, recording }

class VoiceInputState {
  const VoiceInputState({
    this.status = VoiceInputStatus.idle,
    this.startedAt,
    this.problem,
    this.limitReached = false,
  });

  final VoiceInputStatus status;
  final DateTime? startedAt;

  /// Why the last attempt to record did not start (permission, or other).
  final RecordingStart? problem;

  /// The recording hit [VoiceInputController.maxDuration]: it must be sent.
  final bool limitReached;

  bool get isRecording => status == VoiceInputStatus.recording;
}

final voiceInputControllerProvider =
    NotifierProvider.autoDispose<VoiceInputController, VoiceInputState>(
      VoiceInputController.new,
    );

/// The recording of one voice message: start, then either [finish] (to send)
/// or [cancel]. Nothing is kept.
class VoiceInputController extends Notifier<VoiceInputState> {
  /// A message is short: a minute is plenty for a learner's turn and keeps the
  /// upload small.
  static const maxDuration = Duration(seconds: 60);

  Timer? _limit;

  @override
  VoiceInputState build() {
    // Leaving the screen mid-recording throws the recording away. (A provider
    // cannot be read from inside a dispose callback, so the recorder is
    // taken now.)
    final recorder = ref.read(voiceRecorderProvider);
    ref.onDispose(() {
      _limit?.cancel();
      if (_recording) unawaited(recorder.cancel());
    });
    return const VoiceInputState();
  }

  bool _recording = false;

  Future<void> start() async {
    if (state.status != VoiceInputStatus.idle) return;
    state = const VoiceInputState(status: VoiceInputStatus.starting);
    final outcome = await ref.read(voiceRecorderProvider).start();
    if (!ref.mounted) return;
    if (outcome != RecordingStart.started) {
      state = VoiceInputState(problem: outcome);
      return;
    }
    _recording = true;
    state = VoiceInputState(
      status: VoiceInputStatus.recording,
      startedAt: DateTime.now(),
    );
    _limit = Timer(maxDuration, () {
      if (ref.mounted && state.isRecording) {
        state = VoiceInputState(
          status: VoiceInputStatus.recording,
          startedAt: state.startedAt,
          limitReached: true,
        );
      }
    });
  }

  /// Ends the recording and returns it (`null` if it was too short).
  Future<AudioClip?> finish() async {
    if (!state.isRecording) return null;
    _limit?.cancel();
    _recording = false;
    state = const VoiceInputState();
    return ref.read(voiceRecorderProvider).stop();
  }

  Future<void> cancel() async {
    if (!state.isRecording) return;
    _limit?.cancel();
    _recording = false;
    state = const VoiceInputState();
    await ref.read(voiceRecorderProvider).cancel();
  }
}
