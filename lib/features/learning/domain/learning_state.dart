import 'practice_evidence.dart';

/// Where the learner stands on ONE concept (a grammar topic or a word), judged
/// only from structured practice evidence. It says nothing about the learner's
/// overall level, which stays what they declared.
///
/// - [newConcept]: not enough evidence to say anything. Practiced as usual.
/// - [weak]: clear, active difficulty.
/// - [improving]: production has been shown, not yet enough to trust it.
/// - [consolidated]: correct production, repeated and in different
///   interactions, with no recent collapse. Not permanent: it can be lost.
enum LearningState { newConcept, weak, improving, consolidated }

/// How demanding the next practice of a concept should be.
enum AdaptationStrategy { simplify, keep, stretch }

/// The one place that says which strategy a state calls for.
extension LearningStateStrategy on LearningState {
  AdaptationStrategy get strategy => switch (this) {
    LearningState.newConcept => AdaptationStrategy.keep,
    LearningState.weak => AdaptationStrategy.simplify,
    LearningState.improving => AdaptationStrategy.keep,
    LearningState.consolidated => AdaptationStrategy.stretch,
  };
}

/// The thresholds of [PracticeProof.stateOf], in one place.
abstract final class LearningStatePolicy {
  /// Production outcomes remembered per concept (newest last).
  static const recentWindow = 5;

  /// Distinct interactions remembered per concept.
  static const maxContexts = 5;

  /// Correct productions that show the learner can produce the concept.
  static const provenMinProduction = 2;

  /// Correct productions needed to consolidate...
  static const consolidatedMinProduction = 3;

  /// ...spread over at least this many different interactions.
  static const consolidatedMinContexts = 2;

  /// A consolidated concept tolerates this many failures among the latest
  /// [recentWindow] productions: one slip, not a pattern. With more it is no
  /// longer consolidated. Because that needs a calm recent record, a weak
  /// concept cannot become consolidated in a single step: it passes through
  /// improving first.
  static const consolidatedMaxRecentFailures = 1;

  /// The interaction of evidence that does not say which one it came from. All
  /// of it counts as one single interaction.
  static const unknownContext = 'unknown';
}

/// What the learner has actually demonstrated about one concept. A compact
/// ledger inside the learning memory (bounded, additive), not a second memory:
/// the state is always derived from it by [stateOf].
///
/// Only [PracticeEvidenceType.production] can show command. Recognition is
/// counted apart and can reveal a difficulty, but never proves anything.
class PracticeProof {
  const PracticeProof({
    this.productionSuccesses = 0,
    this.productionFailures = 0,
    this.recognitionSuccesses = 0,
    this.recognitionFailures = 0,
    this.recent = const <bool>[],
    this.contexts = const <String>[],
  });

  static const empty = PracticeProof();

  /// The learner produced it correctly / wrongly (wrote it, typed it).
  final int productionSuccesses;
  final int productionFailures;

  /// The learner picked it correctly / wrongly among given options.
  final int recognitionSuccesses;
  final int recognitionFailures;

  /// The latest production outcomes, oldest first, at most
  /// [LearningStatePolicy.recentWindow]. `true` is a correct one.
  final List<bool> recent;

  /// The distinct interactions in which a correct production happened, oldest
  /// first, at most [LearningStatePolicy.maxContexts].
  final List<String> contexts;

  bool get isEmpty =>
      productionSuccesses == 0 &&
      productionFailures == 0 &&
      recognitionSuccesses == 0 &&
      recognitionFailures == 0;

  int get _recentSuccesses => recent.where((ok) => ok).length;
  int get _recentFailures => recent.length - _recentSuccesses;

  /// The learner has produced the concept correctly more than once and does
  /// not currently fail it more than they get it right. Recognition never
  /// contributes.
  bool get productionProven =>
      productionSuccesses >= LearningStatePolicy.provenMinProduction &&
      _recentSuccesses >= _recentFailures;

