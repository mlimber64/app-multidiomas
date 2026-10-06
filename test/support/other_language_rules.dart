import 'package:parla_con_me/features/learning/domain/error_pattern.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic_inference.dart';
import 'package:parla_con_me/features/learning/domain/language_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/profile/domain/language_pair.dart';

/// Rules of a language the app does NOT teach: they know no grammar at all.
/// Only used to prove that the learning system takes its language from the
/// rules it is given, not from a constant. Not a supported learning language.
class NoGrammarRules implements LanguageLearningRules {
  const NoGrammarRules(this.language);

  @override
  final AppLanguage language;

  @override
  TopicInference? inferGrammarTopics(ErrorPattern pattern) => null;

  @override
  Map<GrammarTopic, double> detectGrammarSuccesses({
    required List<String> messageTokens,
    required Iterable<LearningError> knownErrors,
    required Set<String> errorKeysThisTurn,
    required Set<GrammarTopic> errorTopicsThisTurn,
  }) => const {};

  @override
  bool isArticle(String word) => false;

  @override
  String? get teachingNote => null;

  @override
  String describeTopic(GrammarTopic topic) => 'topic:${topic.name}';
}
