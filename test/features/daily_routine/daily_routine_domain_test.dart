import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/daily_routine/domain/daily_routine.dart';
import 'package:parla_con_me/features/daily_routine/domain/scenario_generator.dart';
import 'package:parla_con_me/features/daily_routine/domain/scenario_mission.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_summary.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';

final _now = DateTime(2026, 10, 6, 10);

ScenarioMission _mission([String id = 'cafe:']) => ScenarioMission(
  id: id,
  situation: ScenarioSituation.cafe,
  learningLanguage: AppLanguage.italian,
  targetTopics: const [],
  prompt: 'Play it.',
);

DailyRoutine _routine({
  RoutineStepState review = RoutineStepState.pending,
  RoutineStepState speak = RoutineStepState.pending,
  RoutineStepState words = RoutineStepState.pending,
  AppLanguage language = AppLanguage.italian,
  String date = '2026-10-06',
}) => DailyRoutine(
  date: date,
  learningLanguage: language,
  step1: ReviewStep(
    state: review,
    itemIds: review == RoutineStepState.unavailable
        ? const []
        : const ['error:a'],
  ),
  step2: ScenarioStep(state: speak, mission: _mission()),
  step3: VocabularyStep(
    state: words,
    vocabularyIds: words == RoutineStepState.unavailable
        ? const []
        : const ['it:ciao'],
  ),
);

GrammarTopicProgress _weak(GrammarTopic topic, {int errors = 3}) =>
    GrammarTopicProgress(
      topic: topic,
      exposureCount: errors,
      errorCount: errors,
      lastSeenAt: _now,
    );

LearnerLearningSummary _summary(List<GrammarTopicProgress> topics) =>
    LearnerLearningSummary(grammarTopics: topics);

UserLearningProfile _profile({
  AppLanguage language = AppLanguage.italian,
  Set<LearningGoal> goals = const {LearningGoal.work},
}) => UserLearningProfile(
  learningLanguage: language,
  level: LanguageLevel.a2,
  goals: goals,
  focusAreas: const {LearningFocus.conversation},
  onboardingCompleted: true,
);

