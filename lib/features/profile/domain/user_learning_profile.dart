import 'package:flutter/foundation.dart' show setEquals;

import '../../../core/result/result.dart';
import '../../../shared/models/voice_gender.dart';
import 'language_pair.dart';

export '../../../shared/models/voice_gender.dart';
export 'language_pair.dart';

/// Self-reported level in the learning language (CEFR). [notSure] is a real,
/// stored answer: the app never invents a level for the user (no placement
/// test exists yet).
enum LanguageLevel { a1, a2, b1, b2, notSure }

enum LearningGoal {
  speakConfidently,
  understandListening,
  writeBetter,
  liveAbroad,
  work,
  study,

  /// "A bit of everything": an answer that excludes the specific goals.
  everything;

  /// Stored names from before goals were language-neutral.
  static const legacyNames = {'liveInItaly': liveAbroad};

  /// The option that cannot be combined with the others.
  static const exclusive = everything;
}

enum LearningFocus {
  conversation,
  grammar,
  vocabulary,
  pronunciation,
  comprehension,
}

/// Selection limits of the multi-select questions, defined once for the
/// domain, the onboarding and the profile editor.
const minGoals = 1;
const maxGoals = 3;
const minFocusAreas = 1;
const maxFocusAreas = 3;

/// Toggles [value] in [current] following the rules of a multi-select
/// question, returning a new set (or [current] itself when nothing changes):
/// - removing is always allowed;
/// - adding past [max] is ignored;
/// - [exclusive] ("not sure"/"a bit of everything") replaces every other
///   option, and choosing any other option clears it.
Set<T> toggleSelection<T>(
  Set<T> current,
  T value, {
  required int max,
  T? exclusive,
}) {
  if (current.contains(value)) return {...current}..remove(value);
  if (exclusive != null && value == exclusive) return {value};
  final base = {...current}..remove(exclusive);
  if (base.length >= max) return current;
  return base..add(value);
}

/// What the learner told us about themselves. Declared preferences only, not
/// what the app infers from behavior (that is `LearnerLearningSummary`).
class UserLearningProfile {
  const UserLearningProfile({
    this.supportLanguage = defaultSupportLanguage,
    this.learningLanguage = defaultLearningLanguage,
    this.uiLanguage,
    this.level,
    this.goals = const <LearningGoal>{},
    this.focusAreas = const <LearningFocus>{},
    this.speakReplies = false,
    this.teacherVoice = VoiceGender.female,
    this.onboardingCompleted = false,
  });

  static const empty = UserLearningProfile();

  /// Support language: the one the learner understands, used by the teacher
  /// for hard explanations. Not the UI language, which is not stored here.
  final AppLanguage supportLanguage;

  /// The language being learned. One per user for now.
  final AppLanguage learningLanguage;

  /// The language of the interface when the learner chose one different from
  /// their support language (for example the language they learn, for
  /// immersion); `null` means "the support language". See [effectiveUiLanguage].
  final AppLanguage? uiLanguage;

  /// The language the interface is shown in.
  AppLanguage get effectiveUiLanguage => uiLanguage ?? supportLanguage;

  /// `null` means "not answered yet"; [LanguageLevel.notSure] means the user
  /// explicitly said they don't know.
  final LanguageLevel? level;

  /// Between [minGoals] and [maxGoals] once the profile is complete.
  final Set<LearningGoal> goals;

  /// Between [minFocusAreas] and [maxFocusAreas] once the profile is complete.
  final Set<LearningFocus> focusAreas;

  /// Read the teacher's replies aloud (a reply to a voice message is always
  /// read aloud).
  final bool speakReplies;

  /// The kind of voice the teacher is read aloud with. Presentation only.
  final VoiceGender teacherVoice;
  final bool onboardingCompleted;

  /// The two languages together.
  LanguagePair get languagePair =>
      LanguagePair(support: supportLanguage, learning: learningLanguage);

  bool get hasValidGoals =>
      goals.length >= minGoals && goals.length <= maxGoals;
  bool get hasValidFocusAreas =>
      focusAreas.length >= minFocusAreas && focusAreas.length <= maxFocusAreas;

  /// Every question has an acceptable answer.
  bool get isValid =>
      languagePair.isSupported &&
      availableUiLanguages.contains(effectiveUiLanguage) &&
      level != null &&
      hasValidGoals &&
      hasValidFocusAreas;

  UserLearningProfile copyWith({
    AppLanguage? supportLanguage,
    AppLanguage? learningLanguage,
    AppLanguage? uiLanguage,
    bool clearUiLanguage = false,
    LanguageLevel? level,
    Set<LearningGoal>? goals,
    Set<LearningFocus>? focusAreas,
    bool? speakReplies,
    VoiceGender? teacherVoice,
    bool? onboardingCompleted,
  }) {
    return UserLearningProfile(
      supportLanguage: supportLanguage ?? this.supportLanguage,
      learningLanguage: learningLanguage ?? this.learningLanguage,
      uiLanguage: clearUiLanguage ? null : (uiLanguage ?? this.uiLanguage),
      level: level ?? this.level,
      goals: goals ?? this.goals,
      focusAreas: focusAreas ?? this.focusAreas,
      speakReplies: speakReplies ?? this.speakReplies,
      teacherVoice: teacherVoice ?? this.teacherVoice,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserLearningProfile &&
      other.supportLanguage == supportLanguage &&
      other.learningLanguage == learningLanguage &&
      other.uiLanguage == uiLanguage &&
      other.level == level &&
      setEquals(other.goals, goals) &&
      setEquals(other.focusAreas, focusAreas) &&
      other.speakReplies == speakReplies &&
      other.teacherVoice == teacherVoice &&
      other.onboardingCompleted == onboardingCompleted;

  @override
  int get hashCode => Object.hash(
    supportLanguage,
    learningLanguage,
    uiLanguage,
    level,
    Object.hashAllUnordered(goals),
    Object.hashAllUnordered(focusAreas),
    speakReplies,
    teacherVoice,
    onboardingCompleted,
  );
}

/// Persistence boundary for [UserLearningProfile]. A synced/remote
/// implementation can replace the local one later.
abstract interface class UserLearningProfileRepository {
  /// Returns [UserLearningProfile.empty] when nothing is stored yet.
  Future<Result<UserLearningProfile>> load();
  Future<Result<void>> save(UserLearningProfile profile);
}
