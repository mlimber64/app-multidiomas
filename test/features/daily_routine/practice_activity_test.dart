import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/daily_routine/presentation/practice_activity.dart';

void main() {
  // Miércoles 2026-03-11.
  final today = DateTime(2026, 3, 11, 15);

  test('sin práctica: racha 0 y semana vacía', () {
    final a = practiceActivityOf({}, today);
    expect(a.streak, 0);
    expect(a.week, everyElement(isFalse));
    expect(a.todayIndex, 2);
    expect(a.practicedToday, isFalse);
  });

  test('cuenta los días seguidos hasta hoy', () {
    final a = practiceActivityOf({
      '2026-03-11',
      '2026-03-10',
      '2026-03-09',
      '2026-03-07',
    }, today);
    expect(a.streak, 3);
    expect(a.week, [true, true, true, false, false, false, false]);
    expect(a.practicedToday, isTrue);
  });

  test('si hoy aún no se practicó, la racha de ayer sigue viva', () {
    final a = practiceActivityOf({'2026-03-10', '2026-03-09'}, today);
    expect(a.streak, 2);
    expect(a.practicedToday, isFalse);
  });

  test('un día sin práctica antes de ayer rompe la racha', () {
    final a = practiceActivityOf({'2026-03-09'}, today);
    expect(a.streak, 0);
  });
}
