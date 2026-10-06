import '../../../l10n/l10n.dart';
import '../domain/grammar_topic.dart';

/// The grammar topics' names, as the learner sees them in the current UI
/// language.
extension GrammarTopicLabel on GrammarTopic {
  String label(AppLocalizations l) => switch (this) {
    GrammarTopic.passatoProssimo => l.topicPassatoProssimo,
    GrammarTopic.essereVsAvere => l.topicEssereVsAvere,
    GrammarTopic.prepositions => l.topicPrepositions,
    GrammarTopic.articles => l.topicArticles,
    GrammarTopic.gender => l.topicGender,
    GrammarTopic.plural => l.topicPlural,
    GrammarTopic.agreement => l.topicAgreement,
    GrammarTopic.pronouns => l.topicPronouns,
    GrammarTopic.verbConjugation => l.topicVerbConjugation,
    GrammarTopic.wordOrder => l.topicWordOrder,
    GrammarTopic.toBe => l.topicToBe,
    GrammarTopic.presentContinuous => l.topicPresentContinuous,
    GrammarTopic.pastSimple => l.topicPastSimple,
    GrammarTopic.presentPerfect => l.topicPresentPerfect,
    GrammarTopic.thirdPersonSingular => l.topicThirdPersonSingular,
    GrammarTopic.etreVsAvoir => l.topicEtreVsAvoir,
    GrammarTopic.passeCompose => l.topicPasseCompose,
    GrammarTopic.serVsEstar => l.topicSerVsEstar,
    GrammarTopic.habenVsSein => l.topicHabenVsSein,
    GrammarTopic.perfekt => l.topicPerfekt,
    GrammarTopic.cases => l.topicCases,
    GrammarTopic.porVsPara => l.topicPorVsPara,
    GrammarTopic.measureWords => l.topicMeasureWords,
    GrammarTopic.structuralParticles => l.topicStructuralParticles,
    GrammarTopic.aspectParticles => l.topicAspectParticles,
    GrammarTopic.negation => l.topicNegation,
  };
}
