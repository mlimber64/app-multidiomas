import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../learning/presentation/learning_providers.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/local_review_repository.dart';
import '../domain/exercise_generator.dart';
import '../domain/review_engine.dart';
import '../domain/review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => LocalReviewRepository(ref.watch(localStorageProvider)),
);

/// No screen consumes the engine yet; future review experiences talk to it
/// only through this binding. Stateless, so it is rebuilt when the learner's
/// learning language changes.
final reviewEngineProvider = Provider<ReviewEngine>(
  (ref) => DefaultReviewEngine(
    ref.watch(learningRepositoryProvider),
    ref.watch(reviewRepositoryProvider),
    learningLanguage: ref.watch(
      userLearningProfileProvider.select((p) => p.learningLanguage),
    ),
    evidence: ref.watch(practiceEvidenceRecorderProvider),
  ),
);

/// Pure and stateless: a review item and the learning summary in, an exercise
/// (or an "unavailable" failure) out.
final exerciseGeneratorProvider = Provider<ExerciseGenerator>(
  (ref) => DefaultExerciseGenerator(
    learningLanguage: ref.watch(
      userLearningProfileProvider.select((p) => p.learningLanguage),
    ),
  ),
);
