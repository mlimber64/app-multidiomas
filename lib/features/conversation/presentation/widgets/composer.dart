import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../../services/audio/audio_clip.dart';
import '../../../../services/audio/voice_recorder.dart';
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
    final scheme = Theme.of(context).colorScheme;
    ref.listen(voiceInputControllerProvider, _onVoiceChange);
    final recording = ref.watch(
      voiceInputControllerProvider.select((s) => s.isRecording),
    );
    final startedAt = ref.watch(
      voiceInputControllerProvider.select((s) => s.startedAt),
    );
    return Material(
      color: scheme.surface,
      elevation: AppElevation.card,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: l.correctMeHint,
          child: FilterChip(
            label: Text(l.correctMe),
            avatar: const Icon(Icons.edit_note, size: 18),
            selected: widget.correctionMode,
            onSelected: widget.onCorrectionModeChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: l.composerHint,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
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
                        icon: const Icon(Icons.mic_none),
                      ),
                    if (!hasText) const SizedBox(width: AppSpacing.xs),
                    IconButton.filled(
                      tooltip: l.send,
                      onPressed: enabled ? _submit : null,
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
    final scheme = Theme.of(context).colorScheme;
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
        Icon(Icons.fiber_manual_record, size: 14, color: scheme.error),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Semantics(
            liveRegion: false,
            label: l.recordingNow,
            child: Text(
              '${l.recordingNow}  $minutes:$seconds',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton.filled(
          tooltip: l.recordingSend,
          onPressed: widget.onSend,
          icon: const Icon(Icons.arrow_upward),
        ),
      ],
    );
  }
}
