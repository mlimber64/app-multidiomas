import 'error_pattern.dart';
import 'grammar_topic.dart';

/// Topics inferred for a mistake, with how sure the rule is (0.0..1.0).
class TopicInference {
  const TopicInference({required this.topics, required this.confidence});

  /// Most specific topic first.
  final List<GrammarTopic> topics;
  final double confidence;

  GrammarTopic get primary => topics.first;
}

/// Confidence tiers: a precise pattern rule is medium-high; a coarser
/// "only articles / only prepositions changed" rule is medium.
const _patternRuleConfidence = 0.8;
const _coarseRuleConfidence = 0.6;

/// Deterministic, deliberately tiny rule set. Returns `null` when no rule
/// applies: no topic is better than a wrong topic. Improve by adding rules
/// here (or replacing this function); callers only see [TopicInference].
TopicInference? inferGrammarTopics(ErrorPattern pattern) {
  return _auxiliaryRule(pattern) ?? _functionWordRule(pattern);
}

const _avere = {'ho', 'hai', 'ha', 'abbiamo', 'avete', 'hanno'};
// "è" only with the accent: a bare "e" is the conjunction "and".
const _essere = {'sono', 'sei', 'è', 'siamo', 'siete'};

/// Participles that take "essere" (motion/state verbs) in all gender/number
/// forms. "uscito"/"entrato" are left out: "ho uscito il cane" is valid.
final _essereParticiple = RegExp(
  r'^(andat|venut|partit|arrivat|tornat|rimast|cadut|stat)[oaie]$',
);

/// The verb stem ("andat", "venut", ...) of the first essere-participle in
/// [tokens] (normalized words), or `null` when there is none.
String? essereParticipleStem(Iterable<String> tokens) {
  for (final t in tokens) {
    if (_essereParticiple.hasMatch(t)) return t.substring(0, t.length - 1);
  }
  return null;
}

bool _isParticipleOf(String token, String stem) =>
    token.length == stem.length + 1 &&
    token.startsWith(stem) &&
    _essereParticiple.hasMatch(token);

bool _hasAuxiliaryConstruction(
  List<String> tokens,
  String stem,
  Set<String> auxiliaries,
) {
  for (var i = 0; i + 1 < tokens.length; i++) {
    if (auxiliaries.contains(tokens[i]) &&
        _isParticipleOf(tokens[i + 1], stem)) {
      return true;
    }
  }
  return false;
}

/// "sono andato", "siamo andati", "è andata": an essere form directly followed
/// by a participle of the verb with this [stem] (any gender/number).
bool hasEssereConstruction(List<String> tokens, String stem) =>
    _hasAuxiliaryConstruction(tokens, stem, _essere);

/// "ho andato", "abbiamo andato": the mistaken avere construction with the
/// same verb stem.
bool hasAvereConstruction(List<String> tokens, String stem) =>
    _hasAuxiliaryConstruction(tokens, stem, _avere);

/// "ho andato" -> "sono andato": avere + essere-participle replaced by essere.
TopicInference? _auxiliaryRule(ErrorPattern p) {
  final o = p.originalTokens;
  for (var i = 0; i + 1 < o.length; i++) {
    if (_avere.contains(o[i]) && _essereParticiple.hasMatch(o[i + 1])) {
      final correctedHasEssere = p.correctedTokens.any(_essere.contains);
      final sameParticiple = p.correctedTokens.any(
        (t) => t.startsWith(o[i + 1].substring(0, o[i + 1].length - 1)),
      );
      if (correctedHasEssere && sameParticiple) {
        return const TopicInference(
          topics: [GrammarTopic.essereVsAvere, GrammarTopic.passatoProssimo],
          confidence: _patternRuleConfidence,
        );
      }
    }
  }
  return null;
}

const italianArticles = {
  'il',
  'lo',
  'la',
  "l'",
  'i',
  'gli',
  'le',
  'un',
  'uno',
  'una',
  "un'",
};

const _prepositions = {
  'a',
  'di',
  'da',
  'in',
  'con',
  'su',
  'per',
  'tra',
  'fra',
  'al',
  'allo',
  'alla',
  "all'",
  'ai',
  'agli',
  'alle',
  'del',
  'dello',
  'della',
  "dell'",
  'dei',
  'degli',
  'delle',
  'dal',
  'dallo',
  'dalla',
  "dall'",
  'dai',
  'dagli',
  'dalle',
  'nel',
  'nello',
  'nella',
  "nell'",
  'nei',
  'negli',
  'nelle',
  'sul',
  'sullo',
  'sulla',
  "sull'",
  'sui',
  'sugli',
  'sulle',
};

/// Only small function-word swaps: articles ("la problema" -> "il problema")
/// or prepositions ("in supermercato" -> "al supermercato").
TopicInference? _functionWordRule(ErrorPattern p) {
  final a = p.coreOriginalTokens;
  final b = p.coreCorrectedTokens;
  if (a.isEmpty || b.isEmpty || a.length > 2 || b.length > 2) return null;
  final all = [...a, ...b];
  if (all.every(italianArticles.contains)) {
    return const TopicInference(
      topics: [GrammarTopic.articles],
      confidence: _coarseRuleConfidence,
    );
  }
  if (all.every(_prepositions.contains)) {
    return const TopicInference(
      topics: [GrammarTopic.prepositions],
      confidence: _coarseRuleConfidence,
    );
  }
  return null;
}
