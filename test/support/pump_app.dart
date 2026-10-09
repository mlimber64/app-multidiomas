import 'package:parla_con_me/features/reminders/presentation/reminder_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/app.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/features/profile/data/local_user_learning_profile_repository.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_controller.dart';
import 'package:parla_con_me/features/profile/presentation/ui_language_providers.dart';

import 'fake_notification_service.dart';
import 'in_memory_local_storage.dart';

/// Boots the app like `main()` does: the profile is loaded from [storage]
/// (or taken from [profile]) and preloaded before the first frame. Uses a
/// phone-sized viewport.
Future<void> pumpApp(
  WidgetTester tester,
  InMemoryLocalStorage storage, {
  UserLearningProfile? profile,
  List<Override> overrides = const [],
  FakeNotificationService? notifications,
}) async {
  tester.view.physicalSize = const Size(1080, 4500);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final UserLearningProfile loaded =
      profile ??
      (await LocalUserLearningProfileRepository(
        storage,
      ).load()).when<UserLearningProfile>(
        success: (p) => p,
        failure: (_) => UserLearningProfile.empty,
      );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // No real notifications in tests, and no timer left pending at
        // midnight. A test that wants to look at the notifications passes its
        // own [notifications] (a provider cannot be overridden twice).
        notificationServiceProvider.overrideWithValue(
          notifications ?? FakeNotificationService(),
        ),
        reminderMidnightRefreshProvider.overrideWithValue(false),
        ...overrides,
        // Tests run on a fixed device language, not on the machine's.
        deviceUiLanguageProvider.overrideWithValue(AppLanguage.spanish),
        localStorageProvider.overrideWithValue(storage),
        userLearningProfileProvider.overrideWith(
          () => PreloadedUserLearningProfileController(loaded),
        ),
      ],
      child: const ParlaConMeApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Spanish speaker learning Italian, with the interface in Italian (an
/// explicit choice) so screen tests read the same Italian texts.
const onboardedProfile = UserLearningProfile(
  uiLanguage: AppLanguage.italian,
  level: LanguageLevel.a2,
  goals: {LearningGoal.speakConfidently},
  focusAreas: {LearningFocus.conversation},
  onboardingCompleted: true,
);
