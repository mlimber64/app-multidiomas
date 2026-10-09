import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/app.dart';
import 'package:parla_con_me/features/daily_routine/data/local_daily_routine_repository.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine.dart';
import 'package:parla_con_me/features/daily_routine/presentation/daily_routine_controller.dart';
import 'package:parla_con_me/features/daily_routine/presentation/daily_routine_screen.dart';
import 'package:parla_con_me/features/home/presentation/home_screen.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/reminders/data/reminder_settings.dart';
import 'package:parla_con_me/shared/ui/ui.dart';

import '../../support/fake_notification_service.dart';
import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

// The reminders against the whole app: what gets scheduled, what is taken
// away when the day's practice is done, a new day, the permission, the on/off
// setting and a tap on a notification. The interface is Italian.

// A Wednesday morning.
final _morning = DateTime(2026, 10, 14, 9);

DailyRoutine _routine(
  String date, {
  RoutineStepState step1 = RoutineStepState.pending,
}) => DailyRoutine(
  date: date,
  learningLanguage: AppLanguage.italian,
  step1: ReviewStep(state: step1, itemIds: const ['a']),
  // A pending speaking step needs a mission; there is nothing to say here.
  step2: const ScenarioStep(state: RoutineStepState.unavailable),
  step3: const VocabularyStep(state: RoutineStepState.unavailable),
);

/// Saved routines: [practiced] days have their only step done, [pending] ones
/// not yet.
Future<InMemoryLocalStorage> _storage({
  List<String> practiced = const [],
  List<String> pending = const ['2026-10-14'],
}) async {
  final storage = InMemoryLocalStorage();
  final repo = LocalDailyRoutineRepository(storage);
  for (final date in practiced) {
    await repo.save(_routine(date, step1: RoutineStepState.completed));
  }
  for (final date in pending) {
    await repo.save(_routine(date));
  }
  return storage;
}

class _Run {
  _Run(this.service, this.clock);

  final FakeNotificationService service;
  DateTime Function() clock;

  late ProviderContainer container;
}

Future<_Run> _open(
  WidgetTester tester,
  InMemoryLocalStorage storage, {
  FakeNotificationService? service,
  DateTime? now,
  UserLearningProfile profile = onboardedProfile,
}) async {
  final fake = service ?? FakeNotificationService();
  var moment = now ?? _morning;
  final run = _Run(fake, () => moment);
  await pumpApp(
    tester,
    storage,
    profile: profile,
    notifications: fake,
    overrides: [dailyRoutineClockProvider.overrideWithValue(() => moment)],
  );
  run.container = ProviderScope.containerOf(
    tester.element(find.byType(ParlaConMeApp)),
  );
  // Lets a test move the clock (a new day).
  run.clock = () => moment;
  _clockSetter = (value) => moment = value;
  return run;
}

void Function(DateTime)? _clockSetter;

Future<void> _complete(WidgetTester tester, _Run run) async {
  final ok = await run.container
      .read(dailyRoutineProvider.notifier)
      .completeStep(1);
  expect(ok, isTrue);
  await tester.pumpAndSettle();
}

DateTime _day(int day) => DateTime(2026, 10, day);

