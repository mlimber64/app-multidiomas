import '../../profile/domain/language_pair.dart';
import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'grammar_topic_inference.dart' as inference;
import 'language_learning_rules.dart';
import 'learning_error.dart';
import 'success_detection.dart' as success;

/// The Italian rules: essere/avere with the passato prossimo, articles and
/// prepositions. The rule sets themselves live in `grammar_topic_inference.dart`
/// (mistake -> topic) and `success_detection.dart` (correct use); both are
/// Italian-specific and are reached only through this class.
class ItalianLearningRules implements LanguageLearningRules {
  const ItalianLearningRules();

  @override
  AppLanguage get language => AppLanguage.italian;

  @override
  inference.TopicInference? inferGrammarTopics(ErrorPattern pattern) =>
      inference.inferGrammarTopics(pattern);

  @override
  Map<GrammarTopic, double> detectGrammarSuccesses({
    required List<String> messageTokens,
    required Iterable<LearningError> knownErrors,
    required Set<String> errorKeysThisTurn,
    required Set<GrammarTopic> errorTopicsThisTurn,
  }) => success.detectGrammarSuccesses(
    messageTokens: messageTokens,
    knownErrors: knownErrors,
    errorKeysThisTurn: errorKeysThisTurn,
    errorTopicsThisTurn: errorTopicsThisTurn,
  );

  @override
  bool isArticle(String word) => inference.italianArticles.contains(word);

  @override
  String? get teachingNote => null;

  @override
  String describeTopic(GrammarTopic topic) => switch (topic) {
    GrammarTopic.passatoProssimo => 'the passato prossimo (past tense)',
    GrammarTopic.essereVsAvere =>
      'choosing essere or avere as the auxiliary verb',
    GrammarTopic.prepositions => 'prepositions',
    GrammarTopic.articles => 'articles',
    GrammarTopic.gender => 'noun gender',
    GrammarTopic.plural => 'plurals',
    GrammarTopic.agreement => 'agreement between words',
    GrammarTopic.pronouns => 'pronouns',
    GrammarTopic.verbConjugation => 'verb conjugation',
    GrammarTopic.wordOrder => 'word order',
    // Topics of other languages are not Italian topics.
    _ => topic.name,
  };
}
