import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/presentation/conversation_controller.dart';
import 'package:parla_con_me/features/daily_routine/domain/scenario_generator.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/default_learning_engine.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/italian_learning_rules.dart';
import 'package:parla_con_me/features/learning/domain/learning_context_builder.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/learning/domain/learning_state.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/learning/domain/practice_evidence.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_controller.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/exercise_generator.dart';
import 'package:parla_con_me/features/review/domain/review_engine.dart';
import 'package:parla_con_me/features/review/domain/review_item.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';

// Phase 11B: the adaptive learning state, end to end.

final _now = DateTime.utc(2026, 10, 6, 9);
const _italian = ItalianLearningRules();

const _correction = Correction(
  original: 'Ieri ho andato al supermercato.',
  corrected: 'Ieri sono andato al supermercato.',
  explanation: 'Con "andare" si usa "essere".',
  category: CorrectionCategory.grammar,
);

LearningError _error(
  String original,
  String corrected, {
  GrammarTopic? topic = GrammarTopic.essereVsAvere,
  int frequency = 2,
}) => LearningError(
  id: '$original -> $corrected',
  language: 'it',
  category: LearningErrorCategory.grammar,
  original: original,
  corrected: corrected,
  explanation: 'Spiegazione.',
  grammarTopic: topic,
  frequency: frequency,
  firstSeenAt: _now,
  lastSeenAt: _now,
  confidence: 0.9,
);

PracticeProof _proof(
  int successes, {
  List<String> contexts = const ['a', 'b'],
}) {
  var proof = PracticeProof.empty;
  for (var i = 0; i < successes; i++) {
    proof = proof.record(
      type: PracticeEvidenceType.production,
      success: true,
      context: contexts[i % contexts.length],
    );
  }
  return proof;
}

GrammarTopicProgress _topic(
  GrammarTopic topic, {
  int errors = 2,
  PracticeProof proof = PracticeProof.empty,
}) => GrammarTopicProgress(
  topic: topic,
  exposureCount: errors,
  errorCount: errors,
  lastSeenAt: _now,
  proof: proof,
);

Future<LearnerLearningSummary> _memory(InMemoryLocalStorage storage) async =>
    ((await LocalLearningRepository(storage).getLearningSummary()) as Success)
            .value
        as LearnerLearningSummary;

GrammarTopicProgress _essere(LearnerLearningSummary s) =>
    s.grammarTopics.firstWhere((t) => t.topic == GrammarTopic.essereVsAvere);

