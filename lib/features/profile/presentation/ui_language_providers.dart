import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/user_learning_profile.dart';
import 'profile_controller.dart';

/// The interface language a device locale maps to: its own when the app has
/// that interface, English otherwise.
AppLanguage uiLanguageForLocale(Locale locale) {
  for (final language in availableUiLanguages) {
    if (language.code == locale.languageCode) return language;
  }
  return AppLanguage.english;
}

/// What the device asks for. Overridden in tests.
final deviceUiLanguageProvider = Provider<AppLanguage>(
  (ref) => uiLanguageForLocale(PlatformDispatcher.instance.locale),
);

/// The language picked in the onboarding so far (before a profile exists), so
/// the interface switches the moment the learner chooses theirs.
final onboardingUiLanguageProvider =
    NotifierProvider<OnboardingUiLanguage, AppLanguage?>(
      OnboardingUiLanguage.new,
    );

class OnboardingUiLanguage extends Notifier<AppLanguage?> {
  @override
  AppLanguage? build() => null;

  void choose(AppLanguage language) => state = language;
}

/// The language the interface is shown in: the profile's once onboarding is
/// done, else what the learner has picked so far, else the device's.
final uiLanguageProvider = Provider<AppLanguage>((ref) {
  final profile = ref.watch(userLearningProfileProvider);
  if (profile.onboardingCompleted) return profile.effectiveUiLanguage;
  return ref.watch(onboardingUiLanguageProvider) ??
      ref.watch(deviceUiLanguageProvider);
});

final appLocaleProvider = Provider<Locale>(
  (ref) => Locale(ref.watch(uiLanguageProvider).code),
);
