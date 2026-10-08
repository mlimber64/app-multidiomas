import 'package:parla_con_me/features/learning/domain/practice_evidence.dart';
import 'package:parla_con_me/features/learning/domain/language_scope.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/learning_overview.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';

/// Scriptable [AIService]: records every request and answers with [onRequest]
/// (default: a plain reply). Never touches the network.
class FakeAIService implements AIService {
  FakeAIService({Future<Result<AIResponse>> Function(AIRequest)? onRequest})
    : onRequest =
          onRequest ??
          ((_) async => const Success(AIResponse(message: 'Bene! E poi?')));

  Future<Result<AIResponse>> Function(AIRequest) onRequest;
  final requests = <AIRequest>[];

  @override
  Future<Result<AIResponse>> sendConversation(AIRequest request) {
    requests.add(request);
    return onRequest(request);
  }
}

/// A learning repository whose every operation fails (broken storage).
class FailingLearningRepository implements LearningRepository {
  int calls = 0;

  Future<Result<T>> _fail<T>() async {
    calls++;
    return const Failure(StorageFailure('disk error'));
  }

  @override
  Future<Result<LearnerLearningSummary>> getLearningSummary() => _fail();
  @override
  Future<Result<void>> recordError(LearningError occurrence) => _fail();
  @override
  Future<Result<void>> recordVocabulary(UserVocabulary occurrence) => _fail();
  @override
  Future<Result<void>> recordGrammarTopicExposure(
    GrammarTopic topic, {
    required DateTime at,
    bool wasError = false,
    String language = legacyLanguageCode,
  }) => _fail();
  @override
  Future<Result<void>> recordSuccessfulGrammarUse(
    GrammarTopic topic, {
    required DateTime at,
    String language = legacyLanguageCode,
  }) => _fail();
  @override
  Future<Result<bool>> applyPracticeEvidence(PracticeEvidence e) => _fail();
  @override
  Future<Result<void>> clearLearningData() => _fail();
}

/// An engine that reports a failed `Result` (e.g. storage trouble).
class FailingLearningEngine implements LearningEngine {
  int calls = 0;
  int contextCalls = 0;

  @override
  Future<Result<LearnerLearningSummary>> summary() async =>
      const Failure(StorageFailure('boom'));

  @override
  Future<Result<LearningContext>> learningContext() async {
    contextCalls++;
    return const Failure(StorageFailure('boom'));
  }

  @override
  Future<Result<LearningOverview>> overview() async =>
      const Failure(StorageFailure('boom'));

  @override
  Future<Result<void>> analyze({
    required String userMessage,
    required AIResponse response,
    String? contextId,
  }) async {
    calls++;
    return const Failure(StorageFailure('boom'));
  }
}

/// An engine with a bug: it throws instead of returning a `Result`.
class ThrowingLearningEngine implements LearningEngine {
  int calls = 0;
  int contextCalls = 0;

  @override
  Future<Result<LearnerLearningSummary>> summary() async =>
      throw StateError('bug');

  @override
  Future<Result<LearningContext>> learningContext() async {
    contextCalls++;
    throw StateError('bug building the learning context');
  }

  @override
  Future<Result<LearningOverview>> overview() async =>
      throw StateError('bug building the overview');

  @override
  Future<Result<void>> analyze({
    required String userMessage,
    required AIResponse response,
    String? contextId,
  }) async {
    calls++;
    throw StateError('bug in the learning engine');
  }
}

/// Records what the conversation feature reports to the Learning Engine.
class RecordingLearningEngine implements LearningEngine {
  RecordingLearningEngine({this.context = LearningContext.empty});

  /// What `learningContext()` answers.
  LearningContext context;
  int contextCalls = 0;
  final analyzed = <({String userMessage, AIResponse response})>[];

  /// The `contextId` of each analysis, in the same order as [analyzed].
  final contexts = <String?>[];

  @override
  Future<Result<LearnerLearningSummary>> summary() async =>
      const Success(LearnerLearningSummary.empty);

  @override
  Future<Result<LearningContext>> learningContext() async {
    contextCalls++;
    return Success(context);
  }

  @override
  Future<Result<LearningOverview>> overview() async =>
      const Success(LearningOverview.empty);

  @override
  Future<Result<void>> analyze({
    required String userMessage,
    required AIResponse response,
    String? contextId,
  }) async {
    analyzed.add((userMessage: userMessage, response: response));
    contexts.add(contextId);
    return const Success(null);
  }
}
