import '../../../l10n/l10n.dart';
import '../domain/scenario_mission.dart';

/// Interface copy for the speaking situations, in the current UI language.
/// (What the teacher is told lives in the domain, in English.)
extension ScenarioSituationLabel on ScenarioSituation {
  String title(AppLocalizations l) => switch (this) {
    ScenarioSituation.introduction => l.situationIntroductionTitle,
    ScenarioSituation.yesterday => l.situationYesterdayTitle,
    ScenarioSituation.workday => l.situationWorkdayTitle,
    ScenarioSituation.cafe => l.situationCafeTitle,
    ScenarioSituation.directions => l.situationDirectionsTitle,
    ScenarioSituation.shopping => l.situationShoppingTitle,
    ScenarioSituation.describing => l.situationDescribingTitle,
    ScenarioSituation.plans => l.situationPlansTitle,
  };

  String description(AppLocalizations l) => switch (this) {
    ScenarioSituation.introduction => l.situationIntroductionDesc,
    ScenarioSituation.yesterday => l.situationYesterdayDesc,
    ScenarioSituation.workday => l.situationWorkdayDesc,
    ScenarioSituation.cafe => l.situationCafeDesc,
    ScenarioSituation.directions => l.situationDirectionsDesc,
    ScenarioSituation.shopping => l.situationShoppingDesc,
    ScenarioSituation.describing => l.situationDescribingDesc,
    ScenarioSituation.plans => l.situationPlansDesc,
  };
}
