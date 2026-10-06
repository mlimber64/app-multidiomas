import '../../profile/domain/language_pair.dart';
import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'grammar_topic_inference.dart' show TopicInference;
import 'language_learning_rules.dart';
import 'learning_error.dart';
import 'rule_helpers.dart';
import 'success_detection.dart';

/// The Spanish rules, for someone who learns Spanish (from another language
/// of the app). Small and conservative, like any other language's rules: a
/// rule fires only on a precise, recognizable correction, and no topic is
/// better than a wrong topic. Covered: *ser* vs *estar*, *por* vs *para*, a
/// preposition and article that should be one contraction (*a el* -> *al*),
/// plural marking after a plural determiner, the ending of a verb after its
/// subject pronoun, articles, preposition swaps and word order. Nothing here
/// is a grammar of Spanish: anything else is left without a topic.
class SpanishLearningRules implements LanguageLearningRules {
  const SpanishLearningRules();

  static const _ruleConfidence = 0.8;
  static const _coarseConfidence = coarseRuleConfidence;

  @override
  AppLanguage get language => AppLanguage.spanish;

  @override
  bool isArticle(String word) => _articles.contains(word);

  @override
  TopicInference? inferGrammarTopics(ErrorPattern pattern) =>
      _serEstarRule(pattern) ??
      _porParaRule(pattern) ??
      _contractionRule(pattern) ??
      _pluralRule(pattern) ??
      _conjugationRule(pattern) ??
      functionWordInference(pattern, _articles, GrammarTopic.articles) ??
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
    GrammarTopic.porVsPara => 'choosing por or para',
    GrammarTopic.articles => 'articles',
    GrammarTopic.prepositions => 'prepositions and their contractions',
    GrammarTopic.plural => 'plurals',
    GrammarTopic.verbConjugation => 'verb conjugation',
    GrammarTopic.wordOrder => 'word order',
    GrammarTopic.gender => 'noun gender',
    // Topics of other languages are not Spanish topics.
    _ => topic.name,
  };

  // --- rules ---------------------------------------------------------------

  /// "yo soy cansado" -> "yo estoy cansado": one verb replaced by the other.
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

  /// "voy por la playa" -> "voy para la playa": *por* and *para* swapped.
  TopicInference? _porParaRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length != 1 || b.length != 1) return null;
    final swapped =
        (a.first == 'por' && b.first == 'para') ||
        (a.first == 'para' && b.first == 'por');
    if (!swapped) return null;
    return const TopicInference(
      topics: [GrammarTopic.porVsPara],
      confidence: _ruleConfidence,
    );
  }

  /// "a el" -> "al", "de el" -> "del": the only two contractions of Spanish.
  TopicInference? _contractionRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length == 2 && b.length == 1) {
      final joined = '${a[0]} ${a[1]}';
      if ((joined == 'a el' && b.first == 'al') ||
          (joined == 'de el' && b.first == 'del')) {
        return const TopicInference(
          topics: [GrammarTopic.prepositions],
          confidence: _ruleConfidence,
        );
      }
    }
    return null;
  }

  /// "los libro" -> "los libros": the noun gains its plural mark after a
  /// plural determiner.
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

  /// "nosotros hablo" -> "nosotros hablamos": the same verb with another
  /// ending, right after its subject pronoun.
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

  /// A swap of prepositions only: one added or dropped is not safely a
  /// preposition issue (the personal *a* comes and goes).
  TopicInference? _prepositionRule(ErrorPattern p) {
    if (p.coreOriginalTokens.isEmpty || p.coreCorrectedTokens.isEmpty) {
      return null;
    }
    return functionWordInference(p, _prepositions, GrammarTopic.prepositions);
  }

  // --- vocabulary of the rules ---------------------------------------------

  static const _ser = {'soy', 'eres', 'es', 'somos', 'sois', 'son', 'ser'};
  static const _estar = {
    'estoy',
    'estás',
    'está',
    'estamos',
    'estáis',
    'están',
    'estar',
  };

  static const _subjects = {
    'yo',
    'tú',
    'él',
    'ella',
    'usted',
    'nosotros',
    'nosotras',
    'vosotros',
    'vosotras',
    'ellos',
    'ellas',
    'ustedes',
  };

  static const _pluralDeterminers = {
    'los',
    'las',
    'unos',
    'unas',
    'estos',
    'estas',
    'esos',
    'esas',
    'mis',
    'tus',
    'sus',
    'nuestros',
    'nuestras',
  };

  static const _articles = {
    'el',
    'la',
    'lo',
    'los',
    'las',
    'un',
    'una',
    'unos',
    'unas',
  };

  static const _prepositions = {
    'a',
    'al',
    'de',
    'del',
    'en',
    'con',
    'sin',
    'sobre',
    'entre',
    'hasta',
    'desde',
    'hacia',
    'ante',
    'bajo',
    'contra',
    'según',
    'tras',
    'por',
    'para',
  };

  /// "libro" -> "libros", "ciudad" -> "ciudades", "lápiz" -> "lápices".
  static bool _isPluralOf(String singular, String plural) {
    if (singular.length < 2) return false;
    if (plural == '${singular}s' || plural == '${singular}es') return true;
    return singular.endsWith('z') &&
        plural == '${singular.substring(0, singular.length - 1)}ces';
  }
}
