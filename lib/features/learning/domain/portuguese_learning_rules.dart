import '../../profile/domain/language_pair.dart';
import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'grammar_topic_inference.dart' show TopicInference;
import 'language_learning_rules.dart';
import 'learning_error.dart';
import 'rule_helpers.dart';
import 'success_detection.dart';

/// The Portuguese rules. Small and conservative, like any other language's
/// rules: a rule fires only on a precise, recognizable correction, and no
/// topic is better than a wrong topic. Covered: *ser* or *estar*, a preposition
/// and an article that should be one contraction (*em o* -> *no*), plural
/// marking after a plural determiner, the ending of a verb after its subject
/// pronoun, articles, preposition swaps and word order. Nothing here is a
/// grammar of Portuguese: anything else is left without a topic.
class PortugueseLearningRules implements LanguageLearningRules {
  const PortugueseLearningRules();

  static const _ruleConfidence = 0.8;
  static const _coarseConfidence = coarseRuleConfidence;

  @override
  AppLanguage get language => AppLanguage.portuguese;

  @override
  bool isArticle(String word) => _articles.contains(word);

  @override
  TopicInference? inferGrammarTopics(ErrorPattern pattern) =>
      _serEstarRule(pattern) ??
      _contractionRule(pattern) ??
      _pluralRule(pattern) ??
      _conjugationRule(pattern) ??
      _articleRule(pattern) ??
      _prepositionRule(pattern) ??
      wordOrderInference(pattern);

  /// Literal evidence only (see [detectLiteralGrammarSuccesses]).
  @override
  Map<GrammarTopic, double> detectGrammarSuccesses({
    required List<String> messageTokens,
    required Iterable<LearningError> knownErrors,
    required Set<String> errorKeysThisTurn,
    required Set<GrammarTopic> errorTopicsThisTurn,
  }) => detectLiteralGrammarSuccesses(
    messageTokens: messageTokens,
    knownErrors: knownErrors,
    errorKeysThisTurn: errorKeysThisTurn,
    errorTopicsThisTurn: errorTopicsThisTurn,
  );

  @override
  String? get teachingNote => null;

  @override
  String describeTopic(GrammarTopic topic) => switch (topic) {
    GrammarTopic.serVsEstar => 'choosing ser or estar',
    GrammarTopic.articles => 'articles',
    GrammarTopic.prepositions => 'prepositions and their contractions',
    GrammarTopic.plural => 'plurals',
    GrammarTopic.verbConjugation => 'verb conjugation',
    GrammarTopic.wordOrder => 'word order',
    GrammarTopic.gender => 'noun gender',
    // Topics of other languages are not Portuguese topics.
    _ => topic.name,
  };

  // --- rules ---------------------------------------------------------------

