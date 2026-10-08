import '../../../l10n/l10n.dart';
import '../domain/user_learning_profile.dart';

/// Interface copy for profile enums, in the current UI language. Kept out of
/// the domain so the domain stays free of presentation text.
extension LanguageLevelLabel on LanguageLevel {
  String label(AppLocalizations l) => switch (this) {
    LanguageLevel.a1 => l.levelA1,
    LanguageLevel.a2 => l.levelA2,
    LanguageLevel.b1 => l.levelB1,
    LanguageLevel.b2 => l.levelB2,
    LanguageLevel.notSure => l.levelNotSure,
  };
}

extension LearningGoalLabel on LearningGoal {
  String label(AppLocalizations l) => switch (this) {
    LearningGoal.speakConfidently => l.goalSpeakConfidently,
    LearningGoal.understandListening => l.goalUnderstandListening,
    LearningGoal.writeBetter => l.goalWriteBetter,
    LearningGoal.liveAbroad => l.goalLiveAbroad,
    LearningGoal.work => l.goalWork,
    LearningGoal.study => l.goalStudy,
    LearningGoal.everything => l.goalEverything,
  };
}

extension LearningFocusLabel on LearningFocus {
  String label(AppLocalizations l) => switch (this) {
    LearningFocus.conversation => l.focusConversation,
    LearningFocus.grammar => l.focusGrammar,
    LearningFocus.vocabulary => l.focusVocabulary,
    LearningFocus.pronunciation => l.focusPronunciation,
    LearningFocus.comprehension => l.focusComprehension,
  };
}

/// Languages are always shown by their own name, whatever the UI language, so
/// a learner can find theirs in any interface.
extension AppLanguageLabel on AppLanguage {
  String get label => switch (this) {
    AppLanguage.spanish => 'Español',
    AppLanguage.english => 'English',
    AppLanguage.italian => 'Italiano',
    AppLanguage.french => 'Français',
    AppLanguage.portuguese => 'Português',
    AppLanguage.german => 'Deutsch',
    AppLanguage.mandarin => '中文',
  };
}

/// Joins the labels of a multi-select answer in enum order.
String joinLabels<T extends Enum>(
  AppLocalizations l,
  Iterable<T> all,
  Set<T> selected,
  String Function(T) label,
) {
  final parts = [
    for (final v in all)
      if (selected.contains(v)) label(v),
  ];
  return parts.isEmpty ? l.notSet : parts.join(', ');
}

/// (value, label) pairs shared by onboarding and the profile editor. Choosing
/// the support language comes first and moves the language to learn out of the
/// way if it is the same; the language to learn leaves out the support one.
List<(AppLanguage, String)> supportLanguageOptions() => [
  for (final v in availableSupportLanguages) (v, v.label),
];

List<(AppLanguage, String)> learningLanguageOptions({AppLanguage? support}) => [
  for (final v in supportedLearningLanguages)
    if (v != support) (v, v.label),
];

List<(AppLanguage, String)> uiLanguageOptions() => [
  for (final v in availableUiLanguages) (v, v.label),
];

List<(LanguageLevel, String)> levelOptions(AppLocalizations l) => [
  for (final v in LanguageLevel.values) (v, v.label(l)),
];
List<(LearningGoal, String)> goalOptions(AppLocalizations l) => [
  for (final v in LearningGoal.values) (v, v.label(l)),
];
List<(LearningFocus, String)> focusOptions(AppLocalizations l) => [
  for (final v in LearningFocus.values) (v, v.label(l)),
];

// NUEVO: frase corta, en el idioma que se aprende, para probar la voz del
// profesor desde el perfil.
String voiceSampleText(AppLanguage language) => switch (language) {
  AppLanguage.italian => 'Ciao! Sono il tuo insegnante.',
  AppLanguage.spanish => '¡Hola! Soy tu profesor.',
  AppLanguage.english => 'Hello! I am your teacher.',
  AppLanguage.french => 'Bonjour ! Je suis ton professeur.',
  AppLanguage.portuguese => 'Olá! Eu sou o seu professor.',
  AppLanguage.german => 'Hallo! Ich bin dein Lehrer.',
  AppLanguage.mandarin => '你好！我是你的老师。',
};
