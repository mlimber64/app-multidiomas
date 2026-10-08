import 'dart:convert';

import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../services/storage/local_storage.dart';
import '../domain/grammar_topic.dart';
import '../domain/language_scope.dart';
import '../domain/learning_error.dart';
import '../domain/learning_repository.dart';
import '../domain/learning_state.dart';
import '../domain/learning_summary.dart';
import '../domain/practice_evidence.dart';
import '../domain/user_vocabulary.dart';

/// Stores the learning memory as one versioned JSON document under
/// `learning_memory` in [LocalStorage]:
///
/// ```json
/// {"version": 1, "errors": [...], "grammarTopics": [...], "vocabulary": [...]}
/// ```
///
/// Reads are defensive, following the conversation repository: nothing stored
/// reads as empty, a corrupt document reads as empty and can be overwritten,
/// and corrupt entries are skipped. A document with a *newer* version than
/// this app understands is never overwritten: every operation fails with a
/// [StorageFailure] so an older app can't destroy data written by a newer one.
///
/// Mutations are serialized through a queue (read-modify-write of one
/// document must not interleave). Swap this class for a database-backed
/// [LearningRepository] when the memory outgrows a single document.
class LocalLearningRepository implements LearningRepository {
  LocalLearningRepository(this._storage);

  static const storageKey = 'learning_memory';
  static const currentVersion = 1;

  final LocalStorage _storage;
  Future<void> _tail = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<Result<LearnerLearningSummary>> getLearningSummary() => _enqueue(
    () async => switch (await _load()) {
      Failure(:final failure) => Failure(failure),
      Success(value: final memory) => Success(memory.toSummary()),
    },
  );

  @override
  Future<Result<void>> recordError(LearningError occurrence) => _update(
    (m) => m.errors[occurrence.id] =
        m.errors[occurrence.id]?.merge(occurrence) ?? occurrence,
  );

  @override
  Future<Result<void>> recordVocabulary(UserVocabulary occurrence) => _update(
    (m) => m.vocabulary[occurrence.id] =
        m.vocabulary[occurrence.id]?.merge(occurrence) ?? occurrence,
  );

  @override
  Future<Result<void>> recordGrammarTopicExposure(
    GrammarTopic topic, {
    required DateTime at,
    bool wasError = false,
    String language = legacyLanguageCode,
  }) => _update(
    (m) => m.topics[_topicKey(language, topic)] =
        (m.topics[_topicKey(language, topic)] ??
                GrammarTopicProgress(topic: topic, language: language))
            .recordExposure(at: at, wasError: wasError),
  );

  @override
  Future<Result<void>> recordSuccessfulGrammarUse(
    GrammarTopic topic, {
    required DateTime at,
    String language = legacyLanguageCode,
  }) => _update(
    (m) => m.topics[_topicKey(language, topic)] =
        (m.topics[_topicKey(language, topic)] ??
                GrammarTopicProgress(topic: topic, language: language))
            .recordSuccess(at: at),
  );

  @override
  Future<Result<bool>> applyPracticeEvidence(PracticeEvidence evidence) =>
      _enqueue(() async {
        final loaded = await _load();
        switch (loaded) {
          case Failure(:final failure):
            return Failure<bool>(failure);
          case Success(value: final memory):
            if (!memory.apply(evidence)) return const Success(false);
            final written = await _storage.writeString(
              storageKey,
              jsonEncode(memory.toJson()),
            );
            return switch (written) {
              Failure(:final failure) => Failure<bool>(failure),
              Success() => const Success(true),
            };
        }
      });

  @override
  Future<Result<void>> clearLearningData() =>
      _enqueue(() => _storage.remove(storageKey));

  Future<Result<void>> _update(void Function(_Memory memory) change) =>
      _enqueue(() async {
        final loaded = await _load();
        switch (loaded) {
          case Failure(:final failure):
            return Failure<void>(failure);
          case Success(value: final memory):
            change(memory);
            return _storage.writeString(
              storageKey,
              jsonEncode(memory.toJson()),
            );
        }
      });

  Future<Result<_Memory>> _load() async {
    final read = await _storage.readString(storageKey);
    return switch (read) {
      Failure(:final failure) => Failure(failure),
      Success(value: final raw) => _decode(raw),
    };
  }

  Result<_Memory> _decode(String? raw) {
    if (raw == null) return Success(_Memory());
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return Success(_Memory());
    }
    if (json is! Map) return Success(_Memory());
    final version = json['version'];
    if (version is! int) return Success(_Memory());
    if (version > currentVersion) {
      return const Failure(
        StorageFailure('learning_memory was written by a newer app version'),
      );
    }
    if (version < 1) return Success(_Memory());

