import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'grammar_topic_inference.dart' show TopicInference;

/// Building blocks several languages' rules share. Each is language-neutral:
/// the words (articles, prepositions...) are handed in by the rules.

/// Confidence of a coarse rule: only small function words, or only the order,
/// changed.
const coarseRuleConfidence = 0.6;

/// A swap of small function words only (articles, prepositions): both sides at
/// most two words, all of them in [words]. One side may be empty (a word added
/// or dropped); callers that cannot allow that check it themselves.
TopicInference? functionWordInference(
  ErrorPattern p,
  Set<String> words,
  GrammarTopic topic,
) {
  final a = p.coreOriginalTokens;
  final b = p.coreCorrectedTokens;
  if (a.length > 2 || b.length > 2 || (a.isEmpty && b.isEmpty)) return null;
  if ([...a, ...b].every(words.contains)) {
    return TopicInference(topics: [topic], confidence: coarseRuleConfidence);
  }
  return null;
}

/// The same words in another order.
TopicInference? wordOrderInference(ErrorPattern p) {
  final a = p.coreOriginalTokens;
  final b = p.coreCorrectedTokens;
  if (a.length < 2 || a.length > 4 || a.length != b.length) return null;
  final sortedA = [...a]..sort();
  final sortedB = [...b]..sort();
  for (var i = 0; i < a.length; i++) {
    if (sortedA[i] != sortedB[i]) return null;
  }
  return const TopicInference(
    topics: [GrammarTopic.wordOrder],
    confidence: coarseRuleConfidence,
  );
}

/// The same verb with another ending: a long enough common beginning, and
/// short endings on both sides.
bool sameStemOtherEnding(String a, String b) {
  if (a == b || a.length < 3 || b.length < 3) return false;
  var common = 0;
  while (common < a.length && common < b.length && a[common] == b[common]) {
    common++;
  }
  return common >= 3 && a.length - common <= 4 && b.length - common <= 4;
}
