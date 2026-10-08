import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/daily_routine/data/local_daily_routine_repository.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine.dart';
import 'package:parla_con_me/features/daily_routine/domain/scenario_mission.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';

import '../../support/in_memory_local_storage.dart';

DailyRoutine _routine({
  String date = '2026-10-06',
  AppLanguage language = AppLanguage.italian,
  RoutineStepState review = RoutineStepState.pending,
}) => DailyRoutine(
  date: date,
  learningLanguage: language,
  step1: ReviewStep(state: review, itemIds: const ['error:a', 'error:b']),
  step2: ScenarioStep(
    state: RoutineStepState.pending,
    mission: ScenarioMission(
      id: 'yesterday:passatoProssimo',
      situation: ScenarioSituation.yesterday,
      learningLanguage: language,
      targetTopics: const [GrammarTopic.passatoProssimo],
      prompt: 'SCENARIO MISSION',
    ),
  ),
  step3: const VocabularyStep(
    state: RoutineStepState.pending,
    vocabularyIds: ['it:ciao'],
  ),
);

class _FailingStorage extends InMemoryLocalStorage {
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<Result<String?>> readString(String key) async =>
      failReads ? const Failure(StorageFailure('read')) : super.readString(key);

  @override
  Future<Result<void>> writeString(String key, String value) async => failWrites
      ? const Failure(StorageFailure('write'))
      : super.writeString(key, value);
}