    final memory = _Memory();
    for (final item in _list(json['errors'])) {
      final e = _decodeError(item);
      if (e != null) memory.errors[e.id] = e;
    }
    for (final item in _list(json['grammarTopics'])) {
      final t = _decodeTopic(item);
      if (t != null) memory.topics[_topicKey(t.language, t.topic)] = t;
    }
    for (final item in _list(json['vocabulary'])) {
      final v = _decodeVocabulary(item);
      if (v != null) memory.vocabulary[v.id] = v;
    }
    for (final id in _list(json['appliedEvents'])) {
      if (id is String) memory.applied.add(id);
    }
    return Success(memory);
  }

  static List<Object?> _list(Object? value) =>
      value is List ? value.cast<Object?>() : const [];

  static LearningError? _decodeError(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final original = json['original'];
    final corrected = json['corrected'];
    final firstSeen = _date(json['firstSeenAt']);
    final lastSeen = _date(json['lastSeenAt']);
    if (id is! String || original is! String || corrected is! String) {
      return null;
    }
    if (firstSeen == null || lastSeen == null) return null;
    return LearningError(
      id: id,
      category:
          _byName(LearningErrorCategory.values, json['category']) ??
          LearningErrorCategory.other,
      original: original,
      corrected: corrected,
      explanation: json['explanation'] is String
          ? json['explanation'] as String
          : '',
      grammarTopic: _byName(GrammarTopic.values, json['grammarTopic']),
      language: _languageOf(json['language']),
      frequency: _positiveInt(json['frequency']) ?? 1,
      firstSeenAt: firstSeen,
      lastSeenAt: lastSeen,
      confidence: _unit(json['confidence']) ?? 0,
    );
  }

  static GrammarTopicProgress? _decodeTopic(Object? json) {
    if (json is! Map) return null;
    final topic = _byName(GrammarTopic.values, json['topic']);
    if (topic == null) return null;
    return GrammarTopicProgress(
      topic: topic,
      language: _languageOf(json['language']),
      exposureCount: _nonNegativeInt(json['exposureCount']) ?? 0,
      errorCount: _nonNegativeInt(json['errorCount']) ?? 0,
      successfulUseCount: _nonNegativeInt(json['successfulUseCount']) ?? 0,
      weightedExposure: _nonNegativeDouble(json['weightedExposure']),
      weightedErrors: _nonNegativeDouble(json['weightedErrors']),
      weightedSuccesses: _nonNegativeDouble(json['weightedSuccesses']),
      lastSeenAt: _date(json['lastSeenAt']),
      proof: PracticeProof.fromJson(json['proof']),
    );
  }

  static UserVocabulary? _decodeVocabulary(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final word = json['word'];
    final language = json['language'];
    final lastSeen = _date(json['lastSeenAt']);
    if (id is! String || word is! String || language is! String) return null;
    if (lastSeen == null) return null;
    return UserVocabulary(
      id: id,
      word: word,
      language: language,
      meaning: json['meaning'] is String ? json['meaning'] as String : null,
      exposureCount: _nonNegativeInt(json['exposureCount']) ?? 0,
      successfulUseCount: _nonNegativeInt(json['successfulUseCount']) ?? 0,
      weightedExposure: _nonNegativeDouble(json['weightedExposure']),
      weightedSuccesses: _nonNegativeDouble(json['weightedSuccesses']),
      lastSeenAt: lastSeen,
      proof: PracticeProof.fromJson(json['proof']),
    );
  }

  /// A record without a language predates multilingual memory: legacy.
  static String _languageOf(Object? stored) =>
      stored is String && stored.isNotEmpty ? stored : legacyLanguageCode;

  static String _topicKey(String language, GrammarTopic topic) =>
      '$language:${topic.name}';

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static int? _nonNegativeInt(Object? v) => v is int && v >= 0 ? v : null;
  static int? _positiveInt(Object? v) => v is int && v >= 1 ? v : null;
  static double? _nonNegativeDouble(Object? v) =>
      v is num && v >= 0 ? v.toDouble() : null;
  static double? _unit(Object? v) =>
      v is num && v >= 0 && v <= 1 ? v.toDouble() : null;
}

/// In-memory working copy of the document for one read-modify-write.
class _Memory {
  final errors = <String, LearningError>{};
  final topics = <String, GrammarTopicProgress>{};
  final vocabulary = <String, UserVocabulary>{};

  /// Ids of the latest review events applied, oldest first; bounded.
  final applied = <String>[];
  static const maxAppliedEvents = 200;

