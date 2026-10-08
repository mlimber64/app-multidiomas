import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../../learning/presentation/learning_providers.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../review/presentation/review_providers.dart';
import '../data/local_daily_routine_repository.dart';
import '../domain/daily_routine.dart';
import '../domain/daily_routine_planner.dart';
import '../domain/daily_routine_repository.dart';

final dailyRoutineRepositoryProvider = Provider<DailyRoutineRepository>(
  (ref) => LocalDailyRoutineRepository(ref.watch(localStorageProvider)),
);

/// The planner, wired to the systems of the learner's current language (the
/// review and learning engines already follow it).
final dailyRoutinePlannerProvider = Provider<DailyRoutinePlanner>(
  (ref) => DailyRoutinePlanner(
    reviews: ref.watch(reviewEngineProvider),
    exercises: ref.watch(exerciseGeneratorProvider),
    learning: ref.watch(learningEngineProvider),
  ),
);

/// Source of "now" for the routine. Overridden in tests.
final dailyRoutineClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Today's routine in the learner's language: loaded if it was already made,
/// planned and saved if not. Changing the language to learn loads the routine
/// of that language.
final dailyRoutineProvider =
    AsyncNotifierProvider<DailyRoutineController, DailyRoutine>(
      DailyRoutineController.new,
      // A failure is shown with a "try again" button, not retried silently.
      retry: (_, _) => null,
    );

class DailyRoutineController extends AsyncNotifier<DailyRoutine> {
  bool _busy = false;

  @override
  Future<DailyRoutine> build() async {
    final planner = ref.watch(dailyRoutinePlannerProvider);
    final repository = ref.watch(dailyRoutineRepositoryProvider);
    final profile = ref.read(userLearningProfileProvider);
    final now = ref.read(dailyRoutineClockProvider)();

    // The routine of today is made once: if it exists it is the one used, even
    // when the learning state has moved since.
    final stored = await repository.load(
      DailyRoutine.dateOf(now),
      profile.learningLanguage,
    );
    if (stored case Success(value: final routine?)) return routine;

    final planned = await planner.plan(now: now, profile: profile);
    final routine = switch (planned) {
      Success(value: final r) => r,
      Failure(:final failure) => throw failure,
    };
    // Not being able to save is not a reason to hide the routine: it is shown
    // and planned again next time.
    await repository.save(routine);
    return routine;
  }

  /// Marks [step] (1, 2 or 3) as done and saves it. Returns whether it was
  /// accepted: ignored when the routine is not loaded, the step is not the
  /// next one, it is already done, or another change is being saved.
  Future<bool> completeStep(int step) async {
    final current = state.value;
    if (current == null || _busy) return false;
    final next = switch (step) {
      1 => current.completeStep1(),
      2 => current.completeStep2(),
      3 => current.completeStep3(),
      _ => null,
    };
    if (next == null) return false;

    _busy = true;
    try {
      final saved = await ref.read(dailyRoutineRepositoryProvider).save(next);
      if (saved is Failure<void> || !ref.mounted) return false;
      state = AsyncData(next);
      return true;
    } finally {
      _busy = false;
    }
  }

  /// Tries again after an error.
  void retry() => ref.invalidateSelf();

  /// If the day has changed since the routine was loaded (the app stayed open
  /// overnight), loads the routine of the new day.
  void refreshForToday() {
    final loaded = state.value;
    if (loaded == null) return;
    final today = DailyRoutine.dateOf(ref.read(dailyRoutineClockProvider)());
    if (loaded.date != today) ref.invalidateSelf();
  }
}
