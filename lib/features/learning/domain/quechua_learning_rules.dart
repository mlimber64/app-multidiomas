import '../../profile/domain/language_pair.dart';
import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'grammar_topic_inference.dart' show TopicInference;
import 'language_learning_rules.dart';
import 'learning_error.dart';
import 'rule_helpers.dart';
import 'success_detection.dart';

/// The Southern Quechua rules (Cusco-Collao and Bolivian Quechua, written in
/// the three-vowel alphabet). Small and conservative, like any other
/// language's rules: a rule fires only on a precise, recognizable correction,
/// and no topic is better than a wrong topic.
///
/// Quechua is agglutinative: a word is a root followed by suffixes, so a
/// mistake is usually the same root with another suffix. Every rule here looks
/// for exactly that, one word on each side with the same root. Covered: the
/// evidential suffixes (-mi, -si, -chá), the case suffixes (-pi, -man, -ta...),
/// the plural -kuna, the person endings of the verb, and word order. Quechua
/// has no articles and no grammatical gender, so those topics do not exist
/// here. Nothing here is a grammar of Quechua: anything else is left without a
/// topic.
class QuechuaLearningRules implements LanguageLearningRules {
  const QuechuaLearningRules();

  static const _ruleConfidence = 0.8;
  static const _coarseConfidence = coarseRuleConfidence;

  /// A root shorter than this is too likely to be another word that happens to
  /// end like a suffix (papa / pata), so no topic is claimed.
  static const _minRoot = 3;

  @override
  AppLanguage get language => AppLanguage.quechua;

  /// Quechua has no articles.
  @override
  bool isArticle(String word) => false;

  @override
  String? get teachingNote =>
      'Teach Southern Quechua (Quechua Collao, as spoken in Cusco, Puno and '
      'Bolivia), not the Ancash, Cajamarca or Ecuadorian varieties. Write it in '
      'the standard three-vowel alphabet (a, i, u: ñuqa, not ñoqa) with the '
      "ejectives (ch', k', p', q', t') and aspirates (chh, kh, ph, qh, th) "
      "written out, and always the plain straight apostrophe ('). Quechua is "
      'built from a root plus suffixes, so keep sentences short and, for a '
      'beginner, break a new word into its root and suffixes in the support '
      'language. Bring in the evidential suffixes (-mi, -si, -chá) early, since '
      'they are part of ordinary sentences. The conversation itself is in '
      'Quechua, but explanations and corrections go in the support language: '
      'the learner cannot yet read long explanations in Quechua. Never invent '
      'a word or a form. If you are not sure of a word, a suffix or a regional '
      'difference, say so briefly in the support language and offer the most '
      'widely used form. You understand spoken Quechua far less reliably than '
      'written Quechua: if a recording is unclear, ask the learner to say it '
      'again or to type it, and do not guess.';

  @override
  TopicInference? inferGrammarTopics(ErrorPattern pattern) =>
      _evidentialRule(pattern) ??
      _personEndingRule(pattern) ??
      _pluralRule(pattern) ??
      _caseSuffixRule(pattern) ??
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
  String describeTopic(GrammarTopic topic) => switch (topic) {
    GrammarTopic.evidentials =>
      'the evidential suffixes -mi / -m, -si / -s and -chá',
    GrammarTopic.caseSuffixes =>
      'case suffixes (-pi, -man, -manta, -ta, -wan, -paq, -pa)',
    GrammarTopic.plural => 'the plural suffix -kuna',
    GrammarTopic.verbConjugation => 'the person endings of the verb',
    GrammarTopic.wordOrder => 'word order',
    // Topics of other languages are not Quechua topics.
    _ => topic.name,
  };

  // --- rules ---------------------------------------------------------------

