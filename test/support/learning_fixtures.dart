import 'package:parla_con_me/features/learning/domain/practice_evidence.dart';
import 'package:parla_con_me/features/learning/domain/language_scope.dart';
import 'dart:async';

import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';

import 'in_memory_local_storage.dart';

/// Builds summaries with dates relative to the real clock, because the engine
/// computes relevance at `DateTime.now()`.
LearningError errorOf(
  String original,
  String corrected, {
  int frequency = 2,
  GrammarTopic? topic,
}) => LearningError(
  id: '$original -> $corrected',
  category: LearningErrorCategory.grammar,
  original: original,
  corrected: corrected,
  grammarTopic: topic,
  frequency: frequency,
  firstSeenAt: DateTime.now(),
  lastSeenAt: DateTime.now(),
  confidence: 0.9,
);

GrammarTopicProgress topicOf(
  GrammarTopic topic, {
  int errors = 0,
  int successes = 0,
}) => GrammarTopicProgress(
  topic: topic,
  exposureCount: errors + successes,
  errorCount: errors,
  successfulUseCount: successes,
  lastSeenAt: DateTime.now(),
);

UserVocabulary wordOf(
  String word, {
  int exposure = 1,
  int successes = 0,
  String? meaning,
}) => UserVocabulary.of(
  word: word,
  at: DateTime.now(),
  meaning: meaning,
  exposureCount: exposure,
  successfulUseCount: successes,
);

LearnerLearningSummary summaryOf({
  List<LearningError> errors = const [],
  List<GrammarTopicProgress> topics = const [],
  List<UserVocabulary> vocabulary = const [],
}) => LearnerLearningSummary(
  errors: errors,
  recurringErrors: [
    for (final e in errors)
      if (e.isRecurring) e,
  ],
  grammarTopics: topics,
  vocabularyItems: vocabulary,
);

/// A memory a test fully controls: what it returns, when, and whether it
/// fails. Counts reads. Nothing is stored.
class FakeMemoryRepository implements LearningRepository {
  FakeMemoryRepository([this.summary = LearnerLearningSummary.empty]);

  LearnerLearningSummary summary;
  bool failing = false;

  /// When set, reads wait for it (to observe the loading state).
  Completer<void>? gate;
  int reads = 0;

  @override
  Future<Result<LearnerLearningSummary>> getLearningSummary() async {
    reads++;
    await gate?.future;
    return failing
        ? const Failure(StorageFailure('disk error'))
        : Success(summary);
  }

  @override
  Future<Result<void>> recordError(LearningError occurrence) async =>
      const Success(null);
  @override
  Future<Result<void>> recordVocabulary(UserVocabulary occurrence) async =>
      const Success(null);
  @override
  Future<Result<void>> recordGrammarTopicExposure(
    GrammarTopic topic, {
    required DateTime at,
    bool wasError = false,
    String language = legacyLanguageCode,
  }) async => const Success(null);
  @override
  Future<Result<void>> recordSuccessfulGrammarUse(
    GrammarTopic topic, {
    required DateTime at,
    String language = legacyLanguageCode,
  }) async => const Success(null);
  @override
  Future<Result<bool>> applyPracticeEvidence(PracticeEvidence e) async =>
      const Success(false);
  @override
  Future<Result<void>> clearLearningData() async => const Success(null);
}

/// An in-memory storage that remembers every key anything reads or writes, to
/// prove the screens never touch storage themselves.
class SpyLocalStorage extends InMemoryLocalStorage {
  final accessedKeys = <String>[];

  @override
  Future<Result<String?>> readString(String key) {
    accessedKeys.add(key);
    return super.readString(key);
  }

  @override
  Future<Result<void>> writeString(String key, String value) {
    accessedKeys.add(key);
    return super.writeString(key, value);
  }
}
