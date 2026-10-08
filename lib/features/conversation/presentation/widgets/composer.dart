import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../../services/audio/audio_clip.dart';
import '../../../../services/audio/voice_recorder.dart';
import '../../../../shared/ui/app_action_chip.dart';
import '../../../voice/presentation/speech_controller.dart';
import '../../../voice/presentation/voice_input_controller.dart';

/// Bottom input: "Correggimi" toggle, text field, microphone and send button.
/// The send button is disabled while the field is empty or a send is not
/// allowed, which also prevents duplicate sends. While a voice message is being
/// recorded the field gives way to a recording bar (cancel, time, send).
class Composer extends ConsumerStatefulWidget {
  const Composer({
    required this.canSend,
    required this.sending,
    required this.correctionMode,
    required this.onSend,
    required this.onSendVoice,
    required this.onCorrectionModeChanged,
    super.key,
  });

  final bool canSend;
  final bool sending;
  final bool correctionMode;
  final ValueChanged<String> onSend;
  final ValueChanged<AudioClip> onSendVoice;
  final ValueChanged<bool> onCorrectionModeChanged;

  @override
  ConsumerState<Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<Composer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.canSend) return;
    _controller.clear();
    widget.onSend(text);
  }

  Future<void> _startRecording() async {
    if (!widget.canSend) return;
    // Do not record the teacher's own voice.
    await ref.read(speechControllerProvider.notifier).stop();
    await ref.read(voiceInputControllerProvider.notifier).start();
  }

  Future<void> _finishRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final clip = await ref.read(voiceInputControllerProvider.notifier).finish();
    if (clip == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.recordingTooShort)));
      return;
    }
    if (widget.canSend) widget.onSendVoice(clip);
  }

  void _onVoiceChange(VoiceInputState? previous, VoiceInputState next) {
    if (next.limitReached && !(previous?.limitReached ?? false)) {
      unawaited(_finishRecording());
    }
    final problem = next.problem;
    if (problem != null && problem != previous?.problem) {
      final l = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            problem == RecordingStart.permissionDenied
                ? l.micDenied
                : l.micFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(voiceInputControllerProvider, _onVoiceChange);
    final recording = ref.watch(
      voiceInputControllerProvider.select((s) => s.isRecording),
    );
    final startedAt = ref.watch(
      voiceInputControllerProvider.select((s) => s.startedAt),
    );
    // NUEVO: zona de entrada del diseño: fondo blanco con una línea suave
    // encima, chips de acción, campo de 52 con borde verde y botones redondos.
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.inputAreaBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: recording
              ? _RecordingBar(
                  startedAt: startedAt ?? DateTime.now(),
                  onCancel: () =>
                      ref.read(voiceInputControllerProvider.notifier).cancel(),
                  onSend: _finishRecording,
                )
              : _typing(context),
        ),
      ),
    );
  }

  Widget _typing(BuildContext context) {
    final l = context.l10n;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
      borderSide: const BorderSide(color: AppColors.green, width: 1.5),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: l.correctMeHint,
          child: AppActionChip(
            label: l.correctMe,
            icon: Icons.edit_note,
            variant: AppActionChipVariant.neutral,
            selected: widget.correctionMode,
            onPressed: () =>
                widget.onCorrectionModeChanged(!widget.correctionMode),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: l.composerHint,
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.control,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  border: fieldBorder,
                  enabledBorder: fieldBorder,
                  focusedBorder: fieldBorder,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                final enabled = widget.canSend && hasText;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Speaking is an alternative to typing, so it is offered
                    // while there is nothing typed.
                    if (!hasText)
                      IconButton.outlined(
                        tooltip: l.recordVoice,
                        onPressed: widget.canSend ? _startRecording : null,
                        style: IconButton.styleFrom(
                          fixedSize: const Size.square(AppSizes.control),
                          foregroundColor: AppColors.green,
                          backgroundColor: AppColors.mintSoft,
                          side: const BorderSide(color: AppColors.green),
                        ),
                        icon: const Icon(Icons.mic_none),
                      ),
                    if (!hasText) const SizedBox(width: AppSpacing.xs),
                    IconButton.filled(
                      tooltip: l.send,
                      onPressed: enabled ? _submit : null,
                      style: IconButton.styleFrom(
                        fixedSize: const Size.square(AppSizes.control),
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.track,
                        disabledForegroundColor: AppColors.placeholder,
                      ),
                      icon: widget.sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(Icons.arrow_upward),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// What replaces the field while recording: cancel, a red dot with the time,
/// and send. Time is shown as text, so it does not depend on the dot's color.
class _RecordingBar extends StatefulWidget {
  const _RecordingBar({
    required this.startedAt,
    required this.onCancel,
    required this.onSend,
  });

  final DateTime startedAt;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  State<_RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<_RecordingBar> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final elapsed = DateTime.now().difference(widget.startedAt);
    final minutes = elapsed.inMinutes;
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Row(
      children: [
        IconButton(
          tooltip: l.recordingCancel,
          onPressed: widget.onCancel,
          icon: const Icon(Icons.delete_outline),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Icon(
          Icons.fiber_manual_record,
          size: 14,
          color: AppColors.errorStrike,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Semantics(
            liveRegion: false,
            label: l.recordingNow,
            child: Text(
              '${l.recordingNow}  $minutes:$seconds',
              style: AppTextStyles.bodyStrong,
            ),
          ),
        ),
        IconButton.filled(
          tooltip: l.recordingSend,
          onPressed: widget.onSend,
          style: IconButton.styleFrom(
            fixedSize: const Size.square(AppSizes.control),
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.arrow_upward),
        ),
      ],
    );
  }
}