  /// Takes [e] into the memory. Returns whether anything changed (a repeated
  /// event, or one about something unknown, changes nothing).
  bool apply(PracticeEvidence e) {
    final fromConversation = e.source == PracticeEvidenceSource.conversation;
    // Conversation events have no identity outside the analysis that made them
    // (one pass per AI reply), so only review events are remembered.
    if (!fromConversation && applied.contains(e.eventId)) return false;
    final exposureOnly = e.type == PracticeEvidenceType.exposure;
    var changed = false;

    final topic = LocalLearningRepository._byName(
      GrammarTopic.values,
      e.grammarTopic,
    );
    if (topic != null) {
      final key = LocalLearningRepository._topicKey(e.learningLanguage, topic);
      final known = topics[key];
      if (known != null || fromConversation) {
        topics[key] =
            (known ??
                    GrammarTopicProgress(
                      topic: topic,
                      language: e.learningLanguage,
                    ))
                .practice(
                  at: e.occurredAt,
                  success: e.isSuccess,
                  weight: e.weight,
                  occurrence: fromConversation,
                  exposureOnly: exposureOnly,
                  evidenceType: e.type,
                  context: e.contextId,
                );
        changed = true;
      }
    }

    final word = e.vocabularyWord;
    final id =
        e.referenceId != null &&
            e.referenceId!.startsWith('${e.learningLanguage}:')
        ? e.referenceId
        : (word == null
              ? null
              : UserVocabulary.idFor(word, e.learningLanguage));
    if (id != null && topic == null) {
      final known = vocabulary[id];
      if (known != null || (fromConversation && word != null)) {
        vocabulary[id] =
            (known ??
                    UserVocabulary(
                      id: id,
                      word: word!.trim(),
                      language: e.learningLanguage,
                      lastSeenAt: e.occurredAt,
                      exposureCount: 0,
                    ))
                .practice(
                  at: e.occurredAt,
                  success: e.isSuccess,
                  weight: e.weight,
                  occurrence: fromConversation,
                  evidenceType: e.type,
                  context: e.contextId,
                );
        changed = true;
      }
    }

    if (!changed) return false;
    if (!fromConversation) applied.add(e.eventId);
    while (applied.length > maxAppliedEvents) {
      applied.removeAt(0);
    }
    return true;
  }

  Map<String, Object?> toJson() => {
    'version': LocalLearningRepository.currentVersion,
    'errors': [
      for (final e in errors.values)
        {
          'id': e.id,
          'category': e.category.name,
          'original': e.original,
          'corrected': e.corrected,
          'explanation': e.explanation,
          'grammarTopic': e.grammarTopic?.name,
          'language': e.language,
          'frequency': e.frequency,
          'firstSeenAt': e.firstSeenAt.toIso8601String(),
          'lastSeenAt': e.lastSeenAt.toIso8601String(),
          'confidence': e.confidence,
        },
    ],
    'grammarTopics': [
      for (final t in topics.values)
        {
          'topic': t.topic.name,
          'language': t.language,
          'exposureCount': t.exposureCount,
          'errorCount': t.errorCount,
          'successfulUseCount': t.successfulUseCount,
          if (t.weightedExposure != t.exposureCount ||
              t.weightedErrors != t.errorCount ||
              t.weightedSuccesses != t.successfulUseCount) ...{
            'weightedExposure': t.weightedExposure,
            'weightedErrors': t.weightedErrors,
            'weightedSuccesses': t.weightedSuccesses,
          },
          if (!t.proof.isEmpty) 'proof': t.proof.toJson(),
          'lastSeenAt': t.lastSeenAt?.toIso8601String(),
        },
    ],
    'vocabulary': [
      for (final v in vocabulary.values)
        {
          'id': v.id,
          'word': v.word,
          'language': v.language,
          'meaning': v.meaning,
          'exposureCount': v.exposureCount,
          'successfulUseCount': v.successfulUseCount,
          if (v.weightedExposure != v.exposureCount ||
              v.weightedSuccesses != v.successfulUseCount) ...{
            'weightedExposure': v.weightedExposure,
            'weightedSuccesses': v.weightedSuccesses,
          },
          if (!v.proof.isEmpty) 'proof': v.proof.toJson(),
          'lastSeenAt': v.lastSeenAt.toIso8601String(),
        },
    ],
    if (applied.isNotEmpty) 'appliedEvents': applied,
  };

  LearnerLearningSummary toSummary() {
    final all = errors.values.toList()
      ..sort((a, b) {
        final byFrequency = b.frequency.compareTo(a.frequency);
        return byFrequency != 0
            ? byFrequency
            : b.lastSeenAt.compareTo(a.lastSeenAt);
      });
    final recurring = all.where((e) => e.isRecurring).toList();
    final topicList = topics.values.toList()
      ..sort((a, b) => b.exposureCount.compareTo(a.exposureCount));
    final vocabList = vocabulary.values.toList()
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));

    final dates = <DateTime>[
      for (final e in errors.values) e.lastSeenAt,
      for (final t in topics.values) ?t.lastSeenAt,
      for (final v in vocabulary.values) v.lastSeenAt,
    ];
    DateTime? latest;
    for (final d in dates) {
      if (latest == null || d.isAfter(latest)) latest = d;
    }
    return LearnerLearningSummary(
      totalErrors: errors.values.fold(0, (sum, e) => sum + e.frequency),
      errors: all,
      recurringErrors: recurring,
      grammarTopics: topicList,
      vocabularyItems: vocabList,
      lastUpdatedAt: latest,
    );
  }
}
