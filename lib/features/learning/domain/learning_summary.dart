import 'grammar_topic.dart';
import 'learning_error.dart';
import 'user_vocabulary.dart';

/// What the app has *learned about the learner* from their behavior. Not to
/// be confused with `UserLearningProfile`, which is what the learner *declared*
/// in onboarding.
class LearnerLearningSummary {
  const LearnerLearningSummary({
    this.totalErrors = 0,
    this.errors = const <LearningError>[],
    this.recurringErrors = const <LearningError>[],
    this.grammarTopics = const <GrammarTopicProgress>[],
    this.vocabularyItems = const <UserVocabulary>[],
    this.lastUpdatedAt,
  });

  static const empty = LearnerLearningSummary();

  /// Total mistake occurrences (sum of every error's frequency).
  final int totalErrors;

  /// Every known mistake pattern, most frequent first (then most recent).
  final List<LearningError> errors;

  /// The subset of [errors] seen at least [LearningError.recurringThreshold]
  /// times (2), in the same order. A single sighting is occasional.
  final List<LearningError> recurringErrors;
  final List<GrammarTopicProgress> grammarTopics;
  final List<UserVocabulary> vocabularyItems;

  /// Latest activity recorded; `null` when the memory is empty.
  final DateTime? lastUpdatedAt;

  /// Only what belongs to [languageCode]. Memory holds every language the
  /// learner has studied; each consumer works with the current one.
  LearnerLearningSummary forLanguage(String languageCode) {
    final langErrors = [
      for (final e in errors)
        if (e.language == languageCode) e,
    ];
    return LearnerLearningSummary(
      totalErrors: langErrors.fold(0, (sum, e) => sum + e.frequency),
      errors: langErrors,
      recurringErrors: [
        for (final e in recurringErrors)
          if (e.language == languageCode) e,
      ],
      grammarTopics: [
        for (final t in grammarTopics)
          if (t.language == languageCode) t,
      ],
      vocabularyItems: [
        for (final v in vocabularyItems)
          if (v.language == languageCode) v,
      ],
      lastUpdatedAt: lastUpdatedAt,
    );
  }

  /// Mistakes ordered by how much attention they deserve at [now] (see
  /// `LearningError.priority`). Derived on demand, nothing stored.
  List<LearningError> prioritizedErrors(DateTime now) => _byPriority(
    errors,
    (e) => e.priority(now),
    (a, b) => b.lastSeenAt.compareTo(a.lastSeenAt),
  );

  /// Grammar topics worth practicing first at [now], hardest first. Topics
  /// with no errors are excluded: there is nothing to practice yet.
  List<GrammarTopicProgress> prioritizedTopics(DateTime now) => _byPriority(
    grammarTopics.where((t) => t.errorCount > 0),
    (t) => t.priority(now),
    (a, b) => (b.lastSeenAt ?? now).compareTo(a.lastSeenAt ?? now),
  );

  /// Vocabulary ordered by how much each word deserves reinforcement at
  /// [now] (see `UserVocabulary.priority`).
  List<UserVocabulary> prioritizedVocabulary(DateTime now) => _byPriority(
    vocabularyItems,
    (v) => v.priority(now),
    (a, b) => b.lastSeenAt.compareTo(a.lastSeenAt),
  );

  static List<T> _byPriority<T>(
    Iterable<T> items,
    double Function(T) priority,
    int Function(T, T) tieBreak,
  ) {
    final list = items.toList();
    list.sort((a, b) {
      final byPriority = priority(b).compareTo(priority(a));
      return byPriority != 0 ? byPriority : tieBreak(a, b);
    });
    return list;
  }
}