  /// "ñuqam" -> "ñuqas": one word, the same root, another evidential. Also
  /// "-mi" -> "-m" (the form depends on the sound before it).
  TopicInference? _evidentialRule(ErrorPattern p) {
    final pair = _singleWords(p);
    if (pair == null) return null;
    final (a, b) = pair;
    if (_swapsEnding(a, b, _evidentials)) {
      return const TopicInference(
        topics: [GrammarTopic.evidentials],
        confidence: _ruleConfidence,
      );
    }
    return null;
  }

  /// "rimani" -> "rimanki": the same verb with another person ending.
  TopicInference? _personEndingRule(ErrorPattern p) {
    final pair = _singleWords(p);
    if (pair == null) return null;
    final (a, b) = pair;
    if (_swapsEnding(a, b, _personEndings)) {
      return const TopicInference(
        topics: [GrammarTopic.verbConjugation],
        confidence: _ruleConfidence,
      );
    }
    return null;
  }

  /// "runa" -> "runakuna", or the reverse: the plural suffix added or dropped.
  TopicInference? _pluralRule(ErrorPattern p) {
    final pair = _singleWords(p);
    if (pair == null) return null;
    final (a, b) = pair;
    if (a.length >= _minRoot && b == '${a}kuna') return _plural;
    if (b.length >= _minRoot && a == '${b}kuna') return _plural;
    return null;
  }

  static const _plural = TopicInference(
    topics: [GrammarTopic.plural],
    confidence: _ruleConfidence,
  );

  /// "wasiman" -> "wasipi": the same root with another case suffix, or one
  /// added or dropped (less certain: the root may simply be another word).
  TopicInference? _caseSuffixRule(ErrorPattern p) {
    final pair = _singleWords(p);
    if (pair == null) return null;
    final (a, b) = pair;
    if (_swapsEnding(a, b, _caseSuffixes)) {
      return const TopicInference(
        topics: [GrammarTopic.caseSuffixes],
        confidence: _ruleConfidence,
      );
    }
    if (_swapsEnding(a, b, {'', ..._caseSuffixes})) {
      return const TopicInference(
        topics: [GrammarTopic.caseSuffixes],
        confidence: _coarseConfidence,
      );
    }
    return null;
  }

  /// The one word on each side of the correction, or `null` when either side
  /// is not exactly one word.
  (String, String)? _singleWords(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length != 1 || b.length != 1 || a.first == b.first) return null;
    return (a.first, b.first);
  }

  /// Whether [a] and [b] are one root (at least [_minRoot] letters) followed
  /// by two different endings of [endings]; an empty ending is "no suffix".
  /// Both words are tried against every ending they carry, so the longest
  /// reading that explains the pair is found whichever way the endings nest
  /// (-manta ends in -ta).
  bool _swapsEnding(String a, String b, Set<String> endings) {
    for (final ea in endings) {
      if (!a.endsWith(ea)) continue;
      final root = a.substring(0, a.length - ea.length);
      if (root.length < _minRoot) continue;
      for (final eb in endings) {
        if (eb != ea && b == '$root$eb') return true;
      }
    }
    return false;
  }

  // --- vocabulary of the rules ---------------------------------------------

  /// Direct knowledge (-mi after a consonant, -m after a vowel), reported
  /// (-si / -s) and conjecture (-chá).
  static const _evidentials = {'mi', 'm', 'si', 's', 'chá', 'cha'};

  /// Case suffixes: location, direction, origin, object, company, benefit,
  /// possession, limit and cause.
  static const _caseSuffixes = {
    'pi',
    'man',
    'manta',
    'ta',
    'wan',
    'paq',
    'pa',
    'qpa',
    'kama',
    'rayku',
  };

  /// The person endings of the present and of the past (-rqa-): I, you, he or
  /// she, we (with you), we (without you), you all, they.
  static const _personEndings = {
    'ni',
    'nki',
    'n',
    'nchis',
    'yku',
    'nkichis',
    'nku',
    'rqani',
    'rqanki',
    'rqan',
    'rqanchis',
    'rqayku',
    'rqankichis',
    'rqanku',
  };
}
