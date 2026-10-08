import 'dart:convert';

import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../services/storage/local_storage.dart';
import '../../learning/domain/grammar_topic.dart';
import '../../profile/domain/language_pair.dart';
import '../domain/daily_routine.dart';
import '../domain/daily_routine_repository.dart';
import '../domain/scenario_mission.dart';

/// Stores the routines as one versioned JSON document (`daily_routine`) in
/// [LocalStorage], keyed by day and language, so another language never reads
/// or overwrites a routine of this one. Only the last [keepDays] days are kept.
///
/// Reading is defensive: an unreadable document is "nothing stored", and a
/// malformed routine is skipped (the day is simply planned again). A document
/// written by a newer app version is reported as a failure and never
/// overwritten. Writes are serialized.
class LocalDailyRoutineRepository implements DailyRoutineRepository {
  LocalDailyRoutineRepository(this._storage);

  static const storageKey = 'daily_routine';
  static const currentVersion = 1;

  /// A routine is only useful the day it is made; a few days are kept so the
  /// last days are not lost to a clock change.
  static const keepDays = 14;

  final LocalStorage _storage;
  Future<void> _tail = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<Result<DailyRoutine?>> load(String date, AppLanguage language) =>
      _enqueue(() async {
        return switch (await _read()) {
          Failure(:final failure) => Failure(failure),
          Success(value: final routines) => Success(
            routines[DailyRoutine.keyFor(date, language)],
          ),
        };
      });

  @override
  Future<Result<void>> save(DailyRoutine routine) => _enqueue(() async {
    switch (await _read()) {
      case Failure(:final failure):
        return Failure<void>(failure);
      case Success(value: final routines):
        routines[routine.key] = routine;
        final newest = (routines.values.map((r) => r.date).toSet().toList()
          ..sort());
        final keep = newest.length > keepDays
            ? newest.sublist(newest.length - keepDays).toSet()
            : newest.toSet();
        return _storage.writeString(
          storageKey,
          jsonEncode({
            'version': currentVersion,
            'routines': {
              for (final entry in routines.entries)
                if (keep.contains(entry.value.date))
                  entry.key: _encode(entry.value),
            },
          }),
        );
    }
  });

  Future<Result<Map<String, DailyRoutine>>> _read() async {
    final read = await _storage.readString(storageKey);
    switch (read) {
      case Failure(:final failure):
        return Failure(failure);
      case Success(value: final raw):
        return _decode(raw);
    }
  }

  static Result<Map<String, DailyRoutine>> _decode(String? raw) {
    final routines = <String, DailyRoutine>{};
    if (raw == null) return Success(routines);
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return Success(routines);
    }
    if (json is! Map) return Success(routines);
    final version = json['version'];
    if (version is! int || version < 1) return Success(routines);
    if (version > currentVersion) {
      return const Failure(
        StorageFailure('daily_routine was written by a newer app version'),
      );
    }
    final stored = json['routines'];
    if (stored is! Map) return Success(routines);
    for (final entry in stored.entries) {
      final routine = _decodeRoutine(entry.value);
      // The key is derived from the content: a mismatch means a bad entry.
      if (routine != null && routine.key == entry.key) {
        routines[entry.key as String] = routine;
      }
    }
    return Success(routines);
  }

  // --- encoding ------------------------------------------------------------

  static Map<String, Object?> _encode(DailyRoutine r) => {
    'date': r.date,
    'language': r.learningLanguage.name,
    'review': {'state': r.step1.state.name, 'itemIds': r.step1.itemIds},
    'speak': {
      'state': r.step2.state.name,
      'mission': r.step2.mission == null
          ? null
          : _encodeMission(r.step2.mission!),
    },
    'vocabulary': {'state': r.step3.state.name, 'ids': r.step3.vocabularyIds},
  };

  static Map<String, Object?> _encodeMission(ScenarioMission m) => {
    'id': m.id,
    'situation': m.situation.name,
    'language': m.learningLanguage.name,
    'topics': [for (final t in m.targetTopics) t.name],
    'prompt': m.prompt,
    'minTurns': m.minTurns,
  };

  static DailyRoutine? _decodeRoutine(Object? json) {
    if (json is! Map) return null;
    final date = json['date'];
    final language = _byName(AppLanguage.values, json['language']);
    if (date is! String || !_datePattern.hasMatch(date) || language == null) {
      return null;
    }
    final review = json['review'];
    final speak = json['speak'];
    final vocabulary = json['vocabulary'];
    if (review is! Map || speak is! Map || vocabulary is! Map) return null;

    final reviewState = _byName(RoutineStepState.values, review['state']);
    final speakState = _byName(RoutineStepState.values, speak['state']);
    final vocabState = _byName(RoutineStepState.values, vocabulary['state']);
    final itemIds = _strings(review['itemIds']);
    final wordIds = _strings(vocabulary['ids']);
    if (reviewState == null ||
        speakState == null ||
        vocabState == null ||
        itemIds == null ||
        wordIds == null) {
      return null;
    }
    ScenarioMission? mission;
    if (speak['mission'] != null) {
      mission = _decodeMission(speak['mission']);
      if (mission == null) return null;
    }
    // A step with content cannot be pending or done without it.
    if (speakState != RoutineStepState.unavailable && mission == null) {
      return null;
    }
    return DailyRoutine(
      date: date,
      learningLanguage: language,
      step1: ReviewStep(state: reviewState, itemIds: itemIds),
      step2: ScenarioStep(state: speakState, mission: mission),
      step3: VocabularyStep(state: vocabState, vocabularyIds: wordIds),
    );
  }

  static ScenarioMission? _decodeMission(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final prompt = json['prompt'];
    final situation = _byName(ScenarioSituation.values, json['situation']);
    final language = _byName(AppLanguage.values, json['language']);
    final topicNames = _strings(json['topics']);
    final minTurns = json['minTurns'];
    if (id is! String ||
        prompt is! String ||
        situation == null ||
        language == null ||
        topicNames == null) {
      return null;
    }
    final topics = <GrammarTopic>[];
    for (final name in topicNames) {
      final topic = _byName(GrammarTopic.values, name);
      if (topic == null) return null;
      topics.add(topic);
    }
    return ScenarioMission(
      id: id,
      situation: situation,
      learningLanguage: language,
      targetTopics: topics,
      prompt: prompt,
      minTurns: minTurns is int && minTurns > 0
          ? minTurns
          : ScenarioMission.defaultMinTurns,
    );
  }

  static List<String>? _strings(Object? value) {
    if (value is! List) return null;
    final out = <String>[];
    for (final item in value) {
      if (item is! String) return null;
      out.add(item);
    }
    return out;
  }

  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
