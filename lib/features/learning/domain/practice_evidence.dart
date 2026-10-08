import '../../../core/result/result.dart';

/// Where a piece of practice evidence comes from.
enum PracticeEvidenceSource { conversation, review }

/// What the learner had to do. Producing the answer is a stronger proof of
/// command than picking it from options.
enum PracticeEvidenceType {
  /// The learner wrote the answer (free conversation, typed correction).
  production,

  /// The learner chose between given options.
  recognition,

  /// The item was only seen: it says nothing about command.
  exposure,
}

enum PracticeEvidenceOutcome { success, failure }

/// How much a piece of evidence counts. A fixed table, no AI and no
/// randomness. The weights are exact binary fractions, so sums never drift.
/// Negative outcomes use the same scale (a failure of a strong
/// kind weighs like a success of that kind).
enum EvidenceStrength {
  veryStrong(1.0),
  strong(0.5),
  medium(0.375),
  weak(0.25),
  veryWeak(0.0625);

  const EvidenceStrength(this.weight);

  /// Share of one full occurrence (a message written in conversation).
  final double weight;
}

/// One result of real practice, in the learning domain's own terms. Immutable
/// and independent of where it came from (conversation, review): the
/// `LearningEngine` is the only one that turns it into learning memory.
class PracticeEvidence {
  const PracticeEvidence({
    required this.eventId,
    required this.source,
    required this.type,
    required this.outcome,
    required this.learningLanguage,
    required this.occurredAt,
    this.referenceId,
    this.grammarTopic,
    this.vocabularyWord,
    this.contextId,
  });

  /// Stable identity of the event: the same event delivered twice is applied
  /// once.
  final String eventId;
  final PracticeEvidenceSource source;
  final PracticeEvidenceType type;
  final PracticeEvidenceOutcome outcome;

  /// Language code the evidence belongs to; it never touches another one.
  final String learningLanguage;
  final DateTime occurredAt;

  /// Stable id of the learning item (the vocabulary id, the error id...).
  final String? referenceId;

  /// `GrammarTopic.name` when the evidence is about a grammar topic.
  final String? grammarTopic;

  /// The word when the evidence is about vocabulary.
  final String? vocabularyWord;

  /// The interaction the evidence happened in (a conversation, a review day).
  /// Evidence of the same interaction is never counted as different contexts
  /// when judging whether a concept is consolidated. `null`: unknown, which
  /// counts as one single interaction.
  final String? contextId;

  bool get isSuccess => outcome == PracticeEvidenceOutcome.success;

  /// The fixed hierarchy:
  /// conversation production (very strong) > review production (strong) >
  /// review recognition (weak when right, medium when wrong) > exposure (very
  /// weak).
  EvidenceStrength get strength {
    if (type == PracticeEvidenceType.exposure) return EvidenceStrength.veryWeak;
    return switch ((source, type, outcome)) {
      (PracticeEvidenceSource.conversation, _, _) =>
        EvidenceStrength.veryStrong,
      (
        PracticeEvidenceSource.review,
        PracticeEvidenceType.recognition,
        PracticeEvidenceOutcome.success,
      ) =>
        EvidenceStrength.weak,
      (
        PracticeEvidenceSource.review,
        PracticeEvidenceType.recognition,
        PracticeEvidenceOutcome.failure,
      ) =>
        EvidenceStrength.medium,
      _ => EvidenceStrength.strong,
    };
  }

  double get weight => strength.weight;

  @override
  bool operator ==(Object other) =>
      other is PracticeEvidence &&
      other.eventId == eventId &&
      other.source == source &&
      other.type == type &&
      other.outcome == outcome &&
      other.learningLanguage == learningLanguage &&
      other.occurredAt == occurredAt &&
      other.referenceId == referenceId &&
      other.grammarTopic == grammarTopic &&
      other.vocabularyWord == vocabularyWord &&
      other.contextId == contextId;

  @override
  int get hashCode => Object.hash(
    eventId,
    source,
    type,
    outcome,
    learningLanguage,
    occurredAt,
    referenceId,
    grammarTopic,
    vocabularyWord,
    contextId,
  );
}

/// Takes practice evidence into the learning model. Implemented by the
/// `LearningEngine`, the only writer of learning memory: whoever practices
/// (the review, the conversation) depends on this contract, never on a
/// repository.
abstract interface class PracticeEvidenceRecorder {
  /// Applies [evidence] once. Evidence for another language than the
  /// recorder's, for an item the memory does not know, or already applied, is
  /// ignored (and is not an error).
  Future<Result<void>> recordPracticeEvidence(PracticeEvidence evidence);
}
