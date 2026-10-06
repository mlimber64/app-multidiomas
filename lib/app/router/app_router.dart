import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/conversation/presentation/conversation_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/learning/presentation/learning_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_controller.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/review/presentation/review_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/vocabulary/presentation/vocabulary_screen.dart';

abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const conversation = '/home/conversation';
  static const learning = '/home/learning';
  static const vocabulary = '/home/vocabulary';
  static const progress = '/home/progress';
  static const profile = '/home/profile';

  /// "Ripassa": a focused full-screen flow above the shell (no bottom bar).
  static const review = '/review';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirects when onboarding state changes without rebuilding
  // the router (which would reset navigation state).
  bool isDone() => ref.read(userLearningProfileProvider).onboardingCompleted;
  final refresh = ValueNotifier<bool>(isDone());
  ref.listen(
    userLearningProfileProvider,
    (_, next) => refresh.value = next.onboardingCompleted,
  );
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!isDone()) return atOnboarding ? null : AppRoutes.onboarding;
      return atOnboarding ? AppRoutes.home : null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(path: AppRoutes.review, builder: (_, _) => const ReviewScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(navigationShell: shell),
        branches: [
          _branch(AppRoutes.home, (_, _) => const HomeScreen()),
          _branch(AppRoutes.conversation, (_, _) => const ConversationScreen()),
          _branch(AppRoutes.learning, (_, _) => const LearningScreen()),
          _branch(AppRoutes.vocabulary, (_, _) => const VocabularyScreen()),
          _branch(AppRoutes.progress, (_, _) => const ProgressScreen()),
          _branch(AppRoutes.profile, (_, _) => const ProfileScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, GoRouterWidgetBuilder builder) =>
    StatefulShellBranch(
      routes: [GoRoute(path: path, builder: builder)],
    );
