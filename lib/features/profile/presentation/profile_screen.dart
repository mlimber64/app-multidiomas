import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/multi_select_option_list.dart';
import '../../../shared/widgets/selectable_option_tile.dart';
import '../domain/user_learning_profile.dart';
import 'profile_controller.dart';
import 'profile_labels.dart';

/// Shows the learner's saved preferences and lets them change each one.
/// There is no account: everything stays on this device.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userLearningProfileProvider);
    final controller = ref.read(userLearningProfileProvider.notifier);
    final theme = Theme.of(context);
    final l = context.l10n;

    Future<void> saveProfile(
      ScaffoldMessengerState messenger,
      UserLearningProfile updated,
    ) async {
      final saved = await controller.save(updated);
      if (!saved) {
        messenger.showSnackBar(SnackBar(content: Text(l.couldNotSave)));
      }
    }

    Future<void> edit<T>(
      String title,
      List<(T, String)> options,
      T? current,
      UserLearningProfile Function(T) apply,
    ) async {
      final messenger = ScaffoldMessenger.of(context);
      final picked = await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            _OptionSheet<T>(title: title, options: options, selected: current),
      );
      if (picked == null || picked == current) return;
      await saveProfile(messenger, apply(picked));
    }

    Future<void> editMulti<T extends Enum>(
      String title,
      List<(T, String)> options,
      Set<T> current, {
      required int min,
      required int max,
      required UserLearningProfile Function(Set<T>) apply,
      T? exclusive,
    }) async {
      final messenger = ScaffoldMessenger.of(context);
      final picked = await showModalBottomSheet<Set<T>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _MultiOptionSheet<T>(
          title: title,
          options: options,
          initial: current,
          min: min,
          max: max,
          exclusive: exclusive,
        ),
      );
      if (picked == null || setEquals(picked, current)) return;
      await saveProfile(messenger, apply(picked));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.navProfile)),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(l.profileHeading, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _PreferenceTile(
                    label: l.supportLanguageLabel,
                    value: profile.supportLanguage.label,
                    onTap: () => edit<AppLanguage>(
                      l.supportSheetTitle,
                      supportLanguageOptions(),
                      profile.supportLanguage,
                      // The language to learn moves aside if it is the same.
                      (v) => profile.copyWith(
                        supportLanguage: v,
                        learningLanguage: v == profile.learningLanguage
                            ? defaultLearningLanguageFor(v)
                            : null,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _PreferenceTile(
                    label: l.learningLanguageRow,
                    value: profile.learningLanguage.label,
                    onTap: () => edit<AppLanguage>(
                      l.learnSheetTitle,
                      learningLanguageOptions(support: profile.supportLanguage),
                      profile.learningLanguage,
                      (v) => profile.copyWith(learningLanguage: v),
                    ),
                  ),
                  const Divider(height: 1),
                  _PreferenceTile(
                    label: l.uiLanguageLabel,
                    value: profile.effectiveUiLanguage.label,
                    // Choosing the support language goes back to "follow it".
                    onTap: () => edit<AppLanguage>(
                      l.uiSheetTitle,
                      uiLanguageOptions(),
                      profile.effectiveUiLanguage,
                      (v) => v == profile.supportLanguage
                          ? profile.copyWith(clearUiLanguage: true)
                          : profile.copyWith(uiLanguage: v),
                    ),
                  ),
                  const Divider(height: 1),
                  _PreferenceTile(
                    label: l.rowLevel,
                    value: profile.level?.label(l),
                    onTap: () => edit<LanguageLevel>(
                      l.levelQuestion,
                      levelOptions(l),
                      profile.level,
                      (v) => profile.copyWith(level: v),
                    ),
                  ),
                  const Divider(height: 1),
                  _PreferenceTile(
                    label: l.rowGoals,
                    value: joinLabels(
                      l,
                      LearningGoal.values,
                      profile.goals,
                      (g) => g.label(l),
                    ),
                    onTap: () => editMulti<LearningGoal>(
                      l.goalsQuestion,
                      goalOptions(l),
                      profile.goals,
                      min: minGoals,
                      max: maxGoals,
                      exclusive: LearningGoal.exclusive,
                      apply: (v) => profile.copyWith(goals: v),
                    ),
                  ),
                  const Divider(height: 1),
                  _PreferenceTile(
                    label: l.rowAreas,
                    value: joinLabels(
                      l,
                      LearningFocus.values,
                      profile.focusAreas,
                      (f) => f.label(l),
                    ),
                    onTap: () => editMulti<LearningFocus>(
                      l.focusQuestion,
                      focusOptions(l),
                      profile.focusAreas,
                      min: minFocusAreas,
                      max: maxFocusAreas,
                      apply: (v) => profile.copyWith(focusAreas: v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                title: Text(l.speakRepliesLabel),
                subtitle: Text(l.speakRepliesHint),
                value: profile.speakReplies,
                onChanged: (v) => saveProfile(
                  ScaffoldMessenger.of(context),
                  profile.copyWith(speakReplies: v),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.teacherVoiceLabel,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l.teacherVoiceHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedButton<VoiceGender>(
                      segments: [
                        ButtonSegment(
                          value: VoiceGender.female,
                          label: Text(l.voiceFemale),
                          icon: const Icon(Icons.record_voice_over_outlined),
                        ),
                        ButtonSegment(
                          value: VoiceGender.male,
                          label: Text(l.voiceMale),
                          icon: const Icon(Icons.record_voice_over),
                        ),
                      ],
                      selected: {profile.teacherVoice},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) => saveProfile(
                        ScaffoldMessenger.of(context),
                        profile.copyWith(teacherVoice: selection.first),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l.profileLocalNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: AppSizes.minTouch,
      title: Text(label),
      subtitle: Text(value ?? context.l10n.notSet),
      trailing: const Icon(Icons.edit_outlined),
      onTap: onTap,
    );
  }
}

class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<(T, String)> options;
  final T? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          for (final (value, label) in options)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SelectableOptionTile(
                title: label,
                selected: value == selected,
                onTap: () => Navigator.of(context).pop(value),
              ),
            ),
        ],
      ),
    );
  }
}

/// Multi-select editor: the learner toggles options and confirms with "Salva",
/// which stays disabled until the selection satisfies the minimum.
class _MultiOptionSheet<T extends Enum> extends StatefulWidget {
  const _MultiOptionSheet({
    required this.title,
    required this.options,
    required this.initial,
    required this.min,
    required this.max,
    required this.exclusive,
  });

  final String title;
  final List<(T, String)> options;
  final Set<T> initial;
  final int min;
  final int max;
  final T? exclusive;

  @override
  State<_MultiOptionSheet<T>> createState() => _MultiOptionSheetState<T>();
}

class _MultiOptionSheetState<T extends Enum>
    extends State<_MultiOptionSheet<T>> {
  late Set<T> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          MultiSelectOptionList<T>(
            options: widget.options,
            selected: _selected,
            min: widget.min,
            max: widget.max,
            onToggle: (v) => setState(
              () => _selected = toggleSelection(
                _selected,
                v,
                max: widget.max,
                exclusive: widget.exclusive,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _selected.length >= widget.min
                ? () => Navigator.of(context).pop(_selected)
                : null,
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  }
}
