import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../domain/daily_routine.dart';
import 'daily_routine_controller.dart';
import 'scenario_labels.dart';
import 'scenario_mission_starter.dart';

/// "La tua pratica di oggi": the three steps of the day, in order. This screen
/// only shows the routine and starts each step; every step is done by the
/// screen that already exists for it (the review, the conversation, the word
/// list), and the routine only records that it was done.
class DailyRoutineScreen extends ConsumerWidget {
  const DailyRoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final routine = ref.watch(dailyRoutineProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.routineTitle)),
      body: SafeArea(
        child: ContentWidth(
          child: routine.when(
            loading: () => Center(
              child: Semantics(
                label: l.routinePreparing,
                child: const CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => ErrorStateView(
              message: l.routineError,
              onRetry: ref.read(dailyRoutineProvider.notifier).retry,
            ),
            data: (value) => _Routine(routine: value),
          ),
        ),
      ),
    );
  }
}

class _Routine extends ConsumerWidget {
  const _Routine({required this.routine});

  final DailyRoutine routine;

  Future<void> _startSpeaking(
    BuildContext context,
    WidgetRef ref,
    ScenarioStep step,
  ) async {
    final mission = step.mission;
    if (mission == null) return;
    await startScenarioMission(context, ref, mission);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final current = routine.currentStep;
    final started = routine.completedCount > 0;
    final cta = started ? l.continueAction : l.routineCtaStart;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l.routineIntro, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.md),
        RoutineProgress(routine: routine),
        const SizedBox(height: AppSpacing.lg),
        if (routine.isComplete && !routine.isEmpty) ...[
          _CompletedCard(),
          const SizedBox(height: AppSpacing.lg),
        ],
        _StepCard(
          number: 1,
          title: l.quickReview,
          icon: Icons.replay,
          state: routine.step1.state,
          description: routine.step1.state == RoutineStepState.unavailable
              ? l.routineReviewNone
              : l.routineReviewDesc(routine.step1.itemIds.length),
          isCurrent: current == 1,
          cta: cta,
          onTap: () => context.push(AppRoutes.routineReview),
        ),
        const SizedBox(height: AppSpacing.md),
        _StepCard(
          number: 2,
          title: l.chatTitle,
          icon: Icons.chat_bubble_outline,
          state: routine.step2.state,
          description: routine.step2.mission?.situation.title(l) ?? '',
          detail: routine.step2.mission?.situation.description(l),
          isCurrent: current == 2,
          cta: cta,
          onTap: () => _startSpeaking(context, ref, routine.step2),
        ),
        const SizedBox(height: AppSpacing.md),
        _StepCard(
          number: 3,
          title: l.routineStep3Title,
          icon: Icons.menu_book_outlined,
          state: routine.step3.state,
          description: routine.step3.state == RoutineStepState.unavailable
              ? l.routineWordsNone
              : l.routineWordsDesc(routine.step3.vocabularyIds.length),
          isCurrent: current == 3,
          cta: cta,
          onTap: () => context.push(AppRoutes.routineWords),
        ),
      ],
    );
  }
}

/// "1/3" with a bar, read aloud as "1 of 3 steps done". Counts only the steps
/// that have something to practice today.
class RoutineProgress extends StatelessWidget {
  const RoutineProgress({required this.routine, super.key});

  final DailyRoutine routine;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final done = routine.completedCount;
    final total = routine.availableCount;
    return Semantics(
      label: l.routineProgressSemantics(done, total),
      child: ExcludeSemantics(
        child: Row(
          children: [
            Text(
              l.routineProgress(done, total),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.routineCompleted,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.routineCompletedBody,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One step: done, nothing today, up next (with its button) or waiting for the
/// one before it. State is carried by icon and text, never by color alone.
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.icon,
    required this.state,
    required this.description,
    required this.isCurrent,
    required this.cta,
    required this.onTap,
    this.detail,
  });

  final int number;
  final String title;
  final IconData icon;
  final RoutineStepState state;
  final String description;
  final String? detail;
  final bool isCurrent;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = state == RoutineStepState.completed;
    final unavailable = state == RoutineStepState.unavailable;
    final status = done ? Icons.check_circle : icon;

    return Semantics(
      container: true,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: isCurrent ? scheme.primary : scheme.outlineVariant,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status,
                    color: done || isCurrent
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '$number. $title',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (done)
                    Text(
                      l.routineStepDone,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: unavailable ? scheme.onSurfaceVariant : null,
                ),
              ),
              if (detail != null && !done) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detail!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (isCurrent) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: onTap, child: Text(cta)),
              ] else if (state == RoutineStepState.pending) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: scheme.outline),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        l.routineStepLocked,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
