import '../../profile/domain/language_pair.dart';
import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'grammar_topic_inference.dart' show TopicInference;
import 'language_learning_rules.dart';
import 'learning_error.dart';
import 'rule_helpers.dart';
import 'success_detection.dart';

/// The German rules. Small and conservative, like any other language's rules:
/// a rule fires only on a precise, recognizable correction, and no topic is
/// better than a wrong topic. Covered: *haben* or *sein* as the auxiliary of
/// the Perfekt, the form of an article (case-marking forms are told apart),
/// the ending of a verb after its subject pronoun, preposition swaps and word
/// order (including the verb position). Nothing here is a grammar of German:
/// anything else is left without a topic.
///
/// Known limit: capitalization (every German noun starts with a capital) is
/// ignored by the pattern machinery, so a capitalization-only correction is
/// not a mistake it can track.
class GermanLearningRules implements LanguageLearningRules {
  const GermanLearningRules();

  static const _ruleConfidence = 0.8;
  static const _coarseConfidence = coarseRuleConfidence;

  @override
  AppLanguage get language => AppLanguage.german;

  @override
  bool isArticle(String word) => _articles.contains(word);

  @override
  TopicInference? inferGrammarTopics(ErrorPattern pattern) =>
      _auxiliaryRule(pattern) ??
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
    GrammarTopic.habenVsSein => 'choosing haben or sein as the auxiliary verb',
    GrammarTopic.perfekt => 'the Perfekt (past tense)',
    GrammarTopic.cases => 'cases (Nominativ, Akkusativ, Dativ, Genitiv)',
    GrammarTopic.articles => 'articles and their forms',
    GrammarTopic.prepositions => 'prepositions',
    GrammarTopic.verbConjugation => 'verb conjugation',
    GrammarTopic.wordOrder => 'word order and the verb position',
    GrammarTopic.gender => 'noun gender',
    // Topics of other languages are not German topics.
    _ => topic.name,
  };

  // --- rules ---------------------------------------------------------------

  /// "ich habe gestern nach Berlin gefahren" -> "ich bin gestern nach Berlin
  /// gefahren": a haben form replaced by a sein form, in a sentence that ends
  /// in the participle of a verb taking sein (the participle is usually far
  /// from the auxiliary, so the whole sentence is the evidence).
  TopicInference? _auxiliaryRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length != 1 || b.length != 1) return null;
    if (!_haben.contains(a.first) || !_sein.contains(b.first)) return null;
    final participle = p.fullCorrectedTokens.any(_seinParticiples.contains);
    if (!participle) return null;
    return const TopicInference(
      topics: [GrammarTopic.habenVsSein, GrammarTopic.perfekt],
      confidence: _ruleConfidence,
    );
  }

  /// "ich gehst" -> "ich gehe": the same verb with another ending, right after
  /// its subject pronoun.
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

  /// "der Mann" -> "den Mann": one article form replaced by another. A swap
  /// that involves a form only used to mark a case (den, dem, des, einen,
  /// einem, eines) is a case issue; the rest stays "articles".
  TopicInference? _articleRule(ErrorPattern p) {
    final base = functionWordInference(p, _articles, GrammarTopic.articles);
    if (base == null) return null;
    final involved = [...p.coreOriginalTokens, ...p.coreCorrectedTokens];
    if (involved.any(_caseOnly.contains)) {
      return const TopicInference(
        topics: [GrammarTopic.cases, GrammarTopic.articles],
        confidence: _coarseConfidence,
      );
    }
    return base;
  }

  /// A swap of prepositions only: one added or dropped is not safely a
  /// preposition issue ("zu" is also the infinitive marker).
  TopicInference? _prepositionRule(ErrorPattern p) {
    if (p.coreOriginalTokens.isEmpty || p.coreCorrectedTokens.isEmpty) {
      return null;
    }
    return functionWordInference(p, _prepositions, GrammarTopic.prepositions);
  }

  // --- vocabulary of the rules ---------------------------------------------

  static const _haben = {
    'habe',
    'hast',
    'hat',
    'haben',
    'habt',
    'hatte',
    'hatten',
  };
  static const _sein = {'bin', 'bist', 'ist', 'sind', 'seid', 'war', 'waren'};

  /// Participles of verbs that take sein in the Perfekt (motion and change of
  /// state). Verbs that can take either are left out.
  static const _seinParticiples = {
    'gegangen',
    'gekommen',
    'gefahren',
    'geflogen',
    'geblieben',
    'geworden',
    'gelaufen',
    'gestiegen',
    'gefallen',
    'gestorben',
    'passiert',
    'geschehen',
    'aufgestanden',
    'eingeschlafen',
    'angekommen',
    'abgefahren',
    'ausgestiegen',
    'eingestiegen',
    'zurückgekommen',
    'aufgewacht',
    'abgereist',
    'umgezogen',
  };

  static const _subjects = {'ich', 'du', 'er', 'sie', 'es', 'wir', 'ihr'};

  static const _articles = {
    'der',
    'die',
    'das',
    'den',
    'dem',
    'des',
    'ein',
    'eine',
    'einen',
    'einem',
    'einer',
    'eines',
  };

  /// Article forms that exist to mark a case, not a gender or a number.
  static const _caseOnly = {'den', 'dem', 'des', 'einen', 'einem', 'eines'};

  static const _prepositions = {
    'in',
    'im',
    'an',
    'am',
    'auf',
    'mit',
    'nach',
    'zu',
    'zum',
    'zur',
    'von',
    'vom',
    'bei',
    'beim',
    'aus',
    'für',
    'über',
    'unter',
    'vor',
    'zwischen',
    'durch',
    'gegen',
    'ohne',
    'um',
    'seit',
    'bis',
  };
}