void main() {
  group('DailyRoutine: identity', () {
    test('a routine is one per day and language', () {
      final it = _routine();
      final en = _routine(language: AppLanguage.english);
      final tomorrow = _routine(date: '2026-10-07');
      expect(it.key, '2026-10-06|it');
      expect(en.key, '2026-10-06|en');
      expect({it.key, en.key, tomorrow.key}, hasLength(3));
      expect(DailyRoutine.keyFor('2026-10-06', AppLanguage.italian), it.key);
    });

    test('the date is the local calendar day, zero padded', () {
      expect(DailyRoutine.dateOf(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
      expect(DailyRoutine.dateOf(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('equal content is equal', () {
      expect(_routine(), _routine());
      expect(_routine().hashCode, _routine().hashCode);
      expect(_routine(), isNot(_routine(date: '2026-10-07')));
    });
  });

  group('DailyRoutine: status and completion', () {
    test('starts not started, and completing the steps in order finishes', () {
      var r = _routine();
      expect(r.status, RoutineStatus.notStarted);
      expect(r.currentStep, 1);
      expect(r.isComplete, isFalse);

      r = r.completeStep1()!;
      expect(r.status, RoutineStatus.step1Completed);
      expect(r.currentStep, 2);

      r = r.completeStep2()!;
      expect(r.status, RoutineStatus.step2Completed);
      expect(r.currentStep, 3);

      r = r.completeStep3()!;
      expect(r.status, RoutineStatus.completed);
      expect(r.currentStep, isNull);
      expect(r.isComplete, isTrue);
      expect(r.completedCount, 3);
      expect(r.availableCount, 3);
    });

    test('steps cannot be jumped or repeated', () {
      final fresh = _routine();
      expect(fresh.completeStep2(), isNull);
      expect(fresh.completeStep3(), isNull);
      expect(fresh.canComplete(0), isFalse);
      expect(fresh.canComplete(4), isFalse);

      final first = fresh.completeStep1()!;
      expect(first.completeStep1(), isNull, reason: 'already done');
      expect(first.completeStep3(), isNull, reason: 'step 2 first');

      final done = first.completeStep2()!.completeStep3()!;
      expect(done.completeStep1(), isNull);
      expect(done.completeStep2(), isNull);
      expect(done.completeStep3(), isNull);
    });

    test('completing never changes the rest of the routine', () {
      final r = _routine();
      final next = r.completeStep1()!;
      expect(next.step2, r.step2);
      expect(next.step3, r.step3);
      expect(next.date, r.date);
      expect(next.learningLanguage, r.learningLanguage);
      expect(next.step1.itemIds, r.step1.itemIds);
      expect(r.step1.state, RoutineStepState.pending, reason: 'immutable');
    });

    test('a step with nothing to practice is left out, not faked', () {
      var r = _routine(review: RoutineStepState.unavailable);
      expect(r.availableCount, 2);
      expect(r.completedCount, 0);
      expect(r.status, RoutineStatus.notStarted, reason: 'nothing done yet');
      expect(r.currentStep, 2, reason: 'goes straight to the next one');
      expect(r.canComplete(1), isFalse);
      expect(r.completeStep1(), isNull);

      r = r.completeStep2()!;
      expect(r.status, RoutineStatus.step2Completed);
      r = r.completeStep3()!;
      expect(r.status, RoutineStatus.completed);
      expect(r.completedCount, 2);
    });

    test('with no words, finishing the mission finishes the routine', () {
      final r = _routine(
        review: RoutineStepState.completed,
        words: RoutineStepState.unavailable,
      ).completeStep2()!;
      expect(r.isComplete, isTrue);
      expect(r.status, RoutineStatus.completed);
      expect(r.availableCount, 2);
    });

    test('a routine with nothing at all is not "completed"', () {
      final r = DailyRoutine(
        date: '2026-10-06',
        learningLanguage: AppLanguage.italian,
        step1: const ReviewStep(state: RoutineStepState.unavailable),
        step2: const ScenarioStep(state: RoutineStepState.unavailable),
        step3: const VocabularyStep(state: RoutineStepState.unavailable),
      );
      expect(r.isEmpty, isTrue);
      expect(r.status, RoutineStatus.notStarted);
      expect(r.currentStep, isNull);
    });

    test('completion records that it was done, not how it went', () {
      // The model has no field for correctness at all.
      final r = _routine().completeStep1()!;
      expect(r.step1.state, RoutineStepState.completed);
      expect(r.step1.itemIds, ['error:a']);
    });
  });

  group('ScenarioGenerator', () {
    const generator = ScenarioGenerator();

    ScenarioMission generate(
      LearnerLearningSummary summary, {
      DateTime? date,
      UserLearningProfile? profile,
    }) => generator.generate(
      date: date ?? _now,
      profile: profile ?? _profile(),
      summary: summary,
    );

    test('a weak topic leads to a situation that practices it', () {
      final m = generate(_summary([_weak(GrammarTopic.passatoProssimo)]));
      expect(m.situation, ScenarioSituation.yesterday);
      expect(m.targetTopics, [GrammarTopic.passatoProssimo]);
      expect(m.id, 'yesterday:passatoProssimo');
      expect(m.learningLanguage, AppLanguage.italian);
      expect(m.prompt, contains('SCENARIO MISSION'));
      expect(m.prompt, contains('Italian'));
      expect(m.prompt, contains('what they did yesterday'));
      expect(m.prompt, contains('passatoProssimo'));
      expect(m.minTurns, ScenarioMission.defaultMinTurns);
    });

    test('the most pressing topics come first, at most two', () {
      final m = generate(
        _summary([
          _weak(GrammarTopic.articles, errors: 1),
          _weak(GrammarTopic.prepositions, errors: 6),
          _weak(GrammarTopic.wordOrder, errors: 3),
        ]),
      );
      expect(m.targetTopics, [
        GrammarTopic.prepositions,
        GrammarTopic.wordOrder,
      ]);
      expect([
        ScenarioSituation.directions,
        ScenarioSituation.cafe,
      ], contains(m.situation));
    });

    test('topic names in the prompt come from the language rules', () {
      final m = generator.generate(
        date: _now,
        profile: _profile(),
        summary: _summary([_weak(GrammarTopic.articles)]),
        describeTopic: (t) => 'the ${t.name} of the language',
      );
      expect(m.prompt, contains('the articles of the language'));
    });

    test('same day and same state, same mission; the day rotates choices', () {
      final summary = _summary([_weak(GrammarTopic.prepositions)]);
      final a = generate(summary, date: DateTime(2026, 10, 6, 8));
      final b = generate(summary, date: DateTime(2026, 10, 6, 22));
      expect(a, b, reason: 'any time of the same day');

      final days = {
        for (var d = 0; d < 6; d++)
          generate(summary, date: DateTime(2026, 10, 6 + d)).situation,
      };
      expect(days, {ScenarioSituation.directions, ScenarioSituation.cafe});
    });

    test('with nothing weak the learner goals decide', () {
      expect(
        generate(
          LearnerLearningSummary.empty,
          profile: _profile(goals: {LearningGoal.work}),
        ).situation,
        ScenarioSituation.workday,
      );
      final abroad = generate(
        LearnerLearningSummary.empty,
        profile: _profile(goals: {LearningGoal.liveAbroad}),
      );
      expect(abroad.targetTopics, isEmpty);
      expect(abroad.id, endsWith(':'));
      expect(abroad.prompt, isNot(contains('Without announcing it')));
      expect([
        ScenarioSituation.directions,
        ScenarioSituation.shopping,
      ], contains(abroad.situation));
    });

    test('the goals are read in a fixed order, whatever the set holds', () {
      final one = generate(
        LearnerLearningSummary.empty,
        profile: _profile(
          goals: {LearningGoal.work, LearningGoal.speakConfidently},
        ),
      );
      final other = generate(
        LearnerLearningSummary.empty,
        profile: _profile(
          goals: {LearningGoal.speakConfidently, LearningGoal.work},
        ),
      );
      expect(one, other);
      expect(one.situation, ScenarioSituation.introduction);
    });

    test('with no goals either there is still a valid mission', () {
      final m = generate(
        LearnerLearningSummary.empty,
        profile: _profile(goals: const {}),
      );
      expect(m.situation, ScenarioSituation.introduction);
      expect(m.prompt, isNotEmpty);
    });

    test(
      'every topic has at least one situation, and every situation a text',
      () {
        for (final topic in GrammarTopic.values) {
          expect(
            ScenarioGenerator.situationsForTopic(topic),
            isNotEmpty,
            reason: topic.name,
          );
        }
        for (final s in ScenarioSituation.values) {
          expect(s.instruction, isNotEmpty, reason: s.name);
        }
      },
    );

    test('the language comes from the profile, never from a constant', () {
      final summary = _summary([_weak(GrammarTopic.articles)]);
      for (final language in supportedLearningLanguages) {
        final m = generate(summary, profile: _profile(language: language));
        expect(m.learningLanguage, language);
        expect(m.prompt, contains(language.englishName));
      }
    });
  });
}
