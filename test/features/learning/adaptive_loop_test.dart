import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/presentation/conversation_controller.dart';
import 'package:parla_con_me/features/daily_routine/domain/scenario_generator.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/language_scope.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_state.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/practice_evidence.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_controller.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/exercise_generator.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/features/review/domain/review_session.dart';
import 'package:parla_con_me/features/review/presentation/review_session_controller.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';

// Phase 12: the adaptive circuit, closed end to end from a REAL memory.
//
//   practice -> PracticeEvidence -> learning engine -> learning_memory
//     -> LearningState -> AdaptationStrategy -> conversation / scenario /
//     exercise -> new practice
//
// Each stage reads what the previous one really stored (nothing is built by
// hand), and the app is restarted in the middle.

const _profile = UserLearningProfile(
  level: LanguageLevel.b1,
  learningLanguage: AppLanguage.italian,
  goals: {LearningGoal.work},
  focusAreas: {LearningFocus.conversation},
  onboardingCompleted: true,
);

const _correction = Correction(
  original: 'Ieri ho andato al supermercato.',
  corrected: 'Ieri sono andato al supermercato.',
  explanation: 'Con "andare" si usa "essere".',
  category: CorrectionCategory.grammar,
);

/// One run of the app over [storage]. Booting again over the same storage is
/// restarting the app.
class _App {
  _App(this.storage, {bool correctFirstReply = true}) {
    var calls = 0;
    ai = FakeAIService(
      onRequest: (_) async {
        calls++;
        return Success(
          correctFirstReply && calls == 1
              ? const AIResponse(
                  message: 'Quasi! 😊',
                  corrections: [_correction],
                )
              : const AIResponse(message: 'Bene! E poi?'),
        );
      },
    );
    container = ProviderContainer(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(storage),
        aiServiceProvider.overrideWithValue(ai),
        userLearningProfileProvider.overrideWith(
          () => PreloadedUserLearningProfileController(_profile),
        ),
      ],
    );
  }

  final InMemoryLocalStorage storage;
  late final FakeAIService ai;
  late final ProviderContainer container;

  void dispose() => container.dispose();

  Future<ConversationController> conversation() async {
    container.read(conversationControllerProvider);
    while (container.read(conversationControllerProvider).status ==
        ConversationStatus.loading) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(conversationControllerProvider.notifier);
  }

  Future<void> say(ConversationController c, String text) async {
    await c.send(text);
    await pumpEventQueue();
  }

  /// The instruction the teacher received with the latest message.
  String get lastInstruction => ai.requests.last.systemInstruction!;

  Future<LearnerLearningSummary> summary() async =>
      ((await container.read(learningEngineProvider).summary()) as Success)
              .value
          as LearnerLearningSummary;

  Future<GrammarTopicProgress> topic() async => (await summary()).grammarTopics
      .firstWhere((t) => t.topic == GrammarTopic.essereVsAvere);

  Future<LearningContext> context() async =>
      ((await container.read(learningEngineProvider).learningContext())
                  as Success)
              .value
          as LearningContext;

  /// What every adaptive surface decides, from the memory as stored now.
  Future<_Surfaces> surfaces(DateTime day) async {
    final known = await summary();
    final scenario = const ScenarioGenerator().generate(
      date: day,
      profile: _profile,
      summary: known,
    );
    final exercise =
        (const DefaultExerciseGenerator(
                  learningLanguage: AppLanguage.italian,
                ).generate(
                  ReviewItem.discovered(
                    ReviewItemType.grammar,
                    scopedId('it', GrammarTopic.essereVsAvere.name),
                    day,
                  ),
                  known,
                )
                as Success<Exercise>)
            .value;
    return _Surfaces(
      state: (await topic()).learningState,
      strategies: (await context()).topicStrategies,
      scenarioPrompt: scenario.prompt,
      exercise: exercise,
    );
  }
}

class _Surfaces {
  const _Surfaces({
    required this.state,
    required this.strategies,
    required this.scenarioPrompt,
    required this.exercise,
  });

  final LearningState state;
  final Map<GrammarTopic, AdaptationStrategy> strategies;
  final String scenarioPrompt;
  final Exercise exercise;
}

const _simplifyLine = 'Keep these simple and guided';
const _keepLine = 'Keep the current difficulty';
const _stretchLine = 'Ask for more here';
const _scenarioSimplify = 'keep the demand low';
const _scenarioStretch = 'ask for more';

