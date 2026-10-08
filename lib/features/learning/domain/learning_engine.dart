import '../../../core/result/result.dart';
import '../../../services/ai/ai_service.dart';
import 'learning_context.dart';
import 'learning_overview.dart';
import 'learning_summary.dart';

/// Turns interactions into learning memory:
///
///   user interaction -> AI analysis -> LearningEngine -> LearningRepository
///   -> (future) personalized sessions
///
/// Depends on the AI contract (`AIResponse`) and on `LearningRepository`,
/// never on UI, on a concrete provider, or on a storage technology.
abstract interface class LearningEngine {
  /// What has been learned about the learner so far.
  Future<Result<LearnerLearningSummary>> summary();

  /// What the learner-facing screens show about that memory (see
  /// `LearningOverview`). One memory read. A failure is reported, not hidden:
  /// the screens decide how to present it.
  Future<Result<LearningOverview>> overview();

  /// The small slice of that memory to personalize the next AI turn
  /// ([LearningContext.empty] when there is nothing worth sharing). One memory
  /// read. A failure means "no context": callers continue without it.
  Future<Result<LearningContext>> learningContext();

  /// Called after every assistant reply with what the learner wrote and what
  /// the AI answered (including structured corrections). Updates the memory.
  /// A failure here must never affect the conversation: callers treat this
  /// layer as secondary.
  ///
  /// [contextId] identifies the conversation, so that evidence from one
  /// conversation is never taken for evidence from several (see
  /// `PracticeEvidence.contextId`). Without it the evidence counts as coming
  /// from one single, unknown interaction.
  Future<Result<void>> analyze({
    required String userMessage,
    required AIResponse response,
    String? contextId,
  });
}
