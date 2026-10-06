import '../../profile/domain/language_pair.dart';
import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'grammar_topic_inference.dart' show TopicInference;
import 'language_learning_rules.dart';
import 'learning_error.dart';
import 'rule_helpers.dart';
import 'success_detection.dart';

/// The French rules. Small and conservative, like any other language's rules:
/// a rule fires only on a precise, recognizable correction, and no topic is
/// better than a wrong topic. Covered: *être* or *avoir* as the auxiliary of
/// the passé composé, plural marking after a plural determiner, the ending of
/// a verb after its subject pronoun, articles, prepositions and word order.
/// Nothing here is a grammar of French: anything else is left without a topic.
class FrenchLearningRules implements LanguageLearningRules {
  const FrenchLearningRules();

  static const _ruleConfidence = 0.8;
  static const _coarseConfidence = 0.6;

  @override
  AppLanguage get language => AppLanguage.french;

  @override
  bool isArticle(String word) => _articles.contains(word);

  @override
  TopicInference? inferGrammarTopics(ErrorPattern pattern) =>
      _auxiliaryRule(pattern) ??
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
    GrammarTopic.etreVsAvoir => 'choosing être or avoir as the auxiliary verb',
    GrammarTopic.passeCompose => 'the passé composé (past tense)',
    GrammarTopic.articles => 'articles',
    GrammarTopic.prepositions => 'prepositions',
    GrammarTopic.plural => 'plurals',
    GrammarTopic.verbConjugation => 'verb conjugation',
    GrammarTopic.wordOrder => 'word order',
    GrammarTopic.gender => 'noun gender',
    // Topics of other languages are not French topics.
    _ => topic.name,
  };

  // --- rules ---------------------------------------------------------------

  /// "j'ai allé" -> "je suis allé": avoir + a verb that takes être, replaced by
  /// être with the same participle.
  TopicInference? _auxiliaryRule(ErrorPattern p) {
    final o = p.originalTokens;
    final c = p.correctedTokens;
    for (var i = 0; i + 1 < o.length; i++) {
      final verb = _etreVerbOf[o[i + 1]];
      if (_avoir.contains(o[i]) &&
          verb != null &&
          c.any((t) => _etreVerbOf[t] == verb) &&
          c.any(_etre.contains) &&
          !c.any(_avoir.contains)) {
        return const TopicInference(
          topics: [GrammarTopic.etreVsAvoir, GrammarTopic.passeCompose],
          confidence: _ruleConfidence,
        );
      }
    }
    return null;
  }

  /// "les chat" -> "les chats": the noun gains its plural mark after a plural
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

  /// "nous mangons" -> "nous mangeons": the same verb with another ending,
  /// right after its subject pronoun.
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
  /// preposition issue.
  TopicInference? _prepositionRule(ErrorPattern p) {
    if (p.coreOriginalTokens.isEmpty || p.coreCorrectedTokens.isEmpty) {
      return null;
    }
    return functionWordInference(p, _prepositions, GrammarTopic.prepositions);
  }

  // --- vocabulary of the rules ---------------------------------------------

  // "j'ai" is one word once the apostrophe is kept, so it is listed itself.
  static const _avoir = {"j'ai", 'ai', 'as', 'a', 'avons', 'avez', 'ont'};
  static const _etre = {'suis', 'es', 'est', 'sommes', 'êtes', 'sont'};

  /// Participles of the verbs that take être in the passé composé, in every
  /// gender and number, mapped to their verb's masculine singular form.
  /// Verbs that can take either (sortir, monter, passer...) are left out:
  /// "j'ai sorti la voiture" is correct.
  static final _etreVerbOf = {
    for (final base in const [
      'allé',
      'venu',
      'parti',
      'arrivé',
      'tombé',
      'resté',
      'retourné',
      'devenu',
      'né',
      'mort',
      'entré',
      'rentré',
    ])
      for (final ending in const ['', 'e', 's', 'es']) '$base$ending': base,
  };

  static const _subjects = {
    'je',
    "j'",
    'tu',
    'il',
    'elle',
    'on',
    'nous',
    'vous',
    'ils',
    'elles',
  };

  static const _pluralDeterminers = {
    'les',
    'des',
    'ces',
    'mes',
    'tes',
    'ses',
    'nos',
    'vos',
    'leurs',
  };

  static const _articles = {
    'le',
    'la',
    'les',
    "l'",
    'un',
    'une',
    'des',
    'du',
    'de',
    "d'",
  };

  static const _prepositions = {
    'à',
    'au',
    'aux',
    'de',
    'du',
    'des',
    'en',
    'dans',
    'sur',
    'sous',
    'pour',
    'avec',
    'sans',
    'chez',
    'par',
    'vers',
    'entre',
  };

  /// "chat" -> "chats", "cheval" -> "chevaux", "bateau" -> "bateaux".
  static bool _isPluralOf(String singular, String plural) {
    if (singular.length < 2) return false;
    if (plural == '${singular}s' || plural == '${singular}x') return true;
    return singular.endsWith('al') &&
        plural == '${singular.substring(0, singular.length - 2)}aux';
  }
}
