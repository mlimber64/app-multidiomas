import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../../services/speech/speech_service.dart';
import '../../../profile/presentation/profile_controller.dart';
import '../speech_controller.dart';

/// Reads [text] aloud in the language being learned; tapping it again while it
/// is being read stops it. With [label] it is a small text button, without it
/// an icon button. Explains, once per tap, when the phone cannot do it.
class ListenButton extends ConsumerWidget {
  const ListenButton({
    required this.speechKey,
    required this.text,
    this.label,
    this.icon = Icons.volume_up_outlined,
    this.pace = SpeechPace.normal,
    this.tooltip,
    super.key,
  });

  /// Tells this button from the others (see `speechKeyOf`).
  final String speechKey;
  final String text;
  final String? label;
  final IconData icon;
  final SpeechPace pace;
  final String? tooltip;

  Future<void> _tap(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final language = ref.read(userLearningProfileProvider).learningLanguage;
    final outcome = await ref
        .read(speechControllerProvider.notifier)
        .speak(key: speechKey, text: text, language: language, pace: pace);
    switch (outcome) {
      case SpeechOutcome.done:
        break;
      case SpeechOutcome.noVoice:
        messenger.showSnackBar(SnackBar(content: Text(l.noVoiceInstalled)));
      case SpeechOutcome.failed:
        messenger.showSnackBar(SnackBar(content: Text(l.speechFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(
      speechControllerProvider.select((s) => s.playingKey == speechKey),
    );
    final l = context.l10n;
    final shownIcon = Icon(playing ? Icons.stop_circle_outlined : icon);
    if (label == null) {
      return IconButton(
        tooltip: playing ? l.stopListening : tooltip ?? l.listen,
        onPressed: () => _tap(context, ref),
        icon: shownIcon,
        constraints: const BoxConstraints(
          minWidth: AppSizes.minTouch - 8,
          minHeight: AppSizes.minTouch - 8,
        ),
      );
    }
    return TextButton.icon(
      onPressed: () => _tap(context, ref),
      icon: shownIcon,
      label: Text(playing ? l.stopListening : label!),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, AppSizes.minTouch - 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
