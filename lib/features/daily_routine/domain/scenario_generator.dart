import '../../learning/domain/grammar_topic.dart';
import '../../learning/domain/learning_context_builder.dart';
import '../../learning/domain/learning_state.dart';
import '../../learning/domain/learning_summary.dart';
import '../../profile/domain/user_learning_profile.dart';
import 'scenario_mission.dart';

/// Turns what is already known about the learner into a speaking situation.
/// A pure function: no AI, no storage, no randomness. It reuses the selection
/// the learning memory already defines (`selectTopicsToReinforce`) and the
/// learner's declared goals; it detects and writes nothing.
///
/// Same day, language and learning state: same mission. The day only rotates
/// between equally good situations, so the practice varies from day to day.
class ScenarioGenerator {
  const ScenarioGenerator();

  /// Most topics a mission names to the teacher.
  static const maxTopics = 2;

  ScenarioMission generate({
    required DateTime date,
    required UserLearningProfile profile,
    required LearnerLearningSummary summary,
    String Function(GrammarTopic)? describeTopic,
  }) {
    final language = profile.learningLanguage;
    final describe = describeTopic ?? (GrammarTopic t) => t.name;
    final day = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(1970)).inDays;

    final weak = [
      for (final t in selectTopicsToReinforce(summary, date).take(maxTopics))
        t.topic,
    ];
    final candidates = weak.isNotEmpty
        ? situationsForTopic(weak.first)
        : _situationsForGoals(profile.goals);
    final situation = candidates[day % candidates.length];

    final prompt = StringBuffer(
      "SCENARIO MISSION (today's guided speaking practice, in "
      '${language.englishName}). ${situation.instruction} '
      'Begin by setting the scene in one or two short sentences and saying '
      'your first line as the other person; then play the situation out '
      'naturally with the learner. Keep it realistic, short and at the '
      "learner's level, and stay in the situation.",
    );
    if (weak.isNotEmpty) {
      prompt.write(
        ' Without announcing it, give the learner chances to use: '
        '${weak.map(describe).join('; ')}.',
      );
    }
    // The difficulty is adapted per topic, never for the whole scene: the
    // situation stays at the learner's level, and only the demand on a weak
    // topic is lowered or on a consolidated one raised.
    final strategies = selectTopicStrategies(summary, weak);
    List<String> topicsFor(AdaptationStrategy strategy) => [
      for (final entry in strategies.entries)
        if (entry.value == strategy) describe(entry.key),
    ];
    final simplify = topicsFor(AdaptationStrategy.simplify);
    if (simplify.isNotEmpty) {
      prompt.write(
        ' For ${simplify.join('; ')}: keep the demand low, with short, guided '
        'turns and supportive wording, without simplifying the rest of the '
        'situation.',
      );
    }
    final stretch = topicsFor(AdaptationStrategy.stretch);
    if (stretch.isNotEmpty) {
      prompt.write(
        ' The learner already handles ${stretch.join('; ')} well: if it fits '
        'the situation, ask for more there (less guided, more spontaneous).',
      );
    }
    return ScenarioMission(
      id: '${situation.name}:${weak.map((t) => t.name).join('+')}',
      situation: situation,
      learningLanguage: language,
      targetTopics: weak,
      prompt: prompt.toString(),
    );
  }

  /// The situations that give a chance to use [topic], in a fixed order.
  static List<ScenarioSituation> situationsForTopic(GrammarTopic topic) =>
      switch (topic) {
        GrammarTopic.passatoProssimo ||
        GrammarTopic.essereVsAvere ||
        GrammarTopic.etreVsAvoir ||
        GrammarTopic.pastSimple ||
        GrammarTopic.presentPerfect ||
        GrammarTopic.passeCompose ||
        GrammarTopic.habenVsSein ||
        GrammarTopic.perfekt ||
        GrammarTopic.aspectParticles => const [ScenarioSituation.yesterday],
        GrammarTopic.prepositions ||
        GrammarTopic.porVsPara ||
        GrammarTopic.cases => const [
          ScenarioSituation.directions,
          ScenarioSituation.cafe,
        ],
        GrammarTopic.articles ||
        GrammarTopic.gender ||
        GrammarTopic.plural ||
        GrammarTopic.agreement ||
        GrammarTopic.measureWords => const [
          ScenarioSituation.shopping,
          ScenarioSituation.describing,
        ],
        GrammarTopic.verbConjugation ||
        GrammarTopic.thirdPersonSingular ||
        GrammarTopic.presentContinuous => const [
          ScenarioSituation.workday,
          ScenarioSituation.introduction,
        ],
        GrammarTopic.serVsEstar || GrammarTopic.toBe => const [
          ScenarioSituation.describing,
          ScenarioSituation.introduction,
        ],
        GrammarTopic.pronouns ||
        GrammarTopic.negation ||
        GrammarTopic.wordOrder ||
        GrammarTopic.structuralParticles => const [
          ScenarioSituation.cafe,
          ScenarioSituation.plans,
          ScenarioSituation.workday,
        ],
      };

  /// With nothing to reinforce yet, the learner's own goals decide (in the
  /// order the goals are defined, so the result never depends on a set's
  /// iteration order).
  static List<ScenarioSituation> _situationsForGoals(Set<LearningGoal> goals) {
    for (final goal in LearningGoal.values) {
      if (!goals.contains(goal)) continue;
      return switch (goal) {
        LearningGoal.speakConfidently ||
        LearningGoal.everything => const [ScenarioSituation.introduction],
        LearningGoal.understandListening => const [ScenarioSituation.cafe],
        LearningGoal.writeBetter ||
        LearningGoal.study => const [ScenarioSituation.plans],
        LearningGoal.liveAbroad => const [
          ScenarioSituation.directions,
          ScenarioSituation.shopping,
        ],
        LearningGoal.work => const [ScenarioSituation.workday],
      };
    }
    return const [ScenarioSituation.introduction];
  }
}
