import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'grammar_topic_inference.dart';
import 'learning_error.dart';
import 'user_vocabulary.dart';

/// Certainty that a message shows correct use, by kind of evidence: the exact
/// corrected wording of a known mistake is stronger than the same structure
/// with different words.
const literalSuccessConfidence = 0.7;
const structuralSuccessConfidence = 0.6;

/// Deterministic, deliberately conservative detection of *correct use*. It
/// only ever looks for things the learner was previously corrected on, never
/// for "good Italian" in general, so a message about pizza proves nothing
/// about the past tense. Fewer, reliable successes beat many doubtful ones.
///
/// A topic is credited from a known mistake only when ALL hold:
/// 1. The mistake has an inferred topic (so success can be attributed).
/// 2. The message contains the mistake's *corrected* wording as consecutive
///    words (`sono andato` for `ho andato -> sono andato`), or, for the
///    essere/avere auxiliary rule, the same verb with any essere form and any
///    gender/number (`siamo andati`, `è andata`).
/// 3. The message does NOT contain the mistaken wording (`ho andato`, or
///    `abbiamo andato` with the same verb): a mixed message is not evidence.
/// 4. This turn's AI response did not correct that same mistake, and did not
///    report any mistake in that same topic: the topic was just used wrongly.
///
/// The result has at most one entry per topic (the strongest evidence), so a
/// message that repeats the construction counts once. Limitations: other
/// persons/tenses/verbs of the same rule (`sono venuto` after `ho andato`)
/// are not credited; plural/inflected forms of articles or prepositions are
/// not; there is no understanding of meaning, only wording.
Map<GrammarTopic, double> detectGrammarSuccesses({
  required List<String> messageTokens,
  required Iterable<LearningError> knownErrors,
  required Set<String> errorKeysThisTurn,
  required Set<GrammarTopic> errorTopicsThisTurn,
}) {
  final successes = <GrammarTopic, double>{};
  for (final error in knownErrors) {
    if (error.grammarTopic == null) continue;
    if (errorKeysThisTurn.contains(error.id)) continue;
    final pattern = ErrorPattern.from(error.original, error.corrected);
    if (pattern == null) continue;
    final inference = inferGrammarTopics(pattern);
    if (inference == null) continue;

    final confidence = _grammarEvidence(messageTokens, pattern, inference);
    if (confidence == null) continue;

    for (final topic in inference.topics) {
      if (errorTopicsThisTurn.contains(topic)) continue;
      final known = successes[topic];
      if (known == null || confidence > known) successes[topic] = confidence;
    }
  }
  return successes;
}

double? _grammarEvidence(
  List<String> message,
  ErrorPattern pattern,
  TopicInference inference,
) {
  // The mistaken wording is still there: not evidence of correct use.
  if (ErrorPattern.containsSequence(message, pattern.originalTokens)) {
    return null;
  }
  final stem = inference.primary == GrammarTopic.essereVsAvere
      ? essereParticipleStem(pattern.correctedTokens)
      : null;
  if (stem != null && hasAvereConstruction(message, stem)) return null;

  if (ErrorPattern.containsSequence(message, pattern.correctedTokens)) {
    return literalSuccessConfidence;
  }
  if (stem != null && hasEssereConstruction(message, stem)) {
    return structuralSuccessConfidence;
  }
  return null;
}

/// Correct-use detection from literal evidence only, for languages whose rules
/// have no structural variants: a known mistake of the language, with the
/// topic recorded when it was seen, is now written in its corrected wording and
/// not in its mistaken wording, and the topic was not just used wrongly this
/// turn. The topic is the recorded one (inferred then, with the whole
/// sentence); the stored fragment may have lost that context.
Map<GrammarTopic, double> detectLiteralGrammarSuccesses({
  required List<String> messageTokens,
  required Iterable<LearningError> knownErrors,
  required Set<String> errorKeysThisTurn,
  required Set<GrammarTopic> errorTopicsThisTurn,
}) {
  final successes = <GrammarTopic, double>{};
  for (final error in knownErrors) {
    final topic = error.grammarTopic;
    if (topic == null) continue;
    if (errorKeysThisTurn.contains(error.id)) continue;
    if (errorTopicsThisTurn.contains(topic)) continue;
    final pattern = ErrorPattern.from(error.original, error.corrected);
    if (pattern == null) continue;
    if (ErrorPattern.containsSequence(messageTokens, pattern.originalTokens)) {
      continue;
    }
    if (!ErrorPattern.containsSequence(
      messageTokens,
      pattern.correctedTokens,
    )) {
      continue;
    }
    final known = successes[topic];
    if (known == null || literalSuccessConfidence > known) {
      successes[topic] = literalSuccessConfidence;
    }
  }
  return successes;
}

/// Known vocabulary that the learner used in [messageTokens]: only words
/// already in the memory count (found as whole words, case-insensitive,
/// consecutive for multi-word items), never arbitrary words. Items whose id is
/// in [idsThisTurn] (just corrected in this very turn) are excluded. One
/// entry per item however many times it appears. Inflected forms
/// (`prenotazioni`) are not matched.
List<UserVocabulary> detectVocabularySuccesses({
  required List<String> messageTokens,
  required Iterable<UserVocabulary> vocabulary,
  required Set<String> idsThisTurn,
}) => [
  for (final item in vocabulary)
    if (!idsThisTurn.contains(item.id) &&
        ErrorPattern.containsSequence(
          messageTokens,
          ErrorPattern.tokensOf(item.word),
        ))
      item,
];
