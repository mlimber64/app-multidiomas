import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../data/local_learning_repository.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/default_learning_engine.dart';
import '../domain/language_learning_rules.dart';
import '../domain/learning_engine.dart';
import '../domain/learning_overview.dart';
import '../domain/learning_repository.dart';

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => LocalLearningRepository(ref.watch(localStorageProvider)),
);

/// The conversation feature talks to the engine only through this binding.
///
/// The engine is stateless, so it is rebuilt when the learner's learning
/// language changes.
final learningEngineProvider = Provider<LearningEngine>(
  (ref) => DefaultLearningEngine(
    ref.watch(learningRepositoryProvider),
    rules: ref.watch(learningRulesProvider),
  ),
);

/// The rules of the learner's `learningLanguage`. Profiles only ever carry a
/// supported learning language (the repository and the UI guarantee it), and a
/// supported language is by definition one that has rules.
final learningRulesProvider = Provider<LanguageLearningRules>((ref) {
  final language = ref.watch(
    userLearningProfileProvider.select((p) => p.learningLanguage),
  );
  return learningRulesFor(language) ??
      (throw StateError('No learning rules for ${language.name}'));
});

/// A counter that changes whenever the learning memory may have changed. The
/// repository has no change stream, so whoever updates the memory (the
/// conversation, after the learning analysis) calls [bump]; everything that
/// shows the memory watches this through [learningOverviewProvider] and
/// refreshes by itself. It carries no data: the repository stays the single
/// source of truth.
final learningRevisionProvider = NotifierProvider<LearningRevision, int>(
  LearningRevision.new,
);

class LearningRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// What the learner-facing screens (Percorso, Impara, Parole, Home) show,
/// read from the memory once and shared by all of them. Recomputed when
/// [learningRevisionProvider] changes; while it recomputes, the previous value
/// stays available so screens don't flicker. A memory that cannot be read is
/// an error state (the screens show a friendly retry), never a crash.
final learningOverviewProvider = FutureProvider<LearningOverview>(
  (ref) async {
    ref.watch(learningRevisionProvider);
    final result = await ref.watch(learningEngineProvider).overview();
    return switch (result) {
      Success(value: final overview) => overview,
      Failure(:final failure) => throw failure,
    };
  },
  // Riverpod retries failed providers by default, which would keep the screens
  // on a spinner instead of the friendly error. Retrying is the user's choice
  // ("Riprova"), not automatic.
  retry: (_, _) => null,
);
