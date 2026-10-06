import '../../profile/domain/language_pair.dart';
import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'grammar_topic_inference.dart' show TopicInference;
import 'language_learning_rules.dart';
import 'learning_error.dart';
import 'rule_helpers.dart';
import 'success_detection.dart';

/// The Mandarin Chinese rules (simplified characters). Small and conservative,
/// like any other language's rules: a rule fires only on a precise,
/// recognizable correction, and no topic is better than a wrong topic.
///
/// Chinese is written without spaces, so the learning system reads it one
/// character at a time (see `ErrorPattern`): a mistake is the few characters
/// that changed, and every rule here looks at those characters. Covered:
/// measure words, the particles 的 / 得 / 地, the aspect particles 了 / 过 / 着,
/// the negation 不 vs 没, and word order. Chinese has no articles, no
/// conjugation and no plural marking, so none of those topics exist here.
/// Nothing here is a grammar of Chinese: anything else is left without a topic.
class MandarinLearningRules implements LanguageLearningRules {
  const MandarinLearningRules();

  static const _ruleConfidence = 0.8;
  static const _coarseConfidence = coarseRuleConfidence;

  @override
  AppLanguage get language => AppLanguage.mandarin;

  /// Chinese has no articles.
  @override
  bool isArticle(String word) => false;

  @override
  String? get teachingNote =>
      'Write Chinese in simplified characters. For a beginner, or whenever you '
      'introduce new words, add the pinyin with tone marks in parentheses '
      'after the sentence, and explain in the support language.';

  @override
  TopicInference? inferGrammarTopics(ErrorPattern pattern) =>
      _negationRule(pattern) ??
      _structuralParticleRule(pattern) ??
      _measureWordRule(pattern) ??
      _aspectParticleRule(pattern) ??
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
    GrammarTopic.measureWords => 'measure words (量词)',
    GrammarTopic.structuralParticles => 'the particles 的, 得 and 地',
    GrammarTopic.aspectParticles => 'the aspect particles 了, 过 and 着',
    GrammarTopic.negation => 'negation with 不 and 没',
    GrammarTopic.wordOrder => 'word order',
    // Topics of other languages are not Chinese topics.
    _ => topic.name,
  };

  // --- rules ---------------------------------------------------------------

  /// "我不有书" -> "我没有书": 不 and 没 swapped.
  TopicInference? _negationRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length != 1 || b.length != 1) return null;
    final swapped =
        (a.first == '不' && b.first == '没') ||
        (a.first == '没' && b.first == '不');
    if (!swapped) return null;
    return const TopicInference(
      topics: [GrammarTopic.negation],
      confidence: _ruleConfidence,
    );
  }

  /// "他跑的很快" -> "他跑得很快": one of 的, 得, 地 replaced by another.
  TopicInference? _structuralParticleRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length != 1 || b.length != 1) return null;
    if (a.first != b.first &&
        _structural.contains(a.first) &&
        _structural.contains(b.first)) {
      return const TopicInference(
        topics: [GrammarTopic.structuralParticles],
        confidence: _ruleConfidence,
      );
    }
    return null;
  }

  /// "我有三书" -> "我有三本书" (added after a number or 这/那), and "一个书"
  /// -> "一本书" (one measure word replaced by another).
  TopicInference? _measureWordRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    final swapped =
        a.length == 1 &&
        b.length == 1 &&
        a.first != b.first &&
        _measureWords.contains(a.first) &&
        _measureWords.contains(b.first);
    final added =
        a.isEmpty &&
        b.length == 1 &&
        _measureWords.contains(b.first) &&
        _numbers.contains(p.precedingToken);
    if (!swapped && !added) return null;
    return const TopicInference(
      topics: [GrammarTopic.measureWords],
      confidence: _ruleConfidence,
    );
  }

  /// "我去过中国" -> "我去了中国", or a 了 added or dropped: the aspect particles
  /// 了, 过 and 着.
  TopicInference? _aspectParticleRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    final swapped =
        a.length == 1 &&
        b.length == 1 &&
        a.first != b.first &&
        _aspect.contains(a.first) &&
        _aspect.contains(b.first);
    final oneSided =
        (a.isEmpty && b.length == 1 && _aspect.contains(b.first)) ||
        (b.isEmpty && a.length == 1 && _aspect.contains(a.first));
    if (!swapped && !oneSided) return null;
    return const TopicInference(
      topics: [GrammarTopic.aspectParticles],
      confidence: _coarseConfidence,
    );
  }

  // --- vocabulary of the rules ---------------------------------------------

  static const _structural = {'的', '得', '地'};
  static const _aspect = {'了', '过', '着'};

  static const _measureWords = {
    '个',
    '本',
    '张',
    '只',
    '条',
    '件',
    '杯',
    '位',
    '辆',
    '双',
    '把',
    '些',
    '块',
    '支',
    '封',
    '台',
    '头',
    '间',
    '口',
    '瓶',
    '家',
    '片',
  };

  /// What a measure word follows: a number, or 这 / 那 / 几 / 每.
  static const _numbers = {
    '一',
    '二',
    '两',
    '三',
    '四',
    '五',
    '六',
    '七',
    '八',
    '九',
    '十',
    '几',
    '这',
    '那',
    '每',
  };
}
