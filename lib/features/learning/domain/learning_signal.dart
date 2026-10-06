enum LearningSignalType {
  grammarError,
  vocabularyIssue,

  /// An explicit correction that is neither clearly grammar nor vocabulary
  /// (spelling, naturalness, other).
  correction,
  topicExposure,

  /// The learner used correctly something they had been corrected on.
  successfulGrammarUse,

  /// The learner used correctly a word already in their vocabulary memory.
  successfulVocabularyUse,
}

enum LearningSignalSource {
  /// Reported directly by the AI (e.g. a structured `Correction`).
  aiCorrection,

  /// Derived by the app's own deterministic rules.
  ruleInference,
}

/// Keys used in [LearningSignal.metadata].
abstract final class SignalKeys {
  /// Normalized pattern identity (see `ErrorPattern.key`).
  static const patternKey = 'patternKey';
  static const original = 'original';
  static const corrected = 'corrected';
  static const explanation = 'explanation';
  static const category = 'category';
  static const topic = 'topic';
  static const wasError = 'wasError';
  static const word = 'word';
  static const meaning = 'meaning';
}

/// One piece of evidence about the learner, produced by the engine when it
/// interprets an interaction. Signals are the engine's working language and
/// are not persisted: what is stored is the accumulated memory (errors,
/// topics, vocabulary), which stays bounded.
class LearningSignal {
  const LearningSignal({
    required this.id,
    required this.type,
    required this.source,
    required this.createdAt,
    required this.confidence,
    this.metadata = const {},
  });

  final String id;
  final LearningSignalType type;
  final LearningSignalSource source;
  final DateTime createdAt;

  /// 0.0..1.0 certainty of the evidence: 0.9 explicit AI correction, 0.8/0.6
  /// precise/coarse rule inference.
  final double confidence;

  /// Plain values keyed by [SignalKeys]; shape depends on [type].
  final Map<String, Object?> metadata;
}
