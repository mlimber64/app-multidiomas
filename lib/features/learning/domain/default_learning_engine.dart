import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../services/ai/ai_service.dart';
import '../../../shared/models/correction.dart';
import '../../profile/domain/user_learning_profile.dart';
import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'language_learning_rules.dart';
import 'language_scope.dart';
import 'learning_context.dart';
import 'learning_context_builder.dart';
import 'learning_engine.dart';
import 'learning_error.dart';
import 'learning_overview.dart';
import 'learning_repository.dart';
import 'learning_signal.dart';
import 'learning_summary.dart';
import 'practice_evidence.dart';
import 'success_detection.dart';
import 'user_vocabulary.dart';

/// Deterministic engine that turns one exchange into learning memory. One AI
/// response in, no further AI calls:
///
///   AI corrections --------------------------> mistakes, topic exposure,
///                                              relevant vocabulary
///   learner's message + what is already known -> detected correct use
///
/// Everything is expressed as [LearningSignal]s (`interpret*`, pure) and then
/// applied to the repository (`apply`).
///
/// What it deliberately does NOT do: analyze language in general, count a
/// topic as used correctly without a prior mistake to compare against, send
/// anything to an AI, or decide what to practice next.
class DefaultLearningEngine
    implements LearningEngine, PracticeEvidenceRecorder {
  DefaultLearningEngine(
    this._repository, {
    required this.rules,
    DateTime Function()? clock,
    this.onMemoryChanged,
  }) : _clock = clock ?? DateTime.now;

  final LearningRepository _repository;

  /// Called after the engine really changed the learning memory: once per
  /// [analyze] that wrote something, once per [apply] or
  /// [recordPracticeEvidence] that changed something. Never when nothing
  /// changed (foreign language, repeated event, unknown item, failed write).
  /// It is how whoever shows the memory learns that it must read it again; the
  /// engine knows nothing about who that is.
  final void Function()? onMemoryChanged;

  /// The rules of the language the learner is learning (from their profile):
  /// the engine coordinates and asks them, it never branches on a language.
  final LanguageLearningRules rules;

  /// Decides which vocabulary is considered and the language of newly
  /// recorded words.
  AppLanguage get learningLanguage => rules.language;
  final DateTime Function() _clock;

  /// Certainty of an explicit AI correction.
  static const aiCorrectionConfidence = 0.9;

  /// Vocabulary shorter than this is too ambiguous to track.
  static const minVocabularyLength = 3;

  @override
  Future<Result<LearnerLearningSummary>> summary() => _currentSummary();

  /// The memory holds every language the learner has studied; the engine only
  /// ever works with the current one.
  Future<Result<LearnerLearningSummary>> _currentSummary() async =>
      switch (await _repository.getLearningSummary()) {
        Failure(:final failure) => Failure(failure),
        Success(value: final all) => Success(
          all.forLanguage(learningLanguage.code),
        ),
      };

  @override
  Future<Result<LearningOverview>> overview() async {
    final now = _clock();
    return switch (await _currentSummary()) {
      Failure(:final failure) => Failure(failure),
      Success(value: final known) => Success(
        buildLearningOverview(known, now: now, rules: rules),
      ),
    };
  }

  @override
  Future<Result<LearningContext>> learningContext() async {
    final now = _clock();
    return switch (await _currentSummary()) {
      Failure(:final failure) => Failure(failure),
      Success(value: final known) => Success(
        buildLearningContext(known, now: now, language: learningLanguage.code),
      ),
    };
  }

  @override
  Future<Result<void>> analyze({
    required String userMessage,
    required AIResponse response,
    String? contextId,
  }) async {
    final now = _clock();
    AppFailure? firstFailure;

    final errorSignals = interpret(response.corrections, at: now);

    // Successes are judged against what was known BEFORE this turn.
    var successSignals = const <LearningSignal>[];
    switch (await _currentSummary()) {
      case Failure(:final failure):
        firstFailure = failure;
      case Success(value: final known):
        successSignals = interpretSuccesses(
          userMessage: userMessage,
          errorSignals: errorSignals,
          known: known,
          at: now,
        );
    }

    var changed = false;
    for (final signal in [...errorSignals, ...successSignals]) {
      // Keep going after a failure so one bad write doesn't drop the rest.
      switch (await _applySignal(signal, contextId: contextId)) {
        case Failure(:final failure):
          firstFailure ??= failure;
        case Success(value: final didChange):
          changed = changed || didChange;
      }
    }
    // One notification per analysis, and only if the memory really changed.
    if (changed) onMemoryChanged?.call();
    final failure = firstFailure;
    return failure == null ? const Success(null) : Failure(failure);
  }

  /// Corrections -> signals. Pure: no storage involved.
  List<LearningSignal> interpret(
    List<Correction> corrections, {
    required DateTime at,
  }) {
    final signals = <LearningSignal>[];
    var counter = 0;
    String nextId() => '${at.microsecondsSinceEpoch}-${counter++}';

    for (final correction in corrections) {
      final pattern = ErrorPattern.from(
        correction.original,
        correction.corrected,
      );
      // Identical or empty texts are not a mistake: record nothing.
      if (pattern == null) continue;

      // Topic inference only makes sense for grammar-like corrections.
      final inference = switch (correction.category) {
        CorrectionCategory.grammar ||
        CorrectionCategory.other => rules.inferGrammarTopics(pattern),
        _ => null,
      };
      final category = _categoryFor(correction.category, inference?.primary);
      final isVocabulary = correction.category == CorrectionCategory.vocabulary;

      signals.add(
        LearningSignal(
          id: nextId(),
          type: switch (correction.category) {
            CorrectionCategory.grammar => LearningSignalType.grammarError,
            CorrectionCategory.vocabulary => LearningSignalType.vocabularyIssue,
            _ => LearningSignalType.correction,
          },
          source: LearningSignalSource.aiCorrection,
          createdAt: at,
          confidence: aiCorrectionConfidence,
          metadata: {
            // Scoped by language, so the same words in two languages are two
            // different mistakes.
            SignalKeys.patternKey: scopedId(learningLanguage.code, pattern.key),
            SignalKeys.original: pattern.original,
            SignalKeys.corrected: pattern.corrected,
            SignalKeys.explanation: correction.explanation,
            SignalKeys.category: category.name,
            SignalKeys.topic: inference?.primary.name,
            if (isVocabulary) SignalKeys.word: _vocabularyWord(pattern),
          },
        ),
      );

      for (final topic in inference?.topics ?? const <GrammarTopic>[]) {
        signals.add(
          LearningSignal(
            id: nextId(),
            type: LearningSignalType.topicExposure,
            source: LearningSignalSource.ruleInference,
            createdAt: at,
            confidence: inference!.confidence,
            metadata: {SignalKeys.topic: topic.name, SignalKeys.wasError: true},
          ),
        );
      }
    }
    return signals;
  }

  /// The learner's message + the memory as it was -> signals for correct use
  /// of things they were previously corrected on. Pure: no storage involved.
  /// See [detectGrammarSuccesses] / [detectVocabularySuccesses] for the exact,
  /// conservative rules. [errorSignals] are this turn's `interpret` results,
  /// so a topic or word that was just wrong in this message is never also
  /// counted as a success.
  List<LearningSignal> interpretSuccesses({
    required String userMessage,
    required List<LearningSignal> errorSignals,
    required LearnerLearningSummary known,
    required DateTime at,
  }) {
    final tokens = ErrorPattern.tokensOf(userMessage);
    if (tokens.isEmpty) return const [];

    final errorKeys = <String>{};
    final errorTopics = <GrammarTopic>{};
    final vocabularyIds = <String>{};
    for (final s in errorSignals) {
      switch (s.type) {
        case LearningSignalType.grammarError:
        case LearningSignalType.vocabularyIssue:
        case LearningSignalType.correction:
          errorKeys.add(s.metadata[SignalKeys.patternKey]! as String);
          final word = s.metadata[SignalKeys.word];
          if (word is String) {
            vocabularyIds.add(
              UserVocabulary.idFor(word, learningLanguage.code),
            );
          }
        case LearningSignalType.topicExposure:
          final topic = _topicFrom(s.metadata[SignalKeys.topic]);
          if (topic != null) errorTopics.add(topic);
        case LearningSignalType.successfulGrammarUse:
        case LearningSignalType.successfulVocabularyUse:
      }
    }

    final signals = <LearningSignal>[];
    var counter = 0;
    String nextId() => '${at.microsecondsSinceEpoch}-s${counter++}';

    final grammar = rules.detectGrammarSuccesses(
      messageTokens: tokens,
      knownErrors: known.errors,
      errorKeysThisTurn: errorKeys,
      errorTopicsThisTurn: errorTopics,
    );
    for (final entry in grammar.entries) {
      signals.add(
        LearningSignal(
          id: nextId(),
          type: LearningSignalType.successfulGrammarUse,
          source: LearningSignalSource.ruleInference,
          createdAt: at,
          confidence: entry.value,
          metadata: {SignalKeys.topic: entry.key.name},
        ),
      );
    }

    final vocabulary = detectVocabularySuccesses(
      messageTokens: tokens,
      vocabulary: known.vocabularyItems.where(
        (v) => v.language == learningLanguage.code,
      ),
      idsThisTurn: vocabularyIds,
    );
    for (final item in vocabulary) {
      signals.add(
        LearningSignal(
          id: nextId(),
          type: LearningSignalType.successfulVocabularyUse,
          source: LearningSignalSource.ruleInference,
          createdAt: at,
          confidence: literalSuccessConfidence,
          metadata: {SignalKeys.word: item.word},
        ),
      );
    }
    return signals;
  }

  /// Applies one signal to the memory.
  Future<Result<void>> apply(LearningSignal signal) async {
    switch (await _applySignal(signal)) {
      case Failure(:final failure):
        return Failure(failure);
      case Success(value: final changed):
        if (changed) onMemoryChanged?.call();
        return const Success(null);
    }
  }

  /// Writes the memory for one signal. Returns whether it changed.
  ///
  /// Every write to `learning_memory` is made here, through the repository:
  /// the mistakes (and the vocabulary they teach) are recorded as such, and
  /// everything that proves command of a topic or a word goes through
  /// [PracticeEvidence], the same contract the review uses.
  Future<Result<bool>> _applySignal(
    LearningSignal signal, {
    String? contextId,
  }) async {
    final m = signal.metadata;
    switch (signal.type) {
      case LearningSignalType.grammarError:
      case LearningSignalType.correction:
        return _changed(_repository.recordError(_errorFrom(signal)));

      case LearningSignalType.vocabularyIssue:
        final recorded = await _repository.recordError(_errorFrom(signal));
        if (recorded is Failure<void>) return Failure(recorded.failure);
        // The correct word is relevant vocabulary the learner struggled with.
        final word = m[SignalKeys.word];
        if (word is! String) return const Success(true);
        final vocabulary = await _repository.recordVocabulary(
          UserVocabulary.of(
            word: word,
            at: signal.createdAt,
            language: learningLanguage.code,
          ),
        );
        // The mistake is already in the memory even if the word is not.
        return vocabulary is Failure<void>
            ? Failure(vocabulary.failure)
            : const Success(true);

      case LearningSignalType.topicExposure:
        final topic = _topicFrom(m[SignalKeys.topic]);
        if (topic == null) return const Success(false);
        if (m[SignalKeys.wasError] != true) {
          // A topic that came up without a mistake. Kept as a plain exposure
          // (a full occurrence, no success) rather than as exposure evidence,
          // whose weight is that of something merely seen. The analysis never
          // produces it today (see `interpret`); it stays inside the engine,
          // the only writer.
          return _changed(
            _repository.recordGrammarTopicExposure(
              topic,
              language: learningLanguage.code,
              at: signal.createdAt,
            ),
          );
        }
        return _applyEvidence(
          _conversationEvidence(
            signal,
            PracticeEvidenceOutcome.failure,
            grammarTopic: topic,
            contextId: contextId,
          ),
        );

      case LearningSignalType.successfulGrammarUse:
        final topic = _topicFrom(m[SignalKeys.topic]);
        if (topic == null) return const Success(false);
        return _applyEvidence(
          _conversationEvidence(
            signal,
            PracticeEvidenceOutcome.success,
            grammarTopic: topic,
            contextId: contextId,
          ),
        );

      case LearningSignalType.successfulVocabularyUse:
        final word = m[SignalKeys.word];
        if (word is! String || word.trim().isEmpty) {
          return const Success(false);
        }
        if (m[SignalKeys.meaning] is String) {
          return _changed(
            _repository.recordVocabulary(
              UserVocabulary.of(
                word: word,
                at: signal.createdAt,
                language: learningLanguage.code,
                meaning: m[SignalKeys.meaning] as String?,
                successfulUseCount: 1,
              ),
            ),
          );
        }
        return _applyEvidence(
          _conversationEvidence(
            signal,
            PracticeEvidenceOutcome.success,
            vocabularyWord: word,
            contextId: contextId,
          ),
        );
    }
  }

  static Future<Result<bool>> _changed(Future<Result<void>> write) async =>
      switch (await write) {
        Failure(:final failure) => Failure(failure),
        Success() => const Success(true),
      };

  /// What the learner wrote in conversation, as practice evidence: the same
  /// contract review uses. Written language is the strongest proof there is.
  PracticeEvidence _conversationEvidence(
    LearningSignal signal,
    PracticeEvidenceOutcome outcome, {
    GrammarTopic? grammarTopic,
    String? vocabularyWord,
    String? contextId,
  }) => PracticeEvidence(
    eventId: 'conversation:${signal.id}',
    source: PracticeEvidenceSource.conversation,
    type: PracticeEvidenceType.production,
    outcome: outcome,
    learningLanguage: learningLanguage.code,
    occurredAt: signal.createdAt,
    grammarTopic: grammarTopic?.name,
    vocabularyWord: vocabularyWord,
    contextId: contextId,
    referenceId: vocabularyWord == null
        ? null
        : UserVocabulary.idFor(vocabularyWord, learningLanguage.code),
  );

  /// The one way practice (conversation or review) reaches learning memory.
  /// Evidence for another language is not ours to record; the same event twice
  /// counts once (the repository remembers it).
  @override
  Future<Result<void>> recordPracticeEvidence(PracticeEvidence evidence) async {
    switch (await _applyEvidence(evidence)) {
      case Failure(:final failure):
        return Failure(failure);
      case Success(value: final changed):
        if (changed) onMemoryChanged?.call();
        return const Success(null);
    }
  }

  /// Applies [evidence] and says whether the memory changed.
  Future<Result<bool>> _applyEvidence(PracticeEvidence evidence) async {
    if (evidence.learningLanguage != learningLanguage.code) {
      return const Success(false);
    }
    return _repository.applyPracticeEvidence(evidence);
  }

  LearningError _errorFrom(LearningSignal signal) {
    final m = signal.metadata;
    return LearningError(
      // The pattern key is the identity, so repeats of a mistake merge.
      id: m[SignalKeys.patternKey]! as String,
      language: learningLanguage.code,
      category: LearningErrorCategory.values.firstWhere(
        (c) => c.name == m[SignalKeys.category],
        orElse: () => LearningErrorCategory.other,
      ),
      original: m[SignalKeys.original]! as String,
      corrected: m[SignalKeys.corrected]! as String,
      explanation: (m[SignalKeys.explanation] as String?) ?? '',
      grammarTopic: _topicFrom(m[SignalKeys.topic]),
      firstSeenAt: signal.createdAt,
      lastSeenAt: signal.createdAt,
      confidence: signal.confidence,
    );
  }

  static GrammarTopic? _topicFrom(Object? name) {
    for (final t in GrammarTopic.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// The word a vocabulary correction teaches: only the corrected words that
  /// differ (no context word), without a leading article ("il computer" ->
  /// "computer"). `null` when it is empty, too short, or a phrase of more than
  /// three words: the error is still recorded, just not as vocabulary.
  String? _vocabularyWord(ErrorPattern pattern) {
    final tokens = [...pattern.coreCorrectedTokens];
    while (tokens.length > 1 && rules.isArticle(tokens.first)) {
      tokens.removeAt(0);
    }
    // Han characters are words of one character each, and carry more than a
    // letter does: a Chinese word may have four and counts double.
    final han = tokens.isNotEmpty && tokens.every(ErrorPattern.isHan);
    if (tokens.isEmpty || tokens.length > (han ? 4 : 3)) return null;
    final word = ErrorPattern.joinTokens(tokens);
    final weight = han ? 2 : 1;
    if (word.length * weight < minVocabularyLength || rules.isArticle(word)) {
      return null;
    }
    return word;
  }

  /// The AI's coarse category, refined by an inferred topic when that is more
  /// specific.
  static LearningErrorCategory _categoryFor(
    CorrectionCategory category,
    GrammarTopic? topic,
  ) {
    final refined = switch (topic) {
      GrammarTopic.prepositions => LearningErrorCategory.preposition,
      GrammarTopic.wordOrder => LearningErrorCategory.wordOrder,
      GrammarTopic.agreement ||
      GrammarTopic.gender ||
      GrammarTopic.plural => LearningErrorCategory.agreement,
      _ => null,
    };
    if (refined != null) return refined;
    return switch (category) {
      CorrectionCategory.grammar => LearningErrorCategory.grammar,
      CorrectionCategory.vocabulary => LearningErrorCategory.vocabulary,
      CorrectionCategory.spelling => LearningErrorCategory.spelling,
      _ => LearningErrorCategory.other,
    };
  }
}
