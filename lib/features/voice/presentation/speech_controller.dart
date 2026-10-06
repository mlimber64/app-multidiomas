import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../services/speech/speech_service.dart';
import '../../profile/domain/user_learning_profile.dart';
import '../domain/speech_text.dart';

/// What is being read aloud right now. [playingKey] names the thing (a
/// message, one button of a correction), so only its own button shows "stop".
class SpeechState {
  const SpeechState({this.playingKey});

  final String? playingKey;
}

/// Keys that tell the buttons apart: the teacher's message, and each way of
/// listening to one correction.
String speechKeyOf(String messageId) => 'message:$messageId';
String correctionSpeechKey(String messageId, int index, String mode) =>
    'correction:$messageId:$index:$mode';

final speechControllerProvider =
    NotifierProvider<SpeechController, SpeechState>(SpeechController.new);

/// Reads texts aloud, one at a time. Tapping what is already being read stops
/// it.
class SpeechController extends Notifier<SpeechState> {
  @override
  SpeechState build() => const SpeechState();

  /// Reads [text] in [language]. Returns [SpeechOutcome.noVoice] when the
  /// phone has no voice for it, so the screen can say how to get one.
  Future<SpeechOutcome> speak({
    required String key,
    required String text,
    required AppLanguage language,
    SpeechPace pace = SpeechPace.normal,
  }) async {
    final service = ref.read(speechServiceProvider);
    if (state.playingKey == key) {
      await stop();
      return SpeechOutcome.done;
    }
    state = SpeechState(playingKey: key);
    final outcome = await service.speak(
      text,
      localeTag: speechLocaleTag(language),
      pace: pace,
    );
    // Only clear what is still ours: something else may have taken over.
    if (ref.mounted && state.playingKey == key) state = const SpeechState();
    return outcome;
  }

  Future<void> stop() async {
    state = const SpeechState();
    await ref.read(speechServiceProvider).stop();
  }
}