void main() {
  final day = DateTime.now();

  test('the whole circuit: WEAK -> IMPROVING -> CONSOLIDATED, the same '
      'strategy on every surface, across a restart, with the declared level '
      'untouched', () async {
    final storage = InMemoryLocalStorage();
    var app = _App(storage);
    addTearDown(() => app.dispose());
    var chat = await app.conversation();

    // ---- A. A mistake in conversation: WEAK -> SIMPLIFY everywhere. --------
    await app.say(chat, 'Ieri ho andato al supermercato.');
    var now = await app.surfaces(day);
    expect(now.state, LearningState.weak);
    expect(now.state.strategy, AdaptationStrategy.simplify);
    expect(
      now.strategies[GrammarTopic.essereVsAvere],
      AdaptationStrategy.simplify,
    );
    expect(now.scenarioPrompt, contains(_scenarioSimplify));
    expect(now.exercise.adaptation, AdaptationStrategy.simplify);
    expect(
      now.exercise.options,
      hasLength(DefaultExerciseGenerator.guidedOptions),
    );
    // And the teacher, on the very next message.
    await app.say(chat, 'Ieri sono andato al lavoro.');
    expect(app.lastInstruction, contains(_simplifyLine));
    expect(app.lastInstruction, isNot(contains(_stretchLine)));
    // Only the weak concept is simplified: the learner is still B1.
    expect(app.lastInstruction, contains('Level B1'));

    // ---- B. Production again: IMPROVING -> KEEP everywhere. ----------------
    await app.say(chat, 'Ieri sono andato a scuola.');
    now = await app.surfaces(day);
    expect(now.state, LearningState.improving);
    expect(now.state.strategy, AdaptationStrategy.keep);
    expect(now.strategies[GrammarTopic.essereVsAvere], AdaptationStrategy.keep);
    expect(now.scenarioPrompt, isNot(contains(_scenarioSimplify)));
    expect(now.scenarioPrompt, isNot(contains(_scenarioStretch)));
    expect(now.exercise.adaptation, AdaptationStrategy.keep);
    await app.say(chat, 'Ieri sono andato al cinema.');
    expect(app.lastInstruction, contains(_keepLine));
    expect(app.lastInstruction, isNot(contains(_simplifyLine)));
    expect(app.lastInstruction, isNot(contains(_stretchLine)));

    // Enough correct answers, but all in ONE conversation: still not more.
    var topic = await app.topic();
    expect(topic.proof.productionSuccesses, 3);
    expect(topic.proof.contexts, hasLength(1));
    expect(topic.learningState, LearningState.improving);

    // ---- C. Another conversation: CONSOLIDATED -> STRETCH everywhere. ------
    chat.startNewConversation();
    await app.say(chat, 'Ieri sono andato al mare.');
    now = await app.surfaces(day);
    expect(now.state, LearningState.consolidated);
    expect(now.state.strategy, AdaptationStrategy.stretch);
    expect(
      now.strategies[GrammarTopic.essereVsAvere],
      AdaptationStrategy.stretch,
    );
    expect(now.scenarioPrompt, contains(_scenarioStretch));
    expect(now.exercise.adaptation, AdaptationStrategy.stretch);
    await app.say(chat, 'Ieri sono andato in montagna.');
    expect(app.lastInstruction, contains(_stretchLine));
    expect(app.lastInstruction, isNot(contains(_simplifyLine)));

    // ---- F. The declared level never moved. --------------------------------
    expect(app.container.read(userLearningProfileProvider), _profile);
    expect(
      app.container.read(userLearningProfileProvider).level,
      LanguageLevel.b1,
    );
    for (final request in app.ai.requests) {
      expect(request.systemInstruction, contains('Level B1'));
    }
    expect(
      storage.data.keys.where((k) => k.contains('profile')),
      isEmpty,
      reason: 'nothing here ever writes the profile',
    );

    // ---- E. Restart: the same state, hint and surfaces. --------------------
    final before = now;
    final storedBefore = storage.data['learning_memory'];
    app.dispose();
    app = _App(storage, correctFirstReply: false);
    final after = await app.surfaces(day);
    expect(after.state, before.state);
    expect(after.strategies, before.strategies);
    expect(after.scenarioPrompt, before.scenarioPrompt);
    expect(after.exercise, before.exercise);
    topic = await app.topic();
    expect(topic.proof.contexts, hasLength(2));
    expect(topic.proof.productionSuccesses, 5);
    expect(storage.data['learning_memory'], storedBefore);
    // The next practice already uses it.
    chat = await app.conversation();
    await app.say(chat, 'Ieri sono andato a casa.');
    expect(app.lastInstruction, contains(_stretchLine));
    expect(app.lastInstruction, contains('Level B1'));
    expect(
      app.container.read(userLearningProfileProvider).level,
      LanguageLevel.b1,
    );
  });

  group('evidence', () {
    PracticeEvidence event(
      String id, {
      PracticeEvidenceType type = PracticeEvidenceType.production,
      PracticeEvidenceOutcome outcome = PracticeEvidenceOutcome.success,
      PracticeEvidenceSource source = PracticeEvidenceSource.review,
    }) => PracticeEvidence(
      eventId: id,
      source: source,
      type: type,
      outcome: outcome,
      learningLanguage: 'it',
      occurredAt: DateTime.utc(2026, 10, 7, 9),
      grammarTopic: GrammarTopic.essereVsAvere.name,
      contextId: 'review:2026-10-07',
    );

    Future<_App> weakApp() async {
      final storage = InMemoryLocalStorage();
      final app = _App(storage);
      addTearDown(app.dispose);
      final chat = await app.conversation();
      await app.say(chat, 'Ieri ho andato al supermercato.');
      return app;
    }

    test(
      'the same evidence twice: one effect, one proof, one revision',
      () async {
        final app = await weakApp();
        final recorder = app.container.read(practiceEvidenceRecorderProvider);
        final revision = app.container.read(learningRevisionProvider);

        await recorder.recordPracticeEvidence(event('review:x:attempt:1'));
        final once = app.storage.data['learning_memory'];
        final proven = (await app.topic()).proof;
        expect(app.container.read(learningRevisionProvider), revision + 1);

        await recorder.recordPracticeEvidence(event('review:x:attempt:1'));

        expect(app.storage.data['learning_memory'], once);
        expect((await app.topic()).proof, proven);
        expect(proven.productionSuccesses, 1);
        expect(
          app.container.read(learningRevisionProvider),
          revision + 1,
          reason: 'a repeated event is not a change of the memory',
        );
      },
    );

    test(
      'recognition and exposure never prove production, even in bulk',
      () async {
        final app = await weakApp();
        final recorder = app.container.read(practiceEvidenceRecorderProvider);
        for (var i = 0; i < 12; i++) {
          await recorder.recordPracticeEvidence(
            event('r$i', type: PracticeEvidenceType.recognition),
          );
          await recorder.recordPracticeEvidence(
            event('e$i', type: PracticeEvidenceType.exposure),
          );
        }
        final topic = await app.topic();
        expect(topic.proof.recognitionSuccesses, 12);
        expect(topic.proof.productionSuccesses, 0);
        expect(topic.proof.productionProven, isFalse);
        expect(topic.proof.contexts, isEmpty);
        expect(topic.learningState, LearningState.weak);
        expect(topic.learningState.strategy, AdaptationStrategy.simplify);
      },
    );

    test(
      'production does feed the state, and the state survives a restart',
      () async {
        final app = await weakApp();
        final recorder = app.container.read(practiceEvidenceRecorderProvider);
        await recorder.recordPracticeEvidence(event('p1'));
        await recorder.recordPracticeEvidence(event('p2'));
        expect((await app.topic()).learningState, LearningState.improving);

        final storage = app.storage;
        app.dispose();
        final restarted = _App(storage, correctFirstReply: false);
        addTearDown(restarted.dispose);
        final topic = await restarted.topic();
        expect(topic.proof.productionSuccesses, 2);
        expect(topic.learningState, LearningState.improving);
        expect(topic.learningState.strategy, AdaptationStrategy.keep);
      },
    );
  });

  group('review session', () {
    test(
      'typed answers prove production, picked options only recognition, '
      'and every answer that taught the memory moves the revision once',
      () async {
        final t0 = DateTime.utc(2026, 10, 6, 9);
        final storage = InMemoryLocalStorage();
        final seed = LocalLearningRepository(storage);
        for (var i = 0; i < 2; i++) {
          await seed.recordError(
            LearningError(
              id: 'ho andato -> sono andato',
              language: 'it',
              category: LearningErrorCategory.grammar,
              original: 'ho andato',
              corrected: 'sono andato',
              explanation: 'Usiamo "essere" con andare.',
              grammarTopic: GrammarTopic.essereVsAvere,
              firstSeenAt: t0,
              lastSeenAt: t0,
              confidence: 0.9,
            ),
          );
          await seed.recordGrammarTopicExposure(
            GrammarTopic.essereVsAvere,
            at: t0,
            wasError: true,
          );
        }
        final c = ProviderContainer(
          overrides: <Override>[
            localStorageProvider.overrideWithValue(storage),
            userLearningProfileProvider.overrideWith(
              () => PreloadedUserLearningProfileController(_profile),
            ),
            reviewSessionClockProvider.overrideWithValue(() => t0),
          ],
        );
        addTearDown(c.dispose);
        c.listen(learningRevisionProvider, (_, _) {});
        final revision = c.read(learningRevisionProvider);

        final session = c.read(reviewSessionControllerProvider.notifier);
        await session.start();
        var typed = 0;
        var picked = 0;
        while (c.read(reviewSessionControllerProvider).status ==
            ReviewSessionStatus.answering) {
          final exercise = c.read(reviewSessionControllerProvider).current!;
          exercise.isMultipleChoice ? picked++ : typed++;
          await session.submitAnswer(exercise.correctAnswer);
          session.continueSession();
        }

        expect(typed, greaterThan(0));
        expect(picked, greaterThan(0));
        final known =
            ((await LocalLearningRepository(storage).getLearningSummary())
                        as Success)
                    .value
                as LearnerLearningSummary;
        final topic = known.grammarTopics.single;
        expect(topic.proof.productionSuccesses, typed);
        expect(topic.proof.recognitionSuccesses, picked);
        expect(topic.proof.contexts, [
          'review:2026-10-06',
        ], reason: 'one day of review is one interaction');
        expect(c.read(learningRevisionProvider), revision + typed + picked);
      },
    );
  });
}
