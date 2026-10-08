import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../learning/domain/grammar_topic.dart';
import '../../learning/domain/language_scope.dart';
import '../../learning/domain/learning_context_builder.dart';
import '../../learning/domain/learning_repository.dart';
import '../../learning/domain/learning_summary.dart';
import '../../profile/domain/user_learning_profile.dart';
import '../../learning/domain/practice_evidence.dart';
import 'exercise.dart';
import 'review_item.dart';
import 'review_repository.dart';

/// Answers "what should this learner review now, and when again?".
///
///   learning_memory -> ReviewEngine -> review_memory -> (future) review UI
///
/// Learning memory says what the learner struggles with; review memory only
/// says when each of those things is due again. Fully deterministic: no AI,
/// no randomness, and time always comes from the caller.
abstract interface class ReviewEngine {
  /// Reconciles learning memory with review memory: every current review
  /// candidate has exactly one item (created when missing), and existing
  /// schedules are preserved. Returns the items whose source still exists in
  /// learning memory. A failure to *save* does not fail the call (the result
  /// is still correct for this moment); an unreadable memory does.
  Future<Result<List<ReviewItem>>> synchronize({required DateTime now});

  /// Items due at [now] (never reviewed, or `nextReviewAt <= now`), at most
  /// [limit], with [ReviewItem.priority] filled in. Order: higher priority,
  /// then older `nextReviewAt`, then id. Synchronizes first.
  Future<Result<List<ReviewItem>>> getReviewQueue({
    required DateTime now,
    int limit = 10,
  });

  /// Records the outcome of reviewing [itemId] and reschedules it (see
  /// [ReviewPolicy]). Nothing is ever deleted. [exercise] is the kind of
  /// exercise that was answered; it decides how strong a proof the answer is
  /// for the learning memory (see [PracticeEvidenceRecorder]).
  Future<Result<ReviewItem>> recordReviewResult({
    required String itemId,
    required ReviewResult result,
    required DateTime now,
    ExerciseType? exercise,
  });
}

/// Candidates and priorities come from the selection rules and priorities that
/// learning memory already defines (`selectRecurringErrors`,
/// `selectTopicsToReinforce`, `selectVocabularyToReinforce` and each entity's
/// own `priority(now)`); there is no second scoring system here. Priority and
/// scheduling stay separate: priority is read live from learning memory and
/// never stored; scheduling is stored and only changes through review results.
///
/// Candidates:
/// - **errors**: recurring mistakes still relevant and not in an improving area;
/// - **grammar**: topics still needing reinforcement;
/// - **vocabulary**: words of the learner's [learningLanguage] not yet known.
///
/// Once an item exists it stays in the queue cycle even if its source later
/// fades from the candidate rules (its review schedule is its own); it is only
/// left out when the source no longer exists in learning memory.
class DefaultReviewEngine implements ReviewEngine {
  const DefaultReviewEngine(
    this._learning,
    this._reviews, {
    required this.learningLanguage,
    this.evidence,
  });

  final LearningRepository _learning;
  final ReviewRepository _reviews;

  /// Only vocabulary of this language is reviewed (see `UserLearningProfile`).
  final AppLanguage learningLanguage;

  /// Where what the learner proves while reviewing is sent, so the learning
  /// memory learns from it too (the review keeps only its own schedule). Never
  /// a repository: the learning engine is the only writer of that memory.
  final PracticeEvidenceRecorder? evidence;

  @override
  Future<Result<List<ReviewItem>>> synchronize({required DateTime now}) async =>
      switch (await _sync(now)) {
        Failure(:final failure) => Failure(failure),
        Success(value: final s) => Success(s.items),
      };

  @override
  Future<Result<List<ReviewItem>>> getReviewQueue({
    required DateTime now,
    int limit = 10,
  }) async {
    switch (await _sync(now)) {
      case Failure(:final failure):
        return Failure(failure);
      case Success(value: final s):
        final due = [
          for (final item in s.items)
            if (item.isDue(now)) item,
        ]..sort(_queueOrder);
        return Success(limit <= 0 ? const [] : due.take(limit).toList());
    }
  }

  @override
  Future<Result<ReviewItem>> recordReviewResult({
    required String itemId,
    required ReviewResult result,
    required DateTime now,
    ExerciseType? exercise,
  }) async {
    final found = await _reviews.getItem(itemId);
    switch (found) {
      case Failure(:final failure):
        return Failure(failure);
      case Success(value: null):
        return Failure(StorageFailure('Unknown review item: $itemId'));
      case Success(value: final item?):
        // The learning memory hears about it first, under an id taken from the
        // item as it is now: if saving the schedule fails and the answer is
        // sent again, the same event arrives and counts once. A failure here
        // never blocks the review itself.
        final proof = await _evidenceFor(item, result, now, exercise);
        if (proof != null) await evidence?.recordPracticeEvidence(proof);
        final updated = item.recordResult(result, now);
        return switch (await _reviews.saveItem(updated)) {
          Failure(:final failure) => Failure(failure),
          Success() => Success(updated),
        };
    }
  }