  /// Takes one piece of evidence. [PracticeEvidenceType.exposure] says nothing
  /// about command and changes nothing. [context] identifies the interaction
  /// (a conversation, a review day); the same one is never counted twice.
  PracticeProof record({
    required PracticeEvidenceType type,
    required bool success,
    String? context,
  }) {
    switch (type) {
      case PracticeEvidenceType.exposure:
        return this;
      case PracticeEvidenceType.recognition:
        return _copy(
          recognitionSuccesses: recognitionSuccesses + (success ? 1 : 0),
          recognitionFailures: recognitionFailures + (success ? 0 : 1),
        );
      case PracticeEvidenceType.production:
        final recentOutcomes = [...recent, success];
        final key = context ?? LearningStatePolicy.unknownContext;
        final seen = [...contexts];
        if (success && !seen.contains(key)) seen.add(key);
        return _copy(
          productionSuccesses: productionSuccesses + (success ? 1 : 0),
          productionFailures: productionFailures + (success ? 0 : 1),
          recent: _last(recentOutcomes, LearningStatePolicy.recentWindow),
          contexts: _last(seen, LearningStatePolicy.maxContexts),
        );
    }
  }

  /// The state this evidence supports. [hadDifficulty] is whether the concept
  /// is known to have been a problem for reasons that predate or lie outside
  /// the ledger (a mistake the learner made in conversation).
  ///
  /// - consolidated: proven, at least 3 correct productions in at least 2
  ///   interactions, and at most one failure among the latest 5 productions;
  /// - improving: proven;
  /// - weak: any difficulty seen, not proven;
  /// - new: otherwise.
  LearningState stateOf({required bool hadDifficulty}) {
    if (productionProven) {
      final consolidated =
          productionSuccesses >=
              LearningStatePolicy.consolidatedMinProduction &&
          contexts.length >= LearningStatePolicy.consolidatedMinContexts &&
          _recentFailures <= LearningStatePolicy.consolidatedMaxRecentFailures;
      return consolidated
          ? LearningState.consolidated
          : LearningState.improving;
    }
    final difficulty =
        hadDifficulty || productionFailures > 0 || recognitionFailures > 0;
    return difficulty ? LearningState.weak : LearningState.newConcept;
  }

  PracticeProof _copy({
    int? productionSuccesses,
    int? productionFailures,
    int? recognitionSuccesses,
    int? recognitionFailures,
    List<bool>? recent,
    List<String>? contexts,
  }) => PracticeProof(
    productionSuccesses: productionSuccesses ?? this.productionSuccesses,
    productionFailures: productionFailures ?? this.productionFailures,
    recognitionSuccesses: recognitionSuccesses ?? this.recognitionSuccesses,
    recognitionFailures: recognitionFailures ?? this.recognitionFailures,
    recent: recent ?? this.recent,
    contexts: contexts ?? this.contexts,
  );

  static List<T> _last<T>(List<T> items, int max) =>
      items.length > max ? items.sublist(items.length - max) : items;

  Map<String, Object?> toJson() => {
    'productionSuccesses': productionSuccesses,
    'productionFailures': productionFailures,
    'recognitionSuccesses': recognitionSuccesses,
    'recognitionFailures': recognitionFailures,
    'recent': recent,
    'contexts': contexts,
  };

  /// Defensive: anything that is not a well-formed ledger reads as [empty],
  /// and malformed parts are dropped or clamped.
  static PracticeProof fromJson(Object? json) {
    if (json is! Map) return empty;
    int count(Object? v) => v is int && v >= 0 ? v : 0;
    final recent = json['recent'];
    final contexts = json['contexts'];
    return PracticeProof(
      productionSuccesses: count(json['productionSuccesses']),
      productionFailures: count(json['productionFailures']),
      recognitionSuccesses: count(json['recognitionSuccesses']),
      recognitionFailures: count(json['recognitionFailures']),
      recent: recent is List
          ? _last([
              for (final v in recent) ?(v is bool ? v : null),
            ], LearningStatePolicy.recentWindow)
          : const [],
      contexts: contexts is List
          ? _last(
              <String>{
                for (final v in contexts) ?(v is String ? v : null),
              }.toList(),
              LearningStatePolicy.maxContexts,
            )
          : const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PracticeProof &&
      other.productionSuccesses == productionSuccesses &&
      other.productionFailures == productionFailures &&
      other.recognitionSuccesses == recognitionSuccesses &&
      other.recognitionFailures == recognitionFailures &&
      _same(other.recent, recent) &&
      _same(other.contexts, contexts);

  @override
  int get hashCode => Object.hash(
    productionSuccesses,
    productionFailures,
    recognitionSuccesses,
    recognitionFailures,
    Object.hashAll(recent),
    Object.hashAll(contexts),
  );

  static bool _same(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