void main() {
  late InMemoryLocalStorage storage;
  late LocalDailyRoutineRepository repository;

  setUp(() {
    storage = InMemoryLocalStorage();
    repository = LocalDailyRoutineRepository(storage);
  });

  Future<DailyRoutine?> load(String date, AppLanguage language) async =>
      switch (await repository.load(date, language)) {
        Success(:final value) => value,
        Failure(:final failure) => throw failure,
      };

  group('LocalDailyRoutineRepository', () {
    test('nothing stored is "no routine", not an error', () async {
      expect(await load('2026-10-06', AppLanguage.italian), isNull);
    });

    test('saves and loads exactly the same routine', () async {
      final r = _routine();
      expect(await repository.save(r), isA<Success<void>>());
      expect(await load('2026-10-06', AppLanguage.italian), r);
    });

    test('a completed step is still completed after reloading', () async {
      final done = _routine().completeStep1()!.completeStep2()!;
      await repository.save(done);
      final loaded = (await load('2026-10-06', AppLanguage.italian))!;
      expect(loaded, done);
      expect(loaded.status, RoutineStatus.step2Completed);
      expect(loaded.step2.mission, done.step2.mission);
    });

    test('same day, another language is another routine', () async {
      final it = _routine();
      final fr = _routine(language: AppLanguage.french);
      await repository.save(it);
      expect(await load('2026-10-06', AppLanguage.french), isNull);
      await repository.save(fr.completeStep1()!);
      expect(await load('2026-10-06', AppLanguage.italian), it);
      expect(
        (await load('2026-10-06', AppLanguage.french))!.step1.state,
        RoutineStepState.completed,
      );
    });

    test('another day is another routine', () async {
      await repository.save(_routine());
      expect(await load('2026-10-07', AppLanguage.italian), isNull);
    });

    test(
      'saving again replaces the routine of that day and language',
      () async {
        await repository.save(_routine());
        await repository.save(_routine().completeStep1()!);
        expect(
          (await load('2026-10-06', AppLanguage.italian))!.step1.state,
          RoutineStepState.completed,
        );
        final doc =
            jsonDecode(storage.data[LocalDailyRoutineRepository.storageKey]!)
                as Map;
        expect((doc['routines'] as Map), hasLength(1));
      },
    );

    test('keeps only the last days', () async {
      for (var d = 1; d <= 20; d++) {
        await repository.save(
          _routine(date: '2026-09-${d.toString().padLeft(2, '0')}'),
        );
      }
      final doc =
          jsonDecode(storage.data[LocalDailyRoutineRepository.storageKey]!)
              as Map;
      expect(
        (doc['routines'] as Map),
        hasLength(LocalDailyRoutineRepository.keepDays),
      );
      expect(await load('2026-09-01', AppLanguage.italian), isNull);
      expect(await load('2026-09-20', AppLanguage.italian), isNotNull);
    });

    test('parallel saves are all kept', () async {
      await Future.wait([
        repository.save(_routine(date: '2026-10-01')),
        repository.save(_routine(date: '2026-10-02')),
        repository.save(_routine(date: '2026-10-03')),
      ]);
      for (final d in ['01', '02', '03']) {
        expect(await load('2026-10-$d', AppLanguage.italian), isNotNull);
      }
    });

    test('the stored document is versioned', () async {
      await repository.save(_routine());
      final doc = jsonDecode(storage.data['daily_routine']!) as Map;
      expect(doc['version'], LocalDailyRoutineRepository.currentVersion);
    });
  });

  group('LocalDailyRoutineRepository: bad data', () {
    Future<void> store(Object? document) async {
      storage.data['daily_routine'] = document is String
          ? document
          : jsonEncode(document);
    }

    test('unreadable text is treated as nothing stored', () async {
      await store('{not json');
      expect(await load('2026-10-06', AppLanguage.italian), isNull);
      await store('[1,2,3]');
      expect(await load('2026-10-06', AppLanguage.italian), isNull);
      await store({'version': 'x'});
      expect(await load('2026-10-06', AppLanguage.italian), isNull);
    });

    test('a malformed routine is skipped and the others survive', () async {
      await repository.save(_routine(date: '2026-10-05'));
      final doc = jsonDecode(storage.data['daily_routine']!) as Map;
      (doc['routines'] as Map)['2026-10-06|it'] = {
        'date': '2026-10-06',
        'language': 'it',
        'review': 'oops',
      };
      await store(doc);
      expect(await load('2026-10-06', AppLanguage.italian), isNull);
      expect(await load('2026-10-05', AppLanguage.italian), isNotNull);
    });

    test('an entry under the wrong key is not trusted', () async {
      await repository.save(_routine());
      final doc = jsonDecode(storage.data['daily_routine']!) as Map;
      final routines = doc['routines'] as Map;
      routines['2026-10-06|fr'] = routines['2026-10-06|it'];
      await store(doc);
      expect(await load('2026-10-06', AppLanguage.french), isNull);
      expect(await load('2026-10-06', AppLanguage.italian), isNotNull);
    });

    test('a pending mission step without its mission is rejected', () async {
      await repository.save(_routine());
      final doc = jsonDecode(storage.data['daily_routine']!) as Map;
      final entry = (doc['routines'] as Map)['2026-10-06|it'] as Map;
      (entry['speak'] as Map)['mission'] = null;
      await store(doc);
      expect(await load('2026-10-06', AppLanguage.italian), isNull);
    });

    test('a newer version is reported and never overwritten', () async {
      final newer = jsonEncode({'version': 99, 'routines': {}});
      storage.data['daily_routine'] = newer;
      expect(
        await repository.load('2026-10-06', AppLanguage.italian),
        isA<Failure<DailyRoutine?>>(),
      );
      expect(await repository.save(_routine()), isA<Failure<void>>());
      expect(storage.data['daily_routine'], newer);
    });

    test('storage failures are reported', () async {
      final failing = _FailingStorage();
      final repo = LocalDailyRoutineRepository(failing);
      failing.failReads = true;
      expect(
        await repo.load('2026-10-06', AppLanguage.italian),
        isA<Failure<DailyRoutine?>>(),
      );
      expect(await repo.save(_routine()), isA<Failure<void>>());
      failing.failReads = false;
      failing.failWrites = true;
      expect(await repo.save(_routine()), isA<Failure<void>>());
    });

    test('a failed save does not break the next one', () async {
      final failing = _FailingStorage()..failWrites = true;
      final repo = LocalDailyRoutineRepository(failing);
      await repo.save(_routine());
      failing.failWrites = false;
      expect(await repo.save(_routine()), isA<Success<void>>());
      expect(
        (await repo.load('2026-10-06', AppLanguage.italian)),
        isA<Success<DailyRoutine?>>(),
      );
    });
  });
}