  /// "eu sou cansado" -> "eu estou cansado": one verb replaced by the other.
  TopicInference? _serEstarRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length != 1 || b.length != 1) return null;
    final swapped =
        (_ser.contains(a.first) && _estar.contains(b.first)) ||
        (_estar.contains(a.first) && _ser.contains(b.first));
    if (!swapped) return null;
    return const TopicInference(
      topics: [GrammarTopic.serVsEstar],
      confidence: _ruleConfidence,
    );
  }

  /// "em o" -> "no", "de a" -> "da": a preposition followed by an article
  /// written apart where Portuguese contracts them (or the reverse).
  TopicInference? _contractionRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length == 2 &&
        b.length == 1 &&
        _contractions['${a[0]} ${a[1]}'] == b[0]) {
      return const TopicInference(
        topics: [GrammarTopic.prepositions],
        confidence: _ruleConfidence,
      );
    }
    return null;
  }

  /// "os livro" -> "os livros": the noun gains its plural mark after a plural
  /// determiner.
  TopicInference? _pluralRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length == 1 &&
        b.length == 1 &&
        _pluralDeterminers.contains(p.precedingToken) &&
        _isPluralOf(a.first, b.first)) {
      return const TopicInference(
        topics: [GrammarTopic.plural],
        confidence: _ruleConfidence,
      );
    }
    return null;
  }

  /// "nós falamos" vs "nós falemos": the same verb with another ending, right
  /// after its subject pronoun.
  TopicInference? _conjugationRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length != 1 || b.length != 1) return null;
    if (!_subjects.contains(p.precedingToken)) return null;
    if (sameStemOtherEnding(a.first, b.first)) {
      return const TopicInference(
        topics: [GrammarTopic.verbConjugation],
        confidence: _coarseConfidence,
      );
    }
    return null;
  }

  /// A swap of articles, or one added or dropped. The word *a* is both an
  /// article and a preposition, so on its own (added or dropped) it says
  /// nothing about which one was missing.
  TopicInference? _articleRule(ErrorPattern p) {
    final oneSided =
        p.coreOriginalTokens.isEmpty || p.coreCorrectedTokens.isEmpty;
    final words = oneSided ? _articles.difference(_prepositions) : _articles;
    return functionWordInference(p, words, GrammarTopic.articles);
  }

  /// A swap of prepositions only: one added or dropped is not safely a
  /// preposition issue.
  TopicInference? _prepositionRule(ErrorPattern p) {
    if (p.coreOriginalTokens.isEmpty || p.coreCorrectedTokens.isEmpty) {
      return null;
    }
    return functionWordInference(p, _prepositions, GrammarTopic.prepositions);
  }

  // --- vocabulary of the rules ---------------------------------------------

  static const _ser = {'sou', 'és', 'é', 'somos', 'são', 'ser'};
  static const _estar = {'estou', 'estás', 'está', 'estamos', 'estão', 'estar'};

  static const _subjects = {
    'eu',
    'tu',
    'ele',
    'ela',
    'você',
    'nós',
    'vós',
    'eles',
    'elas',
    'vocês',
  };

  static const _pluralDeterminers = {
    'os',
    'as',
    'uns',
    'umas',
    'estes',
    'estas',
    'esses',
    'essas',
    'meus',
    'minhas',
    'seus',
    'suas',
    'nossos',
    'nossas',
  };

  static const _articles = {'o', 'a', 'os', 'as', 'um', 'uma', 'uns', 'umas'};

  static const _prepositions = {
    'a',
    'à',
    'às',
    'ao',
    'aos',
    'de',
    'do',
    'da',
    'dos',
    'das',
    'em',
    'no',
    'na',
    'nos',
    'nas',
    'num',
    'numa',
    'para',
    'por',
    'pelo',
    'pela',
    'pelos',
    'pelas',
    'com',
    'sem',
    'sobre',
    'entre',
    'até',
    'desde',
  };

  /// Preposition + article written apart -> the contraction.
  static const _contractions = {
    'em o': 'no',
    'em a': 'na',
    'em os': 'nos',
    'em as': 'nas',
    'de o': 'do',
    'de a': 'da',
    'de os': 'dos',
    'de as': 'das',
    'a o': 'ao',
    'a a': 'à',
    'a os': 'aos',
    'a as': 'às',
    'por o': 'pelo',
    'por a': 'pela',
    'por os': 'pelos',
    'por as': 'pelas',
    'em um': 'num',
    'em uma': 'numa',
  };

  /// "livro" -> "livros", "homem" -> "homens", "animal" -> "animais",
  /// "coração" -> "corações".
  static bool _isPluralOf(String singular, String plural) {
    if (singular.length < 2) return false;
    if (plural == '${singular}s') return true;
    if (singular.endsWith('m') &&
        plural == '${singular.substring(0, singular.length - 1)}ns') {
      return true;
    }
    if (singular.endsWith('l') &&
        plural == '${singular.substring(0, singular.length - 1)}is') {
      return true;
    }
    if (singular.endsWith('ão')) {
      final stem = singular.substring(0, singular.length - 2);
      return plural == '$stemões' ||
          plural == '$stemães' ||
          plural == '$stemãos';
    }
    return false;
  }
}
