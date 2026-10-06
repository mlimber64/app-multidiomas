import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/domain/user_learning_profile.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../profile/presentation/ui_language_providers.dart';

enum OnboardingStep { welcome, languages, level, goals, focus }

/// In-progress answers. Lives only while onboarding is on screen; nothing is
/// persisted until [OnboardingController.finish].
class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.welcome,
    this.supportLanguage = defaultSupportLanguage,
    this.learningLanguage = defaultLearningLanguage,
    this.level,
    this.goals = const <LearningGoal>{},
    this.focusAreas = const <LearningFocus>{},
    this.forward = true,
    this.saving = false,
  });

  final OnboardingStep step;

  /// Languages start on the device's language (when the app has it) and the
  /// first learning language that is not the same one.
  final AppLanguage supportLanguage;
  final AppLanguage learningLanguage;
  final LanguageLevel? level;
  final Set<LearningGoal> goals;
  final Set<LearningFocus> focusAreas;

  /// Direction of the last step change, used to pick the transition.
  final bool forward;
  final bool saving;

  bool get isFirst => step == OnboardingStep.welcome;
  bool get isLast => step == OnboardingStep.focus;

  /// Questions are steps 1..4; the welcome step has no progress.
  double get progress => step.index / (OnboardingStep.values.length - 1);

  bool get canContinue =>
      !saving &&
      switch (step) {
        OnboardingStep.welcome => true,
        OnboardingStep.languages => _profile.languagePair.isSupported,
        OnboardingStep.level => level != null,
        OnboardingStep.goals => _profile.hasValidGoals,
        OnboardingStep.focus => _profile.hasValidFocusAreas,
      };

  /// The answers so far as a profile (not yet onboarded, not saved).
  UserLearningProfile get _profile => UserLearningProfile(
    supportLanguage: supportLanguage,
    learningLanguage: learningLanguage,
    level: level,
    goals: goals,
    focusAreas: focusAreas,
  );

  OnboardingState copyWith({
    OnboardingStep? step,
    AppLanguage? supportLanguage,
    AppLanguage? learningLanguage,
    LanguageLevel? level,
    Set<LearningGoal>? goals,
    Set<LearningFocus>? focusAreas,
    bool? forward,
    bool? saving,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      supportLanguage: supportLanguage ?? this.supportLanguage,
      learningLanguage: learningLanguage ?? this.learningLanguage,
      level: level ?? this.level,
      goals: goals ?? this.goals,
      focusAreas: focusAreas ?? this.focusAreas,
      forward: forward ?? this.forward,
      saving: saving ?? this.saving,
    );
  }
}

final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final support = ref.read(deviceUiLanguageProvider);
    return OnboardingState(
      supportLanguage: support,
      learningLanguage: defaultLearningLanguageFor(support),
    );
  }

  /// The interface follows the language the learner picks as theirs. The two
  /// languages of a pair are never the same.
  void selectSupportLanguage(AppLanguage value) {
    ref.read(onboardingUiLanguageProvider.notifier).choose(value);
    state = state.copyWith(
      supportLanguage: value,
      learningLanguage: state.learningLanguage == value
          ? defaultLearningLanguageFor(value)
          : null,
    );
  }

  void selectLearningLanguage(AppLanguage value) =>
      state = state.copyWith(learningLanguage: value);
  void selectLevel(LanguageLevel value) => state = state.copyWith(level: value);

  /// Multi-select: toggles [value] within the limits of the question.
  void toggleGoal(LearningGoal value) => state = state.copyWith(
    goals: toggleSelection(
      state.goals,
      value,
      max: maxGoals,
      exclusive: LearningGoal.exclusive,
    ),
  );

  void toggleFocus(LearningFocus value) => state = state.copyWith(
    focusAreas: toggleSelection(state.focusAreas, value, max: maxFocusAreas),
  );

  void next() {
    if (!state.canContinue || state.isLast) return;
    state = state.copyWith(
      step: OnboardingStep.values[state.step.index + 1],
      forward: true,
    );
  }

  void back() {
    if (state.isFirst || state.saving) return;
    state = state.copyWith(
      step: OnboardingStep.values[state.step.index - 1],
      forward: false,
    );
  }

  /// Saves the profile with `onboardingCompleted: true`. The router then
  /// redirects to Home. Returns `false` if the profile could not be saved.
  Future<bool> finish() async {
    if (!state.canContinue || !state.isLast) return false;
    state = state.copyWith(saving: true);
    final saved = await ref
        .read(userLearningProfileProvider.notifier)
        .save(state._profile.copyWith(onboardingCompleted: true));
    // If saving succeeded the router leaves this screen and the provider is
    // disposed, so only touch state on failure.
    if (!saved) state = state.copyWith(saving: false);
    return saved;
  }
}
