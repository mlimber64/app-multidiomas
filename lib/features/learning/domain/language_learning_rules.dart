import '../../profile/domain/language_pair.dart';
import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'grammar_topic_inference.dart';
import 'english_learning_rules.dart';
import 'french_learning_rules.dart';
import 'german_learning_rules.dart';
import 'italian_learning_rules.dart';
import 'mandarin_learning_rules.dart';
import 'portuguese_learning_rules.dart';
import 'spanish_learning_rules.dart';
import 'learning_error.dart';

/// What the learning system needs to know about ONE language being learned.
/// Everything generic (memory, priorities, review, exercises from the
/// learner's own data) lives outside and works for any language; only what
/// depends on the language's grammar sits behind this boundary.
///
/// The engine coordinates and never branches on a language: it is handed the
/// rules of the learner's `learningLanguage`.
abstract interface class LanguageLearningRules {
  /// The language these rules teach.
  AppLanguage get language;

  /// The grammar topics a mistake touches, or `null` when no rule applies
  /// (no topic is better than a wrong topic).
  TopicInference? inferGrammarTopics(ErrorPattern pattern);

  /// Topics the message used correctly after the learner was corrected on
  /// them (see the Italian implementation for the exact, conservative rules).
  Map<GrammarTopic, double> detectGrammarSuccesses({
    required List<String> messageTokens,
    required Iterable<LearningError> knownErrors,
    required Set<String> errorKeysThisTurn,
    required Set<GrammarTopic> errorTopicsThisTurn,
  });

  /// Whether the normalized (lowercase) word is an article, which is not part
  /// of a vocabulary item ("il computer" is the word "computer").
  bool isArticle(String word);

  /// How the teacher's instruction names [topic] (English, for the AI).
  String describeTopic(GrammarTopic topic);

  /// A short note for the teacher about how this language should be taught
  /// (for example its writing system), or `null` when there is none.
  String? get teachingNote;
}

/// The rules for [language]. A language has rules only when the app can really
/// teach it; this is what makes it a supported learning language (see
/// `supportedLearningLanguages`). Today: Italian, English, French, Portuguese, German, Spanish and Mandarin.
LanguageLearningRules? learningRulesFor(AppLanguage language) =>
    switch (language) {
      AppLanguage.italian => const ItalianLearningRules(),
      AppLanguage.english => const EnglishLearningRules(),
      AppLanguage.french => const FrenchLearningRules(),
      AppLanguage.portuguese => const PortugueseLearningRules(),
      AppLanguage.german => const GermanLearningRules(),
      AppLanguage.spanish => const SpanishLearningRules(),
      AppLanguage.mandarin => const MandarinLearningRules(),
    };
