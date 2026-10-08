/// A situation the conversation is asked to play out (today's speaking mission
/// of the daily routine). The conversation is the usual one: this only tells the
/// teacher what to play and tells the screen what to show.
class ConversationScenario {
  const ConversationScenario({
    required this.id,
    required this.title,
    required this.instruction,
    this.minTurns = 2,
  });

  /// Stable identity (the mission's).
  final String id;

  /// Shown to the learner, in their interface language.
  final String title;

  /// Handed to the teacher with every request (English).
  final String instruction;

  /// Messages from the learner after which the scenario can be finished.
  final int minTurns;
}

/// Said to the teacher in place of a learner message when a conversation opens
/// with the teacher speaking first. Never shown and never stored.
const scenarioOpeningTrigger =
    '[The learner is ready. Begin the scenario: set the scene and say your '
    'first line.]';
