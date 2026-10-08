import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../l10n/l10n.dart';
import '../../conversation/domain/conversation_scenario.dart';
import '../../conversation/presentation/conversation_controller.dart';
import '../domain/scenario_mission.dart';
import 'scenario_labels.dart';

/// Opens today's speaking mission as a conversation. The one place that turns a
/// [ScenarioMission] into a conversation, shared by the routine screen and
/// Home's routine card.
Future<void> startScenarioMission(
  BuildContext context,
  WidgetRef ref,
  ScenarioMission mission,
) async {
  final l = context.l10n;
  final router = GoRouter.of(context);
  await ref
      .read(conversationControllerProvider.notifier)
      .startScenario(
        ConversationScenario(
          id: mission.id,
          title: mission.situation.title(l),
          instruction: mission.prompt,
          minTurns: mission.minTurns,
        ),
      );
  router.go(AppRoutes.conversation);
}
