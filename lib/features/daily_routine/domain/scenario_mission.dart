import '../../learning/domain/grammar_topic.dart';
import '../../profile/domain/language_pair.dart';

/// A real-life situation the learner can practice speaking about. Language
/// neutral: the situation is described to the teacher, who plays it in the
/// language being learned; its title and description are interface copy.
enum ScenarioSituation {
  introduction,
  yesterday,
  workday,
  cafe,
  directions,
  shopping,
  describing,
  plans;

  /// What the teacher is told about the situation (English, for the AI).
  String get instruction => switch (this) {
    introduction =>
      'The learner meets you for the first time at a social event: you both '
          'introduce yourselves and talk about where you live, your work or '
          'study and your interests.',
    yesterday =>
      'You are a friend who asks the learner what they did yesterday: where '
          'they went, who they saw, what they ate and how it went.',
    workday =>
      'You are a colleague asking the learner about their working or studying '
          'day: what they do every day, what is planned for today and what is '
          'difficult.',
    cafe =>
      'You are a waiter or barista in a cafe. The learner orders something to '
          'eat and drink, asks about the menu and asks a question about the '
          'place.',
    directions =>
      'The learner is lost in a town and asks you, a passer-by, how to get '
          'to a place; you explain, and they ask where things are.',
    shopping =>
      'You are a shop assistant. The learner looks for something to buy, '
          'asks about sizes, colors, prices and quantities, and pays.',
    describing =>
      'You ask the learner to describe a person, a place or an object they '
          'know well, and how they feel about it.',
    plans =>
      'You and the learner plan something together for the weekend or a '
          'trip: where to go, when, what to bring and what to do.',
  };
}

/// Today's speaking practice: a situation chosen from what the learner needs
/// to practice. A mission is only a plan: it detects no errors and writes
/// nothing; the conversation it opens does all that, like any other.
class ScenarioMission {
  const ScenarioMission({
    required this.id,
    required this.situation,
    required this.learningLanguage,
    required this.targetTopics,
    required this.prompt,
    this.minTurns = defaultMinTurns,
  });

  /// Messages from the learner after which the mission can be finished.
  static const defaultMinTurns = 2;

  /// Stable identity: the situation and the topics it practices.
  final String id;
  final ScenarioSituation situation;
  final AppLanguage learningLanguage;

  /// The grammar topics the situation is meant to give a chance to use (empty
  /// when it comes from the learner's goals).
  final List<GrammarTopic> targetTopics;

  /// The instruction handed to the teacher with the conversation (English).
  final String prompt;
  final int minTurns;

  @override
  bool operator ==(Object other) =>
      other is ScenarioMission &&
      other.id == id &&
      other.situation == situation &&
      other.learningLanguage == learningLanguage &&
      _sameTopics(other.targetTopics, targetTopics) &&
      other.prompt == prompt &&
      other.minTurns == minTurns;

  static bool _sameTopics(List<GrammarTopic> a, List<GrammarTopic> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    situation,
    learningLanguage,
    Object.hashAll(targetTopics),
    prompt,
    minTurns,
  );
}