void main() {
  group('scheduling', () {
    testWidgets('an unfinished day with a streak: both reminders, in Italian', (
      tester,
    ) async {
      final run = await _open(
        tester,
        await _storage(practiced: ['2026-10-13']),
      );
      final service = run.service;

      expect(service.initialized, isTrue);
      expect(service.channelName, 'Promemoria di pratica');
      final today = service.on(_day(14));
      expect(today.map((n) => n.payload), ['goal', 'streak']);
      expect(today[0].at, DateTime(2026, 10, 14, 15));
      expect(today[0].title, 'LingAI');
      expect(today[0].body, contains('Continua verso il tuo obiettivo'));
      expect(today[1].at, DateTime(2026, 10, 14, 20, 30));
      expect(today[1].body, contains('serie di 1 giorno'));
      // The goal reminder is also ready for the next days.
      expect(service.on(_day(15)).map((n) => n.payload), ['goal']);
      expect(service.on(_day(16)).map((n) => n.payload), ['goal']);
    });

    testWidgets('without a streak there is no streak reminder', (tester) async {
      final run = await _open(tester, await _storage());
      expect(run.service.on(_day(14)).map((n) => n.payload), ['goal']);
    });

    testWidgets('the permission is asked for once the app is set up', (
      tester,
    ) async {
      final run = await _open(tester, await _storage());
      expect(run.service.permissionRequests, greaterThanOrEqualTo(1));
    });

    testWidgets('before the onboarding nothing is scheduled or asked', (
      tester,
    ) async {
      final run = await _open(
        tester,
        await _storage(),
        profile: UserLearningProfile.empty,
      );
      expect(run.service.scheduled, isEmpty);
      expect(run.service.permissionRequests, 0);
    });
  });

  group('cancelling when the day is done', () {
    testWidgets('finishing the routine takes away today\'s reminders at once', (
      tester,
    ) async {
      final run = await _open(
        tester,
        await _storage(practiced: ['2026-10-13']),
      );
      expect(run.service.on(_day(14)), hasLength(2));

      await _complete(tester, run);

      // Neither the afternoon nor the night reminder survives today...
      expect(run.service.on(_day(14)), isEmpty);
      // ...but tomorrow's goal reminder does, and so does tomorrow night's
      // streak reminder: today now counts, so the streak is alive.
      expect(run.service.on(_day(15)).map((n) => n.payload), [
        'goal',
        'streak',
      ]);
    });

    testWidgets('a day already complete schedules nothing for itself', (
      tester,
    ) async {
      final run = await _open(
        tester,
        await _storage(practiced: ['2026-10-13', '2026-10-14'], pending: []),
      );
      expect(run.service.on(_day(14)), isEmpty);
      expect(run.service.on(_day(15)), isNotEmpty);
    });

    testWidgets('a time that has already passed today is not scheduled', (
      tester,
    ) async {
      final run = await _open(
        tester,
        await _storage(practiced: ['2026-10-13']),
        now: DateTime(2026, 10, 14, 16),
      );
      // Past the afternoon one; the night one is still ahead.
      expect(run.service.on(_day(14)).map((n) => n.payload), ['streak']);
    });
  });

  group('a new day', () {
    testWidgets('coming back the next morning plans that day', (tester) async {
      final run = await _open(
        tester,
        await _storage(
          practiced: ['2026-10-13'],
          pending: ['2026-10-14', '2026-10-15'],
        ),
      );
      expect(run.service.on(_day(14)), isNotEmpty);

      // Overnight: the app stays loaded with yesterday's routine, then it
      // comes back to the foreground on the 15th.
      _clockSetter!(DateTime(2026, 10, 15, 8));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(run.service.on(_day(14)), isEmpty, reason: 'yesterday is over');
      // Today is the 15th: its goal reminder is planned, and the streak is
      // already broken, so there is no streak reminder.
      expect(run.service.on(_day(15)).map((n) => n.payload), ['goal']);
    });
  });

  group('the permission', () {
    testWidgets('a refusal schedules nothing and is not insisted on', (
      tester,
    ) async {
      final denied = FakeNotificationService(permission: false);
      final run = await _open(tester, await _storage(), service: denied);
      expect(denied.scheduled, isEmpty);
      final asked = denied.permissionRequests;
      expect(asked, 1);

      // A change in the routine does not ask again in the same session.
      await _complete(tester, run);
      expect(denied.permissionRequests, asked);
      expect(denied.scheduled, isEmpty);
    });

    testWidgets('turning the reminders off and on again asks once more', (
      tester,
    ) async {
      final denied = FakeNotificationService(permission: false);
      final run = await _open(tester, await _storage(), service: denied);
      final notifier = run.container.read(remindersEnabledProvider.notifier);
      await notifier.set(enabled: false);
      await tester.pumpAndSettle();

      denied.permission = true;
      await notifier.set(enabled: true);
      await tester.pumpAndSettle();
      expect(denied.scheduled, isNotEmpty);
    });
  });

  group('the on/off setting', () {
    testWidgets('off cancels everything; on schedules it again', (
      tester,
    ) async {
      final storage = await _storage(practiced: ['2026-10-13']);
      final run = await _open(tester, storage);
      expect(run.service.scheduled, isNotEmpty);

      final notifier = run.container.read(remindersEnabledProvider.notifier);
      await notifier.set(enabled: false);
      await tester.pumpAndSettle();
      expect(run.service.scheduled, isEmpty);
      expect(await storage.readString('reminders_enabled'), isNotNull);

      await notifier.set(enabled: true);
      await tester.pumpAndSettle();
      expect(run.service.scheduled, isNotEmpty);
    });

    testWidgets('an off setting saved earlier is respected from the start', (
      tester,
    ) async {
      final storage = await _storage();
      await storage.writeString('reminders_enabled', '0');
      final run = await _open(tester, storage);
      expect(run.service.scheduled, isEmpty);
    });

    testWidgets('the switch in the profile turns it off and saves it', (
      tester,
    ) async {
      final storage = await _storage(practiced: ['2026-10-13']);
      final run = await _open(tester, storage);
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text('Profilo'),
        ),
      );
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(
        SwitchListTile,
        'Promemoria giornalieri',
      );
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      expect(run.service.scheduled, isEmpty);
      final saved = await storage.readString('reminders_enabled');
      expect(saved.when(success: (v) => v, failure: (_) => 'x'), '0');
    });
  });

  group('tapping a reminder', () {
    testWidgets('while the app is open it goes to the practice of the day', (
      tester,
    ) async {
      final run = await _open(tester, await _storage());
      expect(find.byType(HomeScreen), findsOneWidget);

      run.service.tap('goal');
      await tester.pumpAndSettle();
      expect(find.byType(DailyRoutineScreen), findsOneWidget);
    });

    testWidgets('the streak reminder leads there too', (tester) async {
      final run = await _open(
        tester,
        await _storage(practiced: ['2026-10-13']),
      );
      run.service.tap('streak');
      await tester.pumpAndSettle();
      expect(find.byType(DailyRoutineScreen), findsOneWidget);
    });

    testWidgets('an unknown payload still lands on Home', (tester) async {
      final run = await _open(tester, await _storage());
      run.service.tap(null);
      await tester.pumpAndSettle();
      expect(find.byType(DailyRoutineScreen), findsOneWidget);
    });

    testWidgets('the app opened from closed by a reminder goes there', (
      tester,
    ) async {
      await _open(
        tester,
        await _storage(),
        service: FakeNotificationService(launch: 'goal'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DailyRoutineScreen), findsOneWidget);
    });

    testWidgets('before the onboarding a tap does not skip it', (tester) async {
      final run = await _open(
        tester,
        await _storage(),
        profile: UserLearningProfile.empty,
      );
      run.service.tap('goal');
      await tester.pumpAndSettle();
      expect(find.byType(DailyRoutineScreen), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}