  /// What answering [item] proves about the learner, or `null` when it proves
  /// nothing the learning memory can hold (no recorder, or an item with no
  /// topic or word behind it).
  Future<PracticeEvidence?> _evidenceFor(
    ReviewItem item,
    ReviewResult result,
    DateTime now,
    ExerciseType? exercise,
  ) async {
    if (evidence == null) return null;
    final code = learningLanguage.code;
    final prefix = '$code:';
    String unscoped(String id) =>
        id.startsWith(prefix) ? id.substring(prefix.length) : id;

    String? topic;
    String? word;
    switch (item.type) {
      case ReviewItemType.grammar:
        topic = unscoped(item.sourceId);
      case ReviewItemType.vocabulary:
        word = unscoped(item.sourceId);
      case ReviewItemType.error:
        // An error belongs to the grammar topic it was classified under.
        final summary = await _learning.getLearningSummary();
        if (summary is! Success<LearnerLearningSummary>) return null;
        for (final e in summary.value.forLanguage(code).errors) {
          if (e.id == item.sourceId) topic = e.grammarTopic?.name;
        }
    }
    if (topic == null && word == null) return null;

    final kind = exercise ?? ExercisePracticeType.forItem(item.type);
    return PracticeEvidence(
      eventId:
          'review:${item.id}:attempt:'
          '${item.successfulReviews + item.failedReviews + 1}',
      source: PracticeEvidenceSource.review,
      type: kind.practiceType,
      outcome: result == ReviewResult.success
          ? PracticeEvidenceOutcome.success
          : PracticeEvidenceOutcome.failure,
      learningLanguage: code,
      occurredAt: now.toUtc(),
      referenceId: item.sourceId,
      grammarTopic: topic,
      vocabularyWord: word,
      contextId: _reviewContext(now),
    );
  }

  /// The interaction of a review answer: the day it was given. A review has no
  /// session of its own that the engine knows of, so all the answers of one
  /// day are one context. That is the conservative side: it can only make a
  /// concept look less consolidated, never more.
  static String _reviewContext(DateTime now) {
    final d = now.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'review:${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static int _queueOrder(ReviewItem a, ReviewItem b) {
    final byPriority = b.priority.compareTo(a.priority);
    if (byPriority != 0) return byPriority;
    final byDue = a.nextReviewAt.compareTo(b.nextReviewAt);
    return byDue != 0 ? byDue : a.id.compareTo(b.id);
  }

  Future<Result<_Synced>> _sync(DateTime at) async {
    final now = at.toUtc();
    final summaryResult = await _learning.getLearningSummary();
    if (summaryResult is Failure<LearnerLearningSummary>) {
      return Failure(summaryResult.failure);
    }
    // Memory holds every language studied; only the current one is reviewed.
    final summary = (summaryResult as Success<LearnerLearningSummary>).value
        .forLanguage(learningLanguage.code);
    final storedResult = await _reviews.getItems();
    if (storedResult is Failure<List<ReviewItem>>) {
      return Failure(storedResult.failure);
    }
    final stored = (storedResult as Success<List<ReviewItem>>).value;

    final known = _knownSources(summary, now);
    final candidates = _candidates(summary, now);
    final byId = {for (final item in stored) item.id: item};
    final changed = <ReviewItem>[];

    for (final entry in candidates.entries) {
      if (byId.containsKey(entry.key)) continue;
      final (type, sourceId) = entry.value;
      final item = ReviewItem.discovered(type, sourceId, now);
      byId[item.id] = item;
      changed.add(item);
    }

    // A mistake made again after its last review reopens that item (due now,
    // progression restarts); its review history is kept. A reopened item has
    // no progression left, so repeated syncs do not reopen it again.
    final errors = {for (final e in summary.errors) e.id: e};
    for (final item in byId.values.toList()) {
      if (item.type != ReviewItemType.error) continue;
      final reviewed = item.lastReviewedAt;
      final error = errors[item.sourceId];
      if (reviewed == null || error == null) continue;
      final progressing = item.consecutiveSuccesses > 0 || !item.isDue(now);
      if (error.lastSeenAt.isAfter(reviewed) && progressing) {
        final reopened = item.reopened(now);
        byId[item.id] = reopened;
        changed.add(reopened);
      }
    }

    if (changed.isNotEmpty) {
      // Review memory is downstream of learning memory: if it cannot be saved
      // the answer for this moment is still valid, so the failure is not
      // propagated and the next call simply tries again.
      await _reviews.saveItems(changed);
    }

    final items = [
      for (final item in byId.values)
        if (known.containsKey(item.id)) item.withPriority(known[item.id]!),
    ]..sort((a, b) => a.id.compareTo(b.id));
    return Success(_Synced(items));
  }

  /// Grammar topics are shared names across languages, so their review identity
  /// is scoped by language (the legacy language keeps its original ids).
  String _topicSource(GrammarTopic topic) =>
      scopedId(learningLanguage.code, topic.name);

  /// Every learning entity that may be reviewed, with its priority at [now].
  Map<String, double> _knownSources(LearnerLearningSummary s, DateTime now) => {
    for (final e in s.errors)
      ReviewItem.idFor(ReviewItemType.error, e.id): e.priority(now),
    for (final t in s.grammarTopics)
      ReviewItem.idFor(ReviewItemType.grammar, _topicSource(t.topic)): t
          .priority(now),
    for (final v in s.vocabularyItems)
      if (v.language == learningLanguage.code)
        ReviewItem.idFor(ReviewItemType.vocabulary, v.id): v.priority(now),
  };

  /// New review items worth creating now: id -> (type, sourceId).
  Map<String, (ReviewItemType, String)> _candidates(
    LearnerLearningSummary s,
    DateTime now,
  ) {
    final result = <String, (ReviewItemType, String)>{};
    void add(ReviewItemType type, String sourceId) =>
        result[ReviewItem.idFor(type, sourceId)] = (type, sourceId);

    for (final e in selectRecurringErrors(s, now)) {
      add(ReviewItemType.error, e.id);
    }
    for (final t in selectTopicsToReinforce(s, now)) {
      add(ReviewItemType.grammar, _topicSource(t.topic));
    }
    for (final v in selectVocabularyToReinforce(
      s,
      now,
      learningLanguage.code,
    )) {
      add(ReviewItemType.vocabulary, v.id);
    }
    return result;
  }
}

class _Synced {
  const _Synced(this.items);
  final List<ReviewItem> items;
}
