import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine.dart';
import 'package:parla_con_me/features/daily_routine/domain/scenario_mission.dart';
import 'package:parla_con_me/features/guidance/domain/learning_guidance.dart';
import 'package:parla_con_me/features/guidance/domain/learning_guidance_resolver.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';

const _resolver = LearningGuidanceResolver();

DailyRoutine _routine({
  RoutineStepState review = RoutineStepState.pending,
  RoutineStepState speak = RoutineStepState.pending,
  RoutineStepState words = RoutineStepState.pending,
  int reviewCount = 3,
  int wordCount = 2,
  List<GrammarTopic> topics = const [],
  AppLanguage language = AppLanguage.italian,
}) => DailyRoutine(
  date: '2026-10-06',
  learningLanguage: language,
  step1: ReviewStep(
    state: review,
    itemIds: [for (var i = 0; i < reviewCount; i++) 'error:$i'],
  ),
  step2: ScenarioStep(
    state: speak,
    mission: ScenarioMission(
      id: 'cafe:',
      situation: ScenarioSituation.cafe,
      learningLanguage: language,
      targetTopics: topics,
      prompt: 'Play it.',
    ),
  ),
  step3: VocabularyStep(
    state: words,
    vocabularyIds: [for (var i = 0; i < wordCount; i++) 'w:$i'],
  ),
);

void main() {
  test('review pending: step 1 with the routine\'s own review count', () {
    final g = _resolver.resolve(_routine());
    expect(
      g,
      const LearningGuidance(
        kind: GuidanceKind.review,
        step: 1,
        reason: ReviewsDue(3),
      ),
    );
  });

  test('talk with topics: the first topic of the mission, not re-ranked', () {
    final g = _resolver.resolve(
      _routine(
        review: RoutineStepState.completed,
        topics: const [GrammarTopic.articles, GrammarTopic.plural],
      ),
      goals: const {LearningGoal.work},
    );
    expect(g?.kind, GuidanceKind.talk);
    expect(g?.step, 2);
    expect(g?.reason, const RepeatedDifficulty(GrammarTopic.articles));
  });

  test('talk without topics: the goal, in declaration order', () {
    final g = _resolver.resolve(
      _routine(review: RoutineStepState.completed),
      goals: const {LearningGoal.study, LearningGoal.writeBetter},
    );
    expect(g?.kind, GuidanceKind.talk);
    expect(g?.reason, const MatchesGoal(LearningGoal.writeBetter));
  });

  test('talk without topics or goals: a generic reason, nothing made up', () {
    final g = _resolver.resolve(_routine(review: RoutineStepState.completed));
    expect(g?.reason, const GenericMission());
  });

  test('vocabulary: step 3 with the routine\'s own word count', () {
    final g = _resolver.resolve(
      _routine(
        review: RoutineStepState.completed,
        speak: RoutineStepState.completed,
      ),
    );
    expect(
      g,
      const LearningGuidance(
        kind: GuidanceKind.vocabulary,
        step: 3,
        reason: WordsToReinforce(2),
      ),
    );
  });

  test('no meaningful routine: no guidance', () {
    final g = _resolver.resolve(
      _routine(
        review: RoutineStepState.unavailable,
        speak: RoutineStepState.unavailable,
        words: RoutineStepState.unavailable,
      ),
    );
    expect(g, isNull);
  });

  test('completed routine: RoutineDone', () {
    final g = _resolver.resolve(
      _routine(
        review: RoutineStepState.completed,
        speak: RoutineStepState.completed,
        words: RoutineStepState.completed,
      ),
    );
    expect(g?.kind, GuidanceKind.completed);
    expect(g?.step, isNull);
    expect(g?.reason, const RoutineDone());
  });

  test('it follows currentStep, skipping steps left out', () {
    // Nothing to review: the routine's current step is 2 even though step 3
    // also has words.
    final routine = _routine(review: RoutineStepState.unavailable);
    expect(routine.currentStep, 2);
    expect(_resolver.resolve(routine)?.kind, GuidanceKind.talk);

    // Review done, speaking left out of nothing: step 2 stays next.
    final inProgress = _routine(review: RoutineStepState.completed);
    expect(_resolver.resolve(inProgress)?.step, inProgress.currentStep);
  });

  test('it is deterministic', () {
    final routine = _routine(topics: const [GrammarTopic.articles]);
    expect(
      _resolver.resolve(routine, goals: const {LearningGoal.work}),
      _resolver.resolve(routine, goals: const {LearningGoal.work}),
    );
    final talk = _routine(review: RoutineStepState.completed);
    expect(
      _resolver.resolve(talk, goals: const {LearningGoal.work}),
      _resolver.resolve(talk, goals: const {LearningGoal.work}),
    );
  });

  test('each routine is explained from its own data only', () {
    final italian = _routine(reviewCount: 3);
    final spanish = _routine(reviewCount: 1, language: AppLanguage.spanish);
    expect(_resolver.resolve(italian)?.reason, const ReviewsDue(3));
    expect(_resolver.resolve(spanish)?.reason, const ReviewsDue(1));
  });

  test('topic order is the mission\'s order', () {
    final a = _routine(
      review: RoutineStepState.completed,
      topics: const [GrammarTopic.plural, GrammarTopic.articles],
    );
    final b = _routine(
      review: RoutineStepState.completed,
      topics: const [GrammarTopic.articles, GrammarTopic.plural],
    );
    expect(
      _resolver.resolve(a)?.reason,
      const RepeatedDifficulty(GrammarTopic.plural),
    );
    expect(
      _resolver.resolve(b)?.reason,
      const RepeatedDifficulty(GrammarTopic.articles),
    );
  });
}
