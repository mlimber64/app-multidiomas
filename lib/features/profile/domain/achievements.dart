/// What the app can honestly tell about the learner's effort, taken from the
/// learning memory and the practice of the days. Nothing here is stored: the
/// achievements are derived each time, so they can never disagree with the
/// rest of the app.
class AchievementStats {
  const AchievementStats({
    this.hasMemory = false,
    this.streak = 0,
    this.practicedThisWeek = 0,
    this.fullPracticeDay = false,
    this.wordsMet = 0,
    this.wordsInUse = 0,
    this.areasImproving = 0,
  });

  static const none = AchievementStats();

  /// The learning memory has something in it.
  final bool hasMemory;

  /// Days in a row with practice (see `PracticeActivity.streak`).
  final int streak;

  /// Days of this week with some practice.
  final int practicedThisWeek;

  /// A day of this week had every step of its practice done.
  final bool fullPracticeDay;

  /// Words met, and of those the ones used correctly often enough to be "in
  /// use" (never "learned": the app cannot prove that).
  final int wordsMet;
  final int wordsInUse;

  /// Areas that were a problem and show clear improvement.
  final int areasImproving;
}

/// The medals of the profile, in the order they are shown. Each is unlocked by
/// a plain fact in [AchievementStats].
enum Achievement {
  firstSteps,
  streak3,
  streak7,
  fullDay,
  firstWord,
  words10,
  improving1,
  improving3;

  bool isUnlocked(AchievementStats s) => switch (this) {
    Achievement.firstSteps => s.hasMemory || s.practicedThisWeek > 0,
    Achievement.streak3 => s.streak >= 3,
    Achievement.streak7 => s.streak >= 7,
    Achievement.fullDay => s.fullPracticeDay,
    Achievement.firstWord => s.wordsInUse >= 1,
    Achievement.words10 => s.wordsMet >= 10,
    Achievement.improving1 => s.areasImproving >= 1,
    Achievement.improving3 => s.areasImproving >= 3,
  };
}

/// The achievements unlocked by [stats], in display order.
List<Achievement> unlockedAchievements(AchievementStats stats) => [
  for (final a in Achievement.values)
    if (a.isUnlocked(stats)) a,
];