void main() {
  group('conversation -> evidence -> learning engine -> state', () {
    ProviderContainer containerFor(
      InMemoryLocalStorage storage,
      FakeAIService ai, {
      UserLearningProfile? profile,
      Override? engine,
    }) {
      final c = ProviderContainer(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(storage),
          aiServiceProvider.overrideWithValue(ai),
          ?engine,
          if (profile != null)
            userLearningProfileProvider.overrideWith(
              () => PreloadedUserLearningProfileController(profile),
            ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<ConversationController> ready(ProviderContainer c) async {
      c.read(conversationControllerProvider);
      while (c.read(conversationControllerProvider).status ==
          ConversationStatus.loading) {
        await Future<void>.delayed(Duration.zero);
      }
      return c.read(conversationControllerProvider.notifier);
    }

    /// The first reply corrects the learner; the rest are plain.
    FakeAIService correctingOnce() {
      var calls = 0;
      return FakeAIService(
        onRequest: (_) async {
          calls++;
          return Success(
            calls == 1
                ? const AIResponse(
                    message: 'Quasi! 😊',
                    corrections: [_correction],
                  )
                : const AIResponse(message: 'Bene! E poi?'),
          );
        },
      );
    }

    test(
      'the conversation tells the engine which conversation it was',
      () async {
        final engine = RecordingLearningEngine();
        final c = containerFor(
          InMemoryLocalStorage(),
          correctingOnce(),
          engine: learningEngineProvider.overrideWithValue(engine),
        );
        final controller = await ready(c);
        await controller.send('Ieri ho andato al supermercato.');
        await pumpEventQueue();
        final id = c.read(conversationControllerProvider).conversation.id;
        expect(engine.contexts, ['conversation:$id']);
      },
    );

    test(
      'an error, then correct use: WEAK -> IMPROVING; several in the same '
      'conversation are one context; a new conversation can consolidate',
      () async {
        final storage = InMemoryLocalStorage();
        final c = containerFor(storage, correctingOnce());
        final controller = await ready(c);

        await controller.send('Ieri ho andato al supermercato.');
        await pumpEventQueue();
        var topic = _essere(await _memory(storage));
        expect(topic.proof.productionFailures, 1);
        expect(topic.learningState, LearningState.weak);

        await controller.send('Ieri sono andato al lavoro.');
        await pumpEventQueue();
        topic = _essere(await _memory(storage));
        expect(
          topic.learningState,
          LearningState.weak,
          reason: 'one is not enough',
        );

        await controller.send('Ieri sono andato a scuola.');
        await pumpEventQueue();
        topic = _essere(await _memory(storage));
        expect(topic.learningState, LearningState.improving);

        await controller.send('Ieri sono andato al cinema.');
        await pumpEventQueue();
        topic = _essere(await _memory(storage));
        expect(topic.proof.productionSuccesses, 3);
        expect(topic.proof.contexts, hasLength(1));
        expect(
          topic.learningState,
          LearningState.improving,
          reason: 'three correct answers in one conversation are one context',
        );

        controller.startNewConversation();
        await controller.send('Ieri sono andato al mare.');
        await pumpEventQueue();
        topic = _essere(await _memory(storage));
        expect(topic.proof.contexts, hasLength(2));
        expect(topic.learningState, LearningState.consolidated);
        expect(topic.learningState.strategy, AdaptationStrategy.stretch);
      },
    );

    test('the learner\'s declared level is never touched', () async {
      final storage = InMemoryLocalStorage();
      const profile = UserLearningProfile(
        level: LanguageLevel.b1,
        goals: {LearningGoal.work},
        focusAreas: {LearningFocus.grammar},
        onboardingCompleted: true,
      );
      final c = containerFor(storage, correctingOnce(), profile: profile);
      final controller = await ready(c);
      await controller.send('Ieri ho andato al supermercato.');
      await pumpEventQueue();
      for (final text in [
        'Ieri sono andato al lavoro.',
        'Ieri sono andato a scuola.',
      ]) {
        await controller.send(text);
        await pumpEventQueue();
      }
      controller.startNewConversation();
      await controller.send('Ieri sono andato al mare.');
      await pumpEventQueue();

      expect(
        _essere(await _memory(storage)).learningState,
        LearningState.consolidated,
      );
      expect(c.read(userLearningProfileProvider), profile);
      expect(c.read(userLearningProfileProvider).level, LanguageLevel.b1);
      expect(
        storage.data.keys.where((k) => k.contains('profile')),
        isEmpty,
        reason: 'the adaptive state never writes the profile',
      );
    });
  });

  group('review -> practice evidence -> learning engine -> state', () {
    late InMemoryLocalStorage storage;
    late LocalLearningRepository repo;
    late DefaultLearningEngine learning;
    late DefaultReviewEngine reviews;

    Future<void> seed() async {
      for (var i = 0; i < 2; i++) {
        await repo.recordError(_error('ho andato', 'sono andato'));
        await repo.recordGrammarTopicExposure(
          GrammarTopic.essereVsAvere,
          at: _now,
          wasError: true,
        );
      }
    }

    setUp(() async {
      storage = InMemoryLocalStorage();
      repo = LocalLearningRepository(storage);
      learning = DefaultLearningEngine(
        repo,
        rules: _italian,
        clock: () => _now,
      );
      reviews = DefaultReviewEngine(
        repo,
        LocalReviewRepository(storage),
        learningLanguage: AppLanguage.italian,
        evidence: learning,
      );
      await seed();
    });

    Future<ReviewItem> item(ReviewItemType type) async {
      final queue =
          ((await reviews.getReviewQueue(now: _now, limit: 50)) as Success)
                  .value
              as List<ReviewItem>;
      return queue.firstWhere((i) => i.type == type);
    }

    Future<void> answer(
      ReviewItem item,
      ExerciseType exercise,
      DateTime at, {
      bool correct = true,
    }) async {
      await reviews.recordReviewResult(
        itemId: item.id,
        result: correct ? ReviewResult.success : ReviewResult.failure,
        now: at,
        exercise: exercise,
      );
    }

    Future<GrammarTopicProgress> topic() async =>
        _essere(await _memory(storage));

    test('the starting point: a topic with known mistakes is WEAK', () async {
      expect((await topic()).learningState, LearningState.weak);
    });

    test('typed answers (production) on different days climb WEAK -> '
        'IMPROVING -> CONSOLIDATED', () async {
      final error = await item(ReviewItemType.error);
      final day = DateTime.utc(2026, 10, 7, 9);

      await answer(error, ExerciseType.errorCorrection, day);
      expect((await topic()).learningState, LearningState.weak);

      await answer(
        error,
        ExerciseType.errorCorrection,
        day.add(const Duration(days: 2)),
      );
      expect((await topic()).learningState, LearningState.improving);

      await answer(
        error,
        ExerciseType.errorCorrection,
        day.add(const Duration(days: 8)),
      );
      final t = await topic();
      expect(t.proof.productionSuccesses, 3);
      expect(t.proof.contexts, hasLength(3));
      expect(t.learningState, LearningState.consolidated);
    });

    test('three typed answers the same day are one context', () async {
      final error = await item(ReviewItemType.error);
      final day = DateTime.utc(2026, 10, 7, 9);
      for (var i = 0; i < 3; i++) {
        await answer(
          error,
          ExerciseType.errorCorrection,
          day.add(Duration(minutes: i * 20)),
        );
      }
      final t = await topic();
      expect(t.proof.productionSuccesses, 3);
      expect(t.proof.contexts, ['review:2026-10-07']);
      expect(t.learningState, LearningState.improving);
    });

    test('a wrong typed answer is recorded as a failed production', () async {
      final error = await item(ReviewItemType.error);
      await answer(
        error,
        ExerciseType.errorCorrection,
        DateTime.utc(2026, 10, 7, 9),
        correct: false,
      );
      final t = await topic();
      expect(t.proof.productionFailures, 1);
      expect(t.proof.recent, [false]);
      expect(t.learningState, LearningState.weak);
    });

    test('picking the right option, again and again, proves nothing: the '
        'schedule may call it mastered, the state stays WEAK', () async {
      final grammar = await item(ReviewItemType.grammar);
      var day = DateTime.utc(2026, 10, 7, 9);
      for (var i = 0; i < 6; i++) {
        await answer(grammar, ExerciseType.grammarChoice, day);
        day = day.add(const Duration(days: 10));
      }
      final items =
          ((await reviews.synchronize(now: day)) as Success).value
              as List<ReviewItem>;
      final last = items.firstWhere((i) => i.id == grammar.id);
      expect(last.status, ReviewStatus.mastered);

      final t = await topic();
      expect(t.proof.recognitionSuccesses, 6);
      expect(t.proof.productionSuccesses, 0);
      expect(t.proof.productionProven, isFalse);
      expect(t.proof.contexts, isEmpty);
      expect(t.learningState, LearningState.weak);
    });

    test(
      'recognition can not complete what production has not started',
      () async {
        final error = await item(ReviewItemType.error);
        final grammar = await item(ReviewItemType.grammar);
        var day = DateTime.utc(2026, 10, 7, 9);
        await answer(error, ExerciseType.errorCorrection, day);
        for (var i = 0; i < 8; i++) {
          day = day.add(const Duration(days: 3));
          await answer(grammar, ExerciseType.grammarChoice, day);
        }
        final t = await topic();
        expect(t.proof.productionSuccesses, 1);
        expect(t.learningState, isNot(LearningState.consolidated));
        expect(t.learningState, isNot(LearningState.improving));
      },
    );

    test(
      'the same review event, delivered twice, enters the ledger once',
      () async {
        final event = PracticeEvidence(
          eventId: 'review:error:x:attempt:1',
          source: PracticeEvidenceSource.review,
          type: PracticeEvidenceType.production,
          outcome: PracticeEvidenceOutcome.success,
          learningLanguage: 'it',
          occurredAt: _now,
          grammarTopic: GrammarTopic.essereVsAvere.name,
          contextId: 'review:2026-10-07',
        );
        await learning.recordPracticeEvidence(event);
        final once = storage.data['learning_memory'];
        await learning.recordPracticeEvidence(event);
        await LearningRestart(storage).replay(event);

        expect(storage.data['learning_memory'], once);
        expect((await topic()).proof.productionSuccesses, 1);
      },
    );

    test(
      'the ledger is stored with the topic and survives a restart',
      () async {
        final error = await item(ReviewItemType.error);
        await answer(
          error,
          ExerciseType.errorCorrection,
          DateTime.utc(2026, 10, 7, 9),
        );
        final before = await topic();
        final after = _essere(await _memory(storage));
        expect(after.proof, before.proof);
        expect(after.proof.productionSuccesses, 1);
      },
    );

    test('memory written before the ledger existed still reads, and a topic '
        'with mistakes is WEAK', () async {
      final fresh = InMemoryLocalStorage();
      await seedLegacy(fresh);
      final t = _essere(await _memory(fresh));
      expect(t.proof, PracticeProof.empty);
      expect(t.learningState, LearningState.weak);
    });
  });

  group('adaptation per concept, not per learner', () {
    const b1 = UserLearningProfile(
      level: LanguageLevel.b1,
      goals: {LearningGoal.work},
      focusAreas: {LearningFocus.conversation},
      onboardingCompleted: true,
    );

    // The example of the spec: one learner, four concepts, four states.
    final summary = LearnerLearningSummary(
      grammarTopics: [
        _topic(GrammarTopic.articles, errors: 0, proof: _proof(3)),
        _topic(GrammarTopic.passatoProssimo, proof: _proof(2)),
        _topic(GrammarTopic.pronouns),
        GrammarTopicProgress(topic: GrammarTopic.wordOrder),
      ],
    );

    test('consolidated -> STRETCH, improving -> KEEP, weak -> SIMPLIFY, new '
        '-> KEEP', () {
      final state = {
        for (final t in summary.grammarTopics) t.topic: t.learningState,
      };
      expect(state, {
        GrammarTopic.articles: LearningState.consolidated,
        GrammarTopic.passatoProssimo: LearningState.improving,
        GrammarTopic.pronouns: LearningState.weak,
        GrammarTopic.wordOrder: LearningState.newConcept,
      });
      expect(
        {for (final e in state.entries) e.key: e.value.strategy},
        {
          GrammarTopic.articles: AdaptationStrategy.stretch,
          GrammarTopic.passatoProssimo: AdaptationStrategy.keep,
          GrammarTopic.pronouns: AdaptationStrategy.simplify,
          GrammarTopic.wordOrder: AdaptationStrategy.keep,
        },
      );
    });

    test('the teacher gets the strategy of each concept and the level stays '
        'the declared one', () {
      final context = buildLearningContext(summary, now: _now, language: 'it');
      expect(context.topicStrategies, {
        GrammarTopic.pronouns: AdaptationStrategy.simplify,
        GrammarTopic.passatoProssimo: AdaptationStrategy.keep,
        GrammarTopic.articles: AdaptationStrategy.stretch,
      });

      final instruction = buildTeacherInstruction(
        profile: b1,
        correctionMode: false,
        learningContext: context,
      );
      String named(GrammarTopic t) => _italian.describeTopic(t);
      expect(instruction, contains('Keep these simple and guided'));
      expect(instruction, contains(named(GrammarTopic.pronouns)));
      expect(instruction, contains('Keep the current difficulty'));
      expect(instruction, contains('Ask for more here'));
      expect(instruction, contains(named(GrammarTopic.articles)));
      // The overall level is the declared one, and it is not rewritten.
      expect(instruction, contains('Level B1'));
      expect(instruction, isNot(contains('Level A2')));
      expect(instruction, isNot(contains('Level B2')));
      expect(instruction, contains('overall level above does not change'));
    });

    test('each line of the prompt names only the topics of its strategy', () {
      final context = buildLearningContext(summary, now: _now, language: 'it');
      final lines = buildTeacherInstruction(
        profile: b1,
        correctionMode: false,
        learningContext: context,
      ).split('\n');
      String lineWith(String start) =>
          lines.firstWhere((l) => l.contains(start));
      final simplify = lineWith('Keep these simple and guided');
      final stretch = lineWith('Ask for more here');
      expect(simplify, contains(_italian.describeTopic(GrammarTopic.pronouns)));
      expect(
        simplify,
        isNot(contains(_italian.describeTopic(GrammarTopic.articles))),
      );
      expect(stretch, contains(_italian.describeTopic(GrammarTopic.articles)));
      expect(
        stretch,
        isNot(contains(_italian.describeTopic(GrammarTopic.pronouns))),
      );
    });

    test('words the learner already produces well are offered for new '
        'contexts', () {
      final word = UserVocabularyHelper.consolidated('conto');
      final context = buildLearningContext(
        LearnerLearningSummary(vocabularyItems: [word]),
        now: _now,
        language: 'it',
      );
      expect(context.stretchWords, ['conto']);
      expect(context.isEmpty, isFalse);
      expect(
        buildTeacherInstruction(
          profile: b1,
          correctionMode: false,
          learningContext: context,
        ),
        contains('use them in new, richer contexts: conto'),
      );
    });

    test('nothing to adapt, nothing added: the prompt is as before', () {
      final empty = buildTeacherInstruction(
        profile: b1,
        correctionMode: false,
        learningContext: buildLearningContext(
          LearnerLearningSummary.empty,
          now: _now,
          language: 'it',
        ),
      );
      expect(empty, isNot(contains('Difficulty by area')));
    });

    test('a scenario lowers the demand on the weak topic only, and raises it '
        'where the learner is consolidated; the scene is the same', () {
      const generator = ScenarioGenerator();
      final weakOnly = LearnerLearningSummary(
        grammarTopics: [_topic(GrammarTopic.pronouns)],
      );
      final mixed = LearnerLearningSummary(
        grammarTopics: [
          _topic(GrammarTopic.pronouns),
          _topic(GrammarTopic.articles, errors: 0, proof: _proof(3)),
        ],
      );
      final a = generator.generate(date: _now, profile: b1, summary: weakOnly);
      final b = generator.generate(date: _now, profile: b1, summary: mixed);

      expect(a.situation, b.situation);
      expect(a.id, b.id, reason: 'the scene and its topics are the same');
      expect(a.targetTopics, [GrammarTopic.pronouns]);
      expect(a.prompt, contains('keep the demand low'));
      expect(a.prompt, contains('without simplifying the rest'));
      expect(a.prompt, isNot(contains('ask for more')));
      expect(b.prompt, contains('keep the demand low'));
      expect(b.prompt, contains('ask for more'));
      expect(b.prompt, contains("learner's level"));
      expect(b1.level, LanguageLevel.b1);
    });

    test('a scenario with no weak topic is not simplified', () {
      final calm = const ScenarioGenerator().generate(
        date: _now,
        profile: b1,
        summary: LearnerLearningSummary(
          grammarTopics: [
            _topic(GrammarTopic.passatoProssimo, proof: _proof(2)),
          ],
        ),
      );
      expect(calm.prompt, isNot(contains('keep the demand low')));
    });
  });

  group('exercises', () {
    const generator = DefaultExerciseGenerator(
      learningLanguage: AppLanguage.italian,
    );
    final errors = [
      _error('a0', 'b0', topic: GrammarTopic.articles, frequency: 9),
      _error('a1', 'b1', topic: GrammarTopic.articles, frequency: 8),
      _error('a2', 'b2', topic: GrammarTopic.articles, frequency: 7),
    ];

    Exercise choiceFor(GrammarTopicProgress t) {
      final item = ReviewItem.discovered(
        ReviewItemType.grammar,
        'articles',
        _now,
      );
      final result = generator.generate(
        item,
        LearnerLearningSummary(errors: errors, grammarTopics: [t]),
      );
      return (result as Success<Exercise>).value;
    }

    test('weak: guided (the right form against the mistake), still only '
        'recognition', () {
      final e = choiceFor(_topic(GrammarTopic.articles));
      expect(e.adaptation, AdaptationStrategy.simplify);
      expect(e.options, ['a0', 'b0']);
      expect(e.correctAnswer, 'b0');
      expect(e.type.practiceType, PracticeEvidenceType.recognition);
    });

    test('improving: the usual practice', () {
      final e = choiceFor(_topic(GrammarTopic.articles, proof: _proof(2)));
      expect(e.adaptation, AdaptationStrategy.keep);
      expect(e.options, hasLength(DefaultExerciseGenerator.maxOptions));
    });

    test('consolidated: the full challenge, never fewer options', () {
      final e = choiceFor(
        _topic(GrammarTopic.articles, errors: 2, proof: _proof(3)),
      );
      expect(e.adaptation, AdaptationStrategy.stretch);
      expect(e.options, hasLength(DefaultExerciseGenerator.maxOptions));
    });

    test('every exercise says what it proves: only typing is production', () {
      expect(
        ExerciseType.errorCorrection.practiceType,
        PracticeEvidenceType.production,
      );
      expect(
        ExerciseType.vocabularyContext.practiceType,
        PracticeEvidenceType.production,
      );
      expect(
        ExerciseType.grammarChoice.practiceType,
        PracticeEvidenceType.recognition,
      );
      // And a guided choice does not change that.
      expect(
        choiceFor(_topic(GrammarTopic.articles)).type.practiceType,
        PracticeEvidenceType.recognition,
      );
    });
  });

  group('architecture', () {
    List<File> libFiles() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    String norm(File f) => f.path.replaceAll('\\', '/');

    test('the ledger is written only by the two concept models, through the '
        'repository\'s evidence path', () {
      final writers = [
        for (final f in libFiles())
          if (f.readAsStringSync().contains('proof.record(')) norm(f),
      ]..sort();
      expect(writers, [
        'lib/features/learning/domain/grammar_topic.dart',
        'lib/features/learning/domain/user_vocabulary.dart',
      ]);
    });

    test('nothing outside learning knows the ledger', () {
      final knowers = [
        for (final f in libFiles())
          if (f.readAsStringSync().contains('PracticeProof') &&
              !norm(f).startsWith('lib/features/learning/'))
            norm(f),
      ];
      expect(knowers, isEmpty);
    });

    test('the state never looks at the declared level', () {
      for (final path in [
        'lib/features/learning/domain/learning_state.dart',
        'lib/features/learning/domain/learning_context_builder.dart',
        'lib/features/learning/domain/learning_context.dart',
      ]) {
        final s = File(path).readAsStringSync();
        expect(s, isNot(contains('LanguageLevel')), reason: path);
        expect(s, isNot(contains('profile/')), reason: '$path imports it');
      }
    });

    test('controllers still do not write the learning memory', () {
      for (final f in libFiles()) {
        final path = norm(f);
        if (!path.contains('/presentation/')) continue;
        if (path.endsWith('learning_providers.dart')) continue;
        final s = f.readAsStringSync();
        for (final write in [
          '.applyPracticeEvidence(',
          '.recordError(',
          '.recordVocabulary(',
          '.recordGrammarTopicExposure(',
        ]) {
          expect(s, isNot(contains(write)), reason: '$path $write');
        }
      }
    });
  });
}

/// A word the learner already produces well.
abstract final class UserVocabularyHelper {
  static UserVocabulary consolidated(String word) {
    var v = UserVocabulary.of(word: word, at: _now);
    for (final c in ['a', 'b', 'b']) {
      v = v.practice(
        at: _now,
        success: true,
        evidenceType: PracticeEvidenceType.production,
        context: c,
      );
    }
    return v;
  }
}

/// "The app was restarted": a new engine over the same storage.
class LearningRestart {
  LearningRestart(this.storage);
  final InMemoryLocalStorage storage;

  Future<void> replay(PracticeEvidence event) async {
    final engine = DefaultLearningEngine(
      LocalLearningRepository(storage),
      rules: _italian,
    );
    await engine.recordPracticeEvidence(event);
  }
}

/// Memory as it was written before the ledger: counts only.
Future<void> seedLegacy(InMemoryLocalStorage storage) async {
  storage.data['learning_memory'] =
      '{"version":1,"errors":[],"vocabulary":[],'
      '"grammarTopics":[{"topic":"essereVsAvere","language":"it",'
      '"exposureCount":3,"errorCount":2,"successfulUseCount":1,'
      '"lastSeenAt":"2026-10-06T09:00:00.000Z"}]}';
}
