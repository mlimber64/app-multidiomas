/// A language the app knows by name. Which of them can actually be used as a
/// support language or as a language to learn is decided by
/// [availableSupportLanguages] and [supportedLearningLanguages], not by this
/// enum: adding a value here never makes it selectable on its own.
enum AppLanguage {
  spanish('es', 'Spanish'),
  italian('it', 'Italian'),
  english('en', 'English'),
  french('fr', 'French'),
  portuguese('pt', 'Portuguese'),
  german('de', 'German'),
  mandarin('zh', 'Mandarin Chinese'),
  quechua('qu', 'Southern Quechua (Cusco and Bolivia)');

  const AppLanguage(this.code, this.englishName);

  /// ISO 639-1 code (matches `UserVocabulary.language`).
  final String code;

  /// Name used inside the AI instruction.
  final String englishName;
}

/// What the app can really do today. A language is a *supported learning
/// language* only when the learning system has rules for it (see
/// `learningRulesFor`); a *support language* only needs to be one the app can
/// explain things in. Adding a language to either list is a deliberate act,
/// never a side effect of adding it to [AppLanguage].
///
/// The UI language is a separate setting (`UserLearningProfile.uiLanguage`,
/// by default the support language) and must be one of [availableUiLanguages].
/// Languages the interface exists in. A language can be the learner's support
/// language only when the app can also speak to them in it, so both lists are
/// the same. A new interface language is added with its translation.
const availableUiLanguages = [
  AppLanguage.spanish,
  AppLanguage.english,
  AppLanguage.italian,
];
const availableSupportLanguages = availableUiLanguages;
const supportedLearningLanguages = [
  AppLanguage.italian,
  AppLanguage.english,
  AppLanguage.french,
  AppLanguage.portuguese,
  AppLanguage.german,
  AppLanguage.spanish,
  AppLanguage.mandarin,
  AppLanguage.quechua,
];

const defaultSupportLanguage = AppLanguage.spanish;
const defaultLearningLanguage = AppLanguage.italian;

/// The learning language offered first to someone whose support language is
/// [support]: the first supported one that is not that same language.
AppLanguage defaultLearningLanguageFor(AppLanguage support) =>
    supportedLearningLanguages.firstWhere(
      (l) => l != support,
      orElse: () => defaultLearningLanguage,
    );

/// The two languages of a learner: the one they understand (where the teacher
/// may explain) and the one they learn. Different concepts: they are never
/// assumed equal, and a pair is only usable when the app really supports it.
class LanguagePair {
  const LanguagePair({required this.support, required this.learning});

  final AppLanguage support;
  final AppLanguage learning;

  /// The app can teach [learning] and explain in [support], and the two differ
  /// (learning a language through itself is not a pair).
  bool get isSupported =>
      support != learning &&
      availableSupportLanguages.contains(support) &&
      supportedLearningLanguages.contains(learning);

  @override
  bool operator ==(Object other) =>
      other is LanguagePair &&
      other.support == support &&
      other.learning == learning;

  @override
  int get hashCode => Object.hash(support, learning);

  @override
  String toString() => 'LanguagePair($support -> $learning)';
}
