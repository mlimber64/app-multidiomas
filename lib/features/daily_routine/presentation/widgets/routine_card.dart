import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../guidance/domain/learning_guidance.dart';
import '../../../guidance/presentation/guidance_labels.dart';
import '../../../guidance/presentation/learning_guidance_provider.dart';
import '../../domain/daily_routine.dart';
import '../daily_routine_controller.dart';
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
      // NUEVO: mientras se prepara, un esqueleto neutro con el radio final
      // (Inicio nunca espera por ella ni muestra un spinner a pantalla completa).
      loading: () => const _Skeleton(),
      error: (_, _) => AppCard(
        radius: AppRadius.hero,
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Expanded(child: Text(l.routineError, style: AppTextStyles.body)),
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

// NUEVO: esqueleto de la tarjeta mientras la rutina carga.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.routinePreparing,
    child: Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
    ),
  );
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
    final guidance = this.guidance;
    final complete = guidance?.kind == GuidanceKind.completed;
    final done = routine.completedCount;
    final total = routine.availableCount;

    // NUEVO: el título del hero es el paso que toca; debajo, la razón que ya
    // daba la guía (el mismo texto de antes).
    final String title;
    final String reason;
    if (guidance == null) {
      title = l.routineTitle;
      reason = l.routineIntro;
    } else if (complete) {
      title = l.guidanceCompleted;
      reason = l.routineCompletedBody;
    } else {
      title = switch (guidance.kind) {
        GuidanceKind.review => l.routineHeroReview,
        GuidanceKind.talk => l.routineHeroTalk,
        GuidanceKind.vocabulary => l.routineHeroWords,
        GuidanceKind.completed => l.guidanceCompleted,
      };
      reason = guidance.reason.text(
        l,
        fallback: routine.step2.mission?.situation.description(l) ?? '',
      );
    }

    final String buttonLabel;
    final VoidCallback onButton;
    if (guidance == null) {
      buttonLabel = done > 0 ? l.routineContinue : l.routineStartPractice;
      onButton = onOpenOverview;
    } else if (complete) {
      buttonLabel = l.routineContinue;
      onButton = onOpenOverview;
    } else {
      buttonLabel = done > 0 ? l.routineContinue : l.routineStartPractice;
      onButton = () => onStart(guidance);
    }

    // NUEVO: con la práctica de hoy completa la tarjeta pasa de celeste a verde
    // suave y muestra una insignia que aparece con un pequeño rebote. Todos los
    // colores de la tarjeta salen de este par (acento y texto).
    final accent = complete ? AppColors.green : AppColors.blue;
    final soft = complete ? AppColors.greenDark : AppColors.blueText;
    return CelesteHeroCard(
      color: complete ? AppColors.mint : AppColors.celeste,
      shadow: complete ? AppShadows.success : AppShadows.hero,
      onTap: onOpenOverview,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.routineTitle.toUpperCase(),
                  style: AppTextStyles.eyebrow.copyWith(color: soft),
                ),
              ),
              Semantics(
                label: l.routineProgressSemantics(done, total),
                excludeSemantics: true,
                child: Text(
                  l.routineProgress(done, total),
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 14,
                    color: complete ? AppColors.greenDark : AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentProgress(
            total: 3,
            filled: done,
            height: 6,
            filledColor: accent,
            emptyColor: AppColors.heroTrack,
          ),
          const SizedBox(height: 14),
          if (complete) ...[
            const _CompletedBadge(),
            const SizedBox(height: 10),
          ],
          Text(
            title,
            style: AppTextStyles.heroTitle.copyWith(
              color: complete ? AppColors.greenDark : null,
            ),
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reason,
              style: AppTextStyles.screenSubtitle.copyWith(color: soft),
            ),
          ],
          const SizedBox(height: 14),
          _StepPills(routine: routine, accent: accent, soft: soft),
          const SizedBox(height: 14),
          PrimaryButton(
            label: buttonLabel,
            variant: complete
                ? PrimaryButtonVariant.green
                : PrimaryButtonVariant.blue,
            trailingIcon: Icons.arrow_forward,
            onPressed: onButton,
          ),
        ],
      ),
    );
  }
}

// NUEVO: "① Repasar ② Hablar ③ Consolida": el estado de cada paso va en el
// círculo (número, número resaltado o check) y se lee en voz alta con
// palabras, nunca solo por color. Se parte en líneas en pantallas estrechas.
class _StepPills extends StatelessWidget {
  const _StepPills({
    required this.routine,
    required this.accent,
    required this.soft,
  });

  final DailyRoutine routine;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = [
      (1, l.quickReview, routine.step1.state),
      (2, l.chatTitle, routine.step2.state),
      (3, l.routineStep3Title, routine.step3.state),
    ];
    final current = routine.currentStep;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (number, name, state) in steps)
          _StepPill(
            number: number,
            name: name,
            state: state,
            active: current == number,
            accent: accent,
            soft: soft,
          ),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.number,
    required this.name,
    required this.state,
    required this.active,
    required this.accent,
    required this.soft,
  });

  final int number;
  final String name;
  final RoutineStepState state;
  final bool active;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = switch (state) {
      RoutineStepState.completed => l.guidanceStepDone(name),
      RoutineStepState.pending => l.guidanceStepPending(name),
      RoutineStepState.unavailable => l.guidanceStepNone(name),
    };
    final completed = state == RoutineStepState.completed;
    final textColor = active ? AppColors.navy : soft;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? Colors.white : AppColors.onCelesteSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepCircle(
                number: number,
                completed: completed,
                filled: completed || active,
                accent: accent,
                soft: soft,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  style: AppTextStyles.chip.copyWith(color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.number,
    required this.completed,
    required this.filled,
    required this.accent,
    required this.soft,
  });

  final int number;
  final bool completed;
  final bool filled;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? accent : Colors.transparent,
        shape: BoxShape.circle,
        border: filled ? null : Border.all(color: soft, width: 1.5),
      ),
      child: completed
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : Text(
              '$number',
              style: AppTextStyles.chip.copyWith(
                fontSize: 11,
                height: 1,
                color: filled ? Colors.white : soft,
              ),
            ),
    );
  }
}

// NUEVO: insignia de "práctica completada". Entra una sola vez con un rebote
// (escala elástica) y un destello; con las animaciones del sistema apagadas
// aparece ya en su sitio.
class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.centerLeft,
        child: child,
      ),
      child: Semantics(
        label: l.guidanceCompleted,
        excludeSemantics: true,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
