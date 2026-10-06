import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/multi_select_option_list.dart';
import '../../../shared/widgets/selectable_option_tile.dart';
import '../../profile/domain/user_learning_profile.dart';
import '../../profile/presentation/profile_labels.dart';
import 'onboarding_controller.dart';

/// Five short steps: welcome, languages, level, goals, focus. Answers live in
/// [OnboardingController]; finishing persists the profile and the router
/// redirects to Home.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return PopScope(
      // System back walks back through the steps; from the first step it
      // leaves the app as usual.
      canPop: state.isFirst,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.back();
      },
      child: Scaffold(
        body: SafeArea(
          child: ContentWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(state: state, onBack: controller.back),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: AppMotion.medium,
                      transitionBuilder: (child, animation) {
                        final dx = state.forward ? 0.08 : -0.08;
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: Offset(dx, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(state.step),
                        child: _stepBody(context, state, controller),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Cta(state: state, controller: controller),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody(
    BuildContext context,
    OnboardingState state,
    OnboardingController controller,
  ) {
    final l = context.l10n;
    return switch (state.step) {
      OnboardingStep.welcome => const _WelcomeStep(),
      OnboardingStep.languages => _LanguagesStep(
        state: state,
        controller: controller,
      ),
      OnboardingStep.level => _ChoiceStep<LanguageLevel>(
        title: l.levelQuestion,
        options: levelOptions(l),
        selected: state.level,
        onSelected: controller.selectLevel,
      ),
      OnboardingStep.goals => _MultiChoiceStep<LearningGoal>(
        title: l.goalsQuestion,
        options: goalOptions(l),
        selected: state.goals,
        min: minGoals,
        max: maxGoals,
        onToggle: controller.toggleGoal,
      ),
      OnboardingStep.focus => _MultiChoiceStep<LearningFocus>(
        title: l.focusQuestion,
        options: focusOptions(l),
        selected: state.focusAreas,
        min: minFocusAreas,
        max: maxFocusAreas,
        onToggle: controller.toggleFocus,
      ),
    };
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.onBack});

  final OnboardingState state;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // Fixed height so the layout doesn't jump when leaving the welcome step.
    return SizedBox(
      height: 48,
      child: state.isFirst
          ? null
          : Row(
              children: [
                IconButton(
                  tooltip: context.l10n.back,
                  onPressed: state.saving ? null : onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    label: context.l10n.onbStepSemantics(state.step.index, 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: state.progress),
                        duration: AppMotion.medium,
                        curve: Curves.easeOutCubic,
                        builder: (_, value, _) =>
                            LinearProgressIndicator(value: value, minHeight: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
            ),
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = switch (state.step) {
      OnboardingStep.welcome => l.onbStart,
      OnboardingStep.focus => l.onbFinish,
      _ => l.continueAction,
    };
    return FilledButton(
      onPressed: state.canContinue
          ? () async {
              if (!state.isLast) return controller.next();
              final messenger = ScaffoldMessenger.of(context);
              final saved = await controller.finish();
              if (!saved) {
                messenger.showSnackBar(SnackBar(content: Text(l.couldNotSave)));
              }
            }
          : null,
      child: Text(label),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Icon(
            Icons.chat_bubble_rounded,
            size: 36,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(AppConstants.appName, style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.welcomeTagline,
          style: theme.textTheme.titleLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(context.l10n.welcomeBody, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _ChoiceStep<T> extends StatelessWidget {
  const _ChoiceStep({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.lg),
        for (final (value, label) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
            child: SelectableOptionTile(
              title: label,
              selected: value == selected,
              onTap: () => onSelected(value),
            ),
          ),
      ],
    );
  }
}

class _MultiChoiceStep<T> extends StatelessWidget {
  const _MultiChoiceStep({
    required this.title,
    required this.options,
    required this.selected,
    required this.min,
    required this.max,
    required this.onToggle,
  });

  final String title;
  final List<(T, String)> options;
  final Set<T> selected;
  final int min;
  final int max;
  final ValueChanged<T> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        MultiSelectOptionList<T>(
          options: options,
          selected: selected,
          min: min,
          max: max,
          onToggle: onToggle,
          tileSpacing: AppSpacing.sm + 2,
        ),
      ],
    );
  }
}

/// Support language and language to learn: both single choice. Each list only
/// offers the supported languages (one each today).
class _LanguagesStep extends StatelessWidget {
  const _LanguagesStep({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget section<T>(
      String title,
      List<(T, String)> options,
      T selected,
      ValueChanged<T> onSelected,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final (value, label) in options)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
              child: SelectableOptionTile(
                title: label,
                selected: value == selected,
                onTap: () => onSelected(value),
              ),
            ),
        ],
      );
    }

    return ListView(
      children: [
        Text(
          context.l10n.onbLanguagesTitle,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        section(
          context.l10n.supportLanguageLabel,
          supportLanguageOptions(),
          state.supportLanguage,
          controller.selectSupportLanguage,
        ),
        const SizedBox(height: AppSpacing.md),
        section(
          context.l10n.learnLanguageQuestion,
          learningLanguageOptions(support: state.supportLanguage),
          state.learningLanguage,
          controller.selectLearningLanguage,
        ),
      ],
    );
  }
}
