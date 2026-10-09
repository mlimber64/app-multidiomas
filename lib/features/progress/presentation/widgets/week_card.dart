import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../daily_routine/domain/daily_routine.dart';
import '../../../daily_routine/presentation/practice_activity.dart';
import '../../../daily_routine/presentation/scenario_labels.dart';

/// The week (Monday to Sunday) with the days there was practice. Each day can
/// be tapped: under the week a summary shows what was done that day, taken
/// from the routine saved for it. Today is selected to begin with, and tapping
/// the selected day again goes back to today.
class WeekCard extends ConsumerStatefulWidget {
  const WeekCard({super.key});

  @override
  ConsumerState<WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends ConsumerState<WeekCard> {
  /// The day (0 = Monday) the learner chose; `null` while it is today.
  int? _chosen;

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(practiceActivityProvider).value;
    if (activity == null) return const SizedBox.shrink();
    final l = context.l10n;
    final initials = l.weekInitials.split(',');
    final count = activity.week.where((d) => d).length;
    final selected = _chosen ?? activity.todayIndex;

    return AppCard(
      shadow: AppShadows.word,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.progressWeekTitle, style: AppTextStyles.rowTitle),
          const SizedBox(height: 12),
          Semantics(
            label: l.weekSemantics(count),
            container: true,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _DayDot(
                      initial: initials[i],
                      practiced: activity.week[i],
                      today: i == activity.todayIndex,
                      selected: i == selected,
                      semanticLabel: _daySemantics(context, activity, i),
                      onTap: () => setState(
                        () => _chosen = i == selected && _chosen != null
                            ? null
                            : i,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // The summary of the chosen day. AnimatedSize keeps the card from
          // jumping when the summary has a different height.
          AnimatedSize(
            duration: AppMotion.fast,
            alignment: Alignment.topCenter,
            child: _DaySummary(
              key: ValueKey(selected),
              activity: activity,
              index: selected,
            ),
          ),
        ],
      ),
    );
  }

  /// "lunes: 2 de 3 pasos hechos", for a screen reader.
  String _daySemantics(BuildContext context, PracticeActivity activity, int i) {
    final l = context.l10n;
    final date = activity.dateOf(i);
    final day = date == null
        ? l.weekInitials.split(',')[i]
        : MaterialLocalizations.of(context).formatFullDate(date);
    return l.progressDaySemantics(day, _status(l, activity, i));
  }
}

/// One sentence about a day, for the semantics and for the empty summary.
String _status(AppLocalizations l, PracticeActivity activity, int i) {
  final routine = activity.weekRoutines[i];
  if (routine != null && routine.completedCount > 0) {
    return l.routineProgressSemantics(
      routine.completedCount,
      routine.availableCount,
    );
  }
  if (i > activity.todayIndex) return l.dayFuture;
  if (i == activity.todayIndex) return l.dayTodayNone;
  return l.dayNoPractice;
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.initial,
    required this.practiced,
    required this.today,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  final String initial;
  final bool practiced;
  final bool today;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            children: [
              AnimatedContainer(
                duration: AppMotion.fast,
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: practiced ? AppColors.green : AppColors.divider,
                  shape: BoxShape.circle,
                  // The chosen day has the thick ring; today is marked by its
                  // bold initial and the dot under it.
                  border: selected
                      ? Border.all(color: AppColors.greenDark, width: 2.5)
                      : null,
                  boxShadow: selected ? AppShadows.talk : null,
                ),
                child: practiced
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                initial,
                style: AppTextStyles.small.copyWith(
                  fontWeight: today || selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: selected ? AppColors.greenDark : AppColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              // Today's marker.
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: today ? AppColors.green : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.activity, required this.index, super.key});

  final PracticeActivity activity;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final date = activity.dateOf(index);
    final routine = activity.weekRoutines[index];
    final practiced = routine != null && routine.completedCount > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.mintBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (date != null)
                Text(
                  MaterialLocalizations.of(context).formatFullDate(date),
                  style: AppTextStyles.rowTitle,
                ),
              if (!practiced)
                Padding(
                  padding: EdgeInsets.only(top: date != null ? 4 : 0),
                  child: Text(
                    _status(l, activity, index),
                    style: AppTextStyles.body,
                  ),
                )
              else ...[
                const SizedBox(height: 2),
                Text(
                  l.routineProgressSemantics(
                    routine.completedCount,
                    routine.availableCount,
                  ),
                  style: AppTextStyles.small,
                ),
                const SizedBox(height: 10),
                _StepLine(
                  icon: Icons.replay,
                  name: l.quickReview,
                  state: routine.step1.state,
                  detail: routine.step1.state == RoutineStepState.completed
                      ? l.exercisesDone(routine.step1.itemIds.length)
                      : null,
                ),
                _StepLine(
                  icon: Icons.chat_bubble_outline,
                  name: l.chatTitle,
                  state: routine.step2.state,
                  detail: routine.step2.mission?.situation.title(l),
                ),
                _StepLine(
                  icon: Icons.menu_book_outlined,
                  name: l.routineStep3Title,
                  state: routine.step3.state,
                  detail: routine.step3.state == RoutineStepState.completed
                      ? routine.step3.vocabularyIds.map(_wordOf).join(', ')
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// `it:prenotazione` -> `prenotazione` (see `UserVocabulary.idFor`).
  static String _wordOf(String id) {
    final cut = id.indexOf(':');
    return cut < 0 ? id : id.substring(cut + 1);
  }
}

/// One step of the day: what it is, whether it was done, and what was in it.
class _StepLine extends StatelessWidget {
  const _StepLine({
    required this.icon,
    required this.name,
    required this.state,
    this.detail,
  });

  final IconData icon;
  final String name;
  final RoutineStepState state;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final done = state == RoutineStepState.completed;
    final unavailable = state == RoutineStepState.unavailable;
    final label = switch (state) {
      RoutineStepState.completed => l.guidanceStepDone(name),
      RoutineStepState.pending => l.guidanceStepPending(name),
      RoutineStepState.unavailable => l.guidanceStepNone(name),
    };
    return Semantics(
      label: detail == null ? label : '$label. $detail',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            IconCircle(
              icon: done ? Icons.check : icon,
              size: 26,
              iconSize: 15,
              background: done ? AppColors.green : AppColors.surface,
              foreground: done ? Colors.white : AppColors.muted,
              border: done ? null : AppColors.border,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: name,
                      style: AppTextStyles.rowTitle.copyWith(
                        color: unavailable ? AppColors.muted : AppColors.ink,
                      ),
                    ),
                    if (detail != null && detail!.isNotEmpty)
                      TextSpan(
                        text: '  ·  $detail',
                        style: AppTextStyles.small,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
