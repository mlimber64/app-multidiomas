/// What kind of learning item a review refers to. New kinds (pronunciation,
/// listening, ...) are added here; the engine and the storage format only
/// depend on the type's name.
enum ReviewItemType { error, grammar, vocabulary }

/// Where an item is in its review lifecycle.
///
/// - [fresh]: discovered, never reviewed.
/// - [learning]: reviewed, but not yet consistently correct (also where any
///   failure sends the item back to).
/// - [review]: at least [ReviewPolicy.reviewAfterSuccesses] correct reviews in
///   a row.
/// - [mastered]: earned conservatively, see [ReviewPolicy.isMastered].
enum ReviewStatus { fresh, learning, review, mastered }

enum ReviewResult { success, failure }

/// The scheduling rules, in one place. Deliberately simple and deterministic:
/// not SM-2, no per-item ease, no randomness.
abstract final class ReviewPolicy {
  /// Interval after the 1st, 2nd, 3rd, ... consecutive correct review. The
  /// last value repeats for every later one.
  static const successIntervals = <Duration>[
    Duration(days: 1),
    Duration(days: 3),
    Duration(days: 7),
    Duration(days: 14),
    Duration(days: 30),
  ];

  /// After a failure the interval is reset to zero and the item becomes due
  /// again after this short delay, not instantly: a failed item is not handed
  /// out again by the very next queue request, so a review session cannot
  /// loop on it.
  static const failureRetryDelay = Duration(minutes: 10);

  /// Consecutive correct reviews that move an item from `learning` to `review`.
  static const reviewAfterSuccesses = 2;

  /// Mastery needs this many correct reviews in a row (no failure in the
  /// current progression)...
  static const masteredMinSuccesses = 5;

  /// ...and an interval of at least this long.
  static const masteredMinInterval = Duration(days: 30);

  static Duration intervalAfterSuccesses(int consecutiveSuccesses) {
    if (consecutiveSuccesses <= 0) return Duration.zero;
    final i = consecutiveSuccesses - 1;
    return successIntervals[i < successIntervals.length
        ? i
        : successIntervals.length - 1];
  }

  static bool isMastered({
    required int successfulReviews,
    required int consecutiveSuccesses,
    required Duration interval,
  }) =>
      successfulReviews >= masteredMinSuccesses &&
      consecutiveSuccesses >= masteredMinSuccesses &&
      interval >= masteredMinInterval;
}

/// When a learning item should be reviewed again. Holds scheduling state only:
/// what the item *is* (the mistake, the topic, the word) stays in learning
/// memory and is found through [type] + [sourceId].
class ReviewItem {
  const ReviewItem({
    required this.type,
    required this.sourceId,
    required this.firstSeenAt,
    required this.nextReviewAt,
    this.status = ReviewStatus.fresh,
    this.lastReviewedAt,
    this.interval = Duration.zero,
    this.successfulReviews = 0,
    this.failedReviews = 0,
    this.consecutiveSuccesses = 0,
    this.priority = 0,
  });

  /// A newly discovered item: due right away.
  factory ReviewItem.discovered(
    ReviewItemType type,
    String sourceId,
    DateTime now,
  ) => ReviewItem(
    type: type,
    sourceId: sourceId,
    firstSeenAt: now.toUtc(),
    nextReviewAt: now.toUtc(),
  );

  /// The stable identity of the item: the same learning entity is always the
  /// same review item.
  static String idFor(ReviewItemType type, String sourceId) =>
      '${type.name}:$sourceId';

  final ReviewItemType type;

  /// Id of the entity in learning memory: `LearningError.id`, the
  /// `GrammarTopic` name, or `UserVocabulary.id` (already language-qualified).
  final String sourceId;
  final ReviewStatus status;
  final DateTime firstSeenAt;
  final DateTime? lastReviewedAt;
  final DateTime nextReviewAt;

  /// Current gap between reviews; zero until the first correct review and
  /// after any failure.
  final Duration interval;
  final int successfulReviews;
  final int failedReviews;

  /// Correct reviews in a row; a failure resets it to zero.
  final int consecutiveSuccesses;

  /// How much the item matters to this learner *now*, taken from learning
  /// memory when the queue is built. Derived and never persisted (0 until the
  /// engine fills it in). Independent from scheduling.
  final double priority;

  String get id => idFor(type, sourceId);

  bool isDue(DateTime now) => !nextReviewAt.isAfter(now);

  /// Applies one review outcome at [now]. Pure and deterministic.
  ReviewItem recordResult(ReviewResult result, DateTime now) {
    final at = now.toUtc();
    switch (result) {
      case ReviewResult.success:
        final streak = consecutiveSuccesses + 1;
        final successes = successfulReviews + 1;
        final next = ReviewPolicy.intervalAfterSuccesses(streak);
        return _copy(
          status:
              ReviewPolicy.isMastered(
                successfulReviews: successes,
                consecutiveSuccesses: streak,
                interval: next,
              )
              ? ReviewStatus.mastered
              : streak >= ReviewPolicy.reviewAfterSuccesses
              ? ReviewStatus.review
              : ReviewStatus.learning,
          lastReviewedAt: at,
          nextReviewAt: at.add(next),
          interval: next,
          successfulReviews: successes,
          consecutiveSuccesses: streak,
        );
      case ReviewResult.failure:
        return _copy(
          status: ReviewStatus.learning,
          lastReviewedAt: at,
          nextReviewAt: at.add(ReviewPolicy.failureRetryDelay),
          interval: Duration.zero,
          failedReviews: failedReviews + 1,
          consecutiveSuccesses: 0,
        );
    }
  }

  /// The learner made the mistake again after the last review: the item is
  /// due now and its current progression restarts. Counters of past reviews
  /// are history and stay.
  ReviewItem reopened(DateTime now) => _copy(
    status: ReviewStatus.learning,
    nextReviewAt: now.toUtc(),
    interval: Duration.zero,
    consecutiveSuccesses: 0,
  );

  ReviewItem withPriority(double value) => _copy(priority: value);

  ReviewItem _copy({
    ReviewStatus? status,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    Duration? interval,
    int? successfulReviews,
    int? failedReviews,
    int? consecutiveSuccesses,
    double? priority,
  }) => ReviewItem(
    type: type,
    sourceId: sourceId,
    firstSeenAt: firstSeenAt,
    status: status ?? this.status,
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    nextReviewAt: nextReviewAt ?? this.nextReviewAt,
    interval: interval ?? this.interval,
    successfulReviews: successfulReviews ?? this.successfulReviews,
    failedReviews: failedReviews ?? this.failedReviews,
    consecutiveSuccesses: consecutiveSuccesses ?? this.consecutiveSuccesses,
    priority: priority ?? this.priority,
  );

  @override
  bool operator ==(Object other) =>
      other is ReviewItem &&
      other.type == type &&
      other.sourceId == sourceId &&
      other.status == status &&
      other.firstSeenAt == firstSeenAt &&
      other.lastReviewedAt == lastReviewedAt &&
      other.nextReviewAt == nextReviewAt &&
      other.interval == interval &&
      other.successfulReviews == successfulReviews &&
      other.failedReviews == failedReviews &&
      other.consecutiveSuccesses == consecutiveSuccesses &&
      other.priority == priority;

  @override
  int get hashCode => Object.hash(
    type,
    sourceId,
    status,
    firstSeenAt,
    lastReviewedAt,
    nextReviewAt,
    interval,
    successfulReviews,
    failedReviews,
    consecutiveSuccesses,
    priority,
  );

  @override
  String toString() => 'ReviewItem($id, $status, next: $nextReviewAt)';
}
