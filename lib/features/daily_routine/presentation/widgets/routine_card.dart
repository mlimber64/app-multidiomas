import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../guidance/domain/learning_guidance.dart';
import '../../../guidance/presentation/guidance_labels.dart';
import '../../../guidance/presentation/learning_guidance_provider.dart';
import '../../domain/daily_routine.dart';
import '../daily_routine_controller.dart';
import '../daily_routine_screen.dart';
import '../scenario_labels.dart';
import '../scenario_mission_starter.dart';

/// Home's card for "La tua pratica di oggi": the real progress of today's
/// routine, the step that is next with the reason for it, and one button that
/// goes straight to that step. The card itself opens the whole routine. Nothing
/// here is an invented number: it all comes from the routine.
class RoutineCard extends ConsumerStatefulWidget {
  const RoutineCard({super.key});

  @override
  ConsumerState<RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends ConsumerState<RoutineCard> {
  late final AppLifecycleListener _lifecycle;

  /// A navigation is under way: further taps are ignored until it is over.
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    // The app left open overnight: coming back, the routine is today's.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(dailyRoutineProvider.notifier).refreshForToday(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await action();
    } finally {
      _navigating = false;
    }
  }

  Future<void> _openOverview() =>
      _guard(() => context.push<void>(AppRoutes.dailyRoutine));

  Future<void> _start(LearningGuidance guidance, DailyRoutine routine) =>
      _guard(() async {
        switch (guidance.kind) {
          case GuidanceKind.review:
            await context.push<void>(AppRoutes.routineReview);
          case GuidanceKind.vocabulary:
            await context.push<void>(AppRoutes.routineWords);
          case GuidanceKind.talk:
            final mission = routine.step2.mission;
            if (mission == null) return;
            await startScenarioMission(context, ref, mission);
          case GuidanceKind.completed:
            await context.push<void>(AppRoutes.dailyRoutine);
        }
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final routine = ref.watch(dailyRoutineProvider);
    return routine.when(
      // Home never waits for it: the card appears when it is ready.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => _Frame(
        child: Row(
          children: [
            Expanded(child: Text(l.routineError)),
            TextButton(
              onPressed: ref.read(dailyRoutineProvider.notifier).retry,
              child: Text(l.tryAgain),
            ),
          ],
        ),
      ),
      data: (value) => _Content(
        routine: value,
        guidance: ref.watch(learningGuidanceProvider),
        onOpenOverview: _openOverview,
        onStart: (guidance) => _start(guidance, value),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.routine,
    required this.guidance,
    required this.onOpenOverview,
    required this.onStart,
  });

  final DailyRoutine routine;

  /// `null` when the routine has nothing to practice.
  final LearningGuidance? guidance;
  final VoidCallback onOpenOverview;
  final void Function(LearningGuidance guidance) onStart;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final guidance = this.guidance;
    final complete = guidance?.kind == GuidanceKind.completed;
    const minSize = Size(0, AppSizes.minTouch);
    final overviewLabel = routine.completedCount > 0
        ? l.guidanceContinue
        : l.guidanceStart;

    final String? reason = guidance == null || complete
        ? null
        : guidance.reason.text(
            l,
            fallback: routine.step2.mission?.situation.description(l) ?? '',
          );

    return _Frame(
      onTap: onOpenOverview,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.routineTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          RoutineProgress(routine: routine),
          const SizedBox(height: AppSpacing.md),
          if (guidance == null) ...[
            Text(l.routineIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: minSize),
              onPressed: onOpenOverview,
              child: Text(overviewLabel),
            ),
          ] else if (complete) ...[
            Row(
              children: [
                Icon(Icons.check_circle, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l.guidanceCompleted,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l.routineCompletedBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            _Steps(routine: routine),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: minSize),
              onPressed: onOpenOverview,
              child: Text(l.routineContinue),
            ),
          ] else ...[
            Text(
              guidance.kind.action(l),
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(reason, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: minSize),
              onPressed: () => onStart(guidance),
              child: Text(guidance.kind.action(l)),
            ),
            const SizedBox(height: AppSpacing.md),
            _Steps(routine: routine),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              style: TextButton.styleFrom(minimumSize: minSize),
              onPressed: onOpenOverview,
              child: Text(overviewLabel),
            ),
          ],
        ],
      ),
    );
  }
}

/// "✓ Ripassa ○ Parla ○ Consolida": the state of each step in the icon and in
/// the words read aloud, never in color alone. Wraps on narrow screens.
class _Steps extends StatelessWidget {
  const _Steps({required this.routine});

  final DailyRoutine routine;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = [
      (l.quickReview, routine.step1.state),
      (l.chatTitle, routine.step2.state),
      (l.routineStep3Title, routine.step3.state),
    ];
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (name, state) in steps) _StepChip(name: name, state: state),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.name, required this.state});

  final String name;
  final RoutineStepState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color, label) = switch (state) {
      RoutineStepState.completed => (
        Icons.check_circle,
        scheme.primary,
        l.guidanceStepDone(name),
      ),
      RoutineStepState.pending => (
        Icons.radio_button_unchecked,
        scheme.onSurfaceVariant,
        l.guidanceStepPending(name),
      ),
      RoutineStepState.unavailable => (
        Icons.remove_circle_outline,
        scheme.outline,
        l.guidanceStepNone(name),
      ),
    };
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.xs),
            Flexible(child: Text(name, style: theme.textTheme.labelLarge)),
          ],
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}
