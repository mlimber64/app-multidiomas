import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../conversation/presentation/conversation_controller.dart';
import '../daily_routine_controller.dart';

/// Over the conversation while it plays out today's mission: what it is and
/// how to finish it. The conversation underneath is the usual one; finishing
/// only tells the routine its second step is done and goes back to it.
class ScenarioBanner extends ConsumerWidget {
  const ScenarioBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenario = ref.watch(
      conversationControllerProvider.select((s) => s.scenario),
    );
    if (scenario == null) return const SizedBox.shrink();
    final ready = ref.watch(
      conversationControllerProvider.select((s) => s.scenarioReady),
    );
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.flag_outlined, color: scheme.onSecondaryContainer),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.missionBanner(scenario.title),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                      if (!ready)
                        Text(
                          l.missionKeepGoing,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // The theme makes buttons full width: here it is the only action.
            FilledButton.tonal(
              onPressed: ready ? () => _finish(context, ref) : null,
              child: Text(l.missionFinish),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    await ref.read(dailyRoutineProvider.notifier).completeStep(2);
    ref.read(conversationControllerProvider.notifier).finishScenario();
    router.go(AppRoutes.dailyRoutine);
  }
}
