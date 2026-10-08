import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/daily_routine.dart';
import 'daily_routine_controller.dart';

// NUEVO: la actividad de práctica que muestran la racha de Inicio y la semana
// de Progreso. No hay un contador de racha en la app: se deriva de las rutinas
// diarias ya guardadas (un día cuenta si se hizo algún paso de su rutina), así
// que solo ve los últimos días que guarda la rutina y solo los días en que se
// abrió la app.
class PracticeActivity {
  const PracticeActivity({
    required this.streak,
    required this.week,
    required this.todayIndex,
  });

  /// Sin actividad conocida.
  static const empty = PracticeActivity(
    streak: 0,
    week: [false, false, false, false, false, false, false],
    todayIndex: 0,
  );

  /// Días seguidos con práctica, contando hasta hoy, o hasta ayer si hoy aún
  /// no se ha practicado.
  final int streak;

  /// De lunes a domingo de la semana actual: `true` si ese día hubo práctica.
  final List<bool> week;

  /// Posición de hoy en [week] (0 = lunes).
  final int todayIndex;

  bool get practicedToday => week[todayIndex];
}

/// Cuántos días hacia atrás se miran (lo que la rutina conserva).
const _lookBackDays = 14;

/// Pura: de los días con práctica y de hoy, la racha y la semana.
PracticeActivity practiceActivityOf(Set<String> practicedDays, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  bool practiced(DateTime d) => practicedDays.contains(DailyRoutine.dateOf(d));

  var streak = 0;
  var cursor = practiced(day)
      ? day
      : DateTime(day.year, day.month, day.day - 1);
  while (practiced(cursor)) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }

  final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
  final week = [
    for (var i = 0; i < 7; i++)
      practiced(DateTime(monday.year, monday.month, monday.day + i)),
  ];
  return PracticeActivity(
    streak: streak,
    week: week,
    todayIndex: day.weekday - 1,
  );
}

// NUEVO: lee las rutinas guardadas del idioma que se aprende y las resume. Se
// recalcula cuando cambia la rutina de hoy (al completar un paso).
final practiceActivityProvider = FutureProvider<PracticeActivity>((ref) async {
  ref.watch(dailyRoutineProvider);
  final language = ref.watch(
    userLearningProfileProvider.select((p) => p.learningLanguage),
  );
  final repository = ref.watch(dailyRoutineRepositoryProvider);
  final now = ref.read(dailyRoutineClockProvider)();
  final today = DateTime(now.year, now.month, now.day);

  final practiced = <String>{};
  for (var back = 0; back < _lookBackDays; back++) {
    final key = DailyRoutine.dateOf(
      DateTime(today.year, today.month, today.day - back),
    );
    final loaded = await repository.load(key, language);
    if (loaded case Success(
      value: final routine?,
    ) when routine.completedCount > 0) {
      practiced.add(key);
    }
  }
  return practiceActivityOf(practiced, now);
});
