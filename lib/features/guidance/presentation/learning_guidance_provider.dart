import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../daily_routine/presentation/daily_routine_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/learning_guidance.dart';
import '../domain/learning_guidance_resolver.dart';

/// The next step of today's routine and why, derived from the routine already
/// loaded. `null` while it loads, if it failed, or if it has nothing to
/// practice. It plans, reads and writes nothing itself.
final learningGuidanceProvider = Provider<LearningGuidance?>((ref) {
  final routine = ref.watch(dailyRoutineProvider).value;
  if (routine == null) return null;
  final goals = ref.watch(userLearningProfileProvider.select((p) => p.goals));
  return const LearningGuidanceResolver().resolve(routine, goals: goals);
});
