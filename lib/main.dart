import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/profile/domain/user_learning_profile.dart';
import 'features/profile/presentation/profile_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the saved profile before the first frame so routing (onboarding vs
  // Home) is correct from the start. A read failure is treated as "no
  // profile yet".
  final container = ProviderContainer();
  final loaded = await container
      .read(userLearningProfileRepositoryProvider)
      .load();
  final profile = loaded.when(
    success: (p) => p,
    failure: (_) => UserLearningProfile.empty,
  );
  container.dispose();

  runApp(
    ProviderScope(
      overrides: [
        userLearningProfileProvider.overrideWith(
          () => PreloadedUserLearningProfileController(profile),
        ),
      ],
      child: const ParlaConMeApp(),
    ),
  );
}
