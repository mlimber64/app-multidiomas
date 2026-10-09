import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../daily_routine/presentation/practice_activity.dart';
import '../../../learning/presentation/learning_providers.dart';
import '../../domain/achievements.dart';

/// The learner's real stats, as the achievements read them: from the learning
/// overview and the practice of the days. While either is still loading (or
/// cannot be read) the missing part simply counts as nothing yet.
final achievementStatsProvider = Provider<AchievementStats>((ref) {
  final overview = ref.watch(learningOverviewProvider).value;
  final activity = ref.watch(practiceActivityProvider).value;
  final inUse = overview?.vocabularyInUse.length ?? 0;
  final toConsolidate = overview?.vocabularyToConsolidate.length ?? 0;
  return AchievementStats(
    hasMemory: overview != null && !overview.isEmpty,
    streak: activity?.streak ?? 0,
    practicedThisWeek: activity?.week.where((d) => d).length ?? 0,
    fullPracticeDay:
        activity?.weekRoutines.any(
          (r) =>
              r != null &&
              r.availableCount > 0 &&
              r.completedCount == r.availableCount,
        ) ??
        false,
    wordsMet: inUse + toConsolidate,
    wordsInUse: inUse,
    areasImproving: overview?.improving.length ?? 0,
  );
});

/// "Tus logros": medals for the effort so far. Unlocked ones are colored,
/// the rest are grey with a lock and say what unlocks them. Tapping a medal
/// shows its name and goal under the grid (so a locked one is a target, not a
/// mystery). Everything unlocks from facts the app already knows.
class AchievementsCard extends ConsumerStatefulWidget {
  const AchievementsCard({super.key});

  @override
  ConsumerState<AchievementsCard> createState() => _AchievementsCardState();
}

class _AchievementsCardState extends ConsumerState<AchievementsCard> {
  Achievement? _selected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stats = ref.watch(achievementStatsProvider);
    final unlocked = unlockedAchievements(stats).toSet();
    // Until the learner chooses one, the first one still to unlock is shown:
    // a goal to aim for.
    final shown =
        _selected ??
        Achievement.values.firstWhere(
          (a) => !unlocked.contains(a),
          orElse: () => Achievement.values.first,
        );

    return AppCard(
      radius: AppRadius.panel,
      shadow: AppShadows.word,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.achievementsTitle, style: AppTextStyles.rowTitle),
              ),
              StatusChip(
                label: l.achievementsCount(
                  unlocked.length,
                  Achievement.values.length,
                ),
                icon: Icons.emoji_events_outlined,
                background: AppColors.amberBg,
                foreground: AppColors.amberText,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Responsive: three medals per row on a narrow phone, four when
          // there is room; they never overflow.
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final columns = constraints.maxWidth >= 360 ? 4 : 3;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final a in Achievement.values)
                    SizedBox(
                      width: width,
                      child: _Medal(
                        achievement: a,
                        unlocked: unlocked.contains(a),
                        selected: a == shown,
                        onTap: () => setState(() => _selected = a),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _Detail(achievement: shown, unlocked: unlocked.contains(shown)),
        ],
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({
    required this.achievement,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final Achievement achievement;
  final bool unlocked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final look = achievement.look;
    final title = achievement.title(l);
    return Semantics(
      button: true,
      selected: selected,
      label:
          '$title. ${unlocked ? l.achievementUnlocked : l.achievementLocked}. '
          '${achievement.goal(l)}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked ? look.background : AppColors.surfaceSoft,
                border: Border.all(
                  color: selected
                      ? (unlocked ? look.foreground : AppColors.muted)
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Icon(
                unlocked ? look.icon : Icons.lock_rounded,
                size: 26,
                color: unlocked ? look.foreground : AppColors.placeholder,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.small.copyWith(
                fontSize: 11.5,
                height: 1.2,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: unlocked ? AppColors.ink : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.achievement, required this.unlocked});

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      child: DecoratedBox(
        key: ValueKey(achievement),
        decoration: BoxDecoration(
          color: unlocked ? AppColors.mintSoft : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: unlocked ? AppColors.mintBorder : AppColors.divider,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A Wrap, not a Row: on a very narrow screen the state goes
                // under the name instead of overflowing.
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(achievement.title(l), style: AppTextStyles.rowTitle),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          unlocked ? Icons.check_circle : Icons.lock_rounded,
                          size: 18,
                          color: unlocked ? AppColors.green : AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            unlocked
                                ? l.achievementUnlocked
                                : l.achievementLocked,
                            style: AppTextStyles.small.copyWith(
                              fontWeight: FontWeight.w800,
                              color: unlocked
                                  ? AppColors.greenDark
                                  : AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(achievement.goal(l), style: AppTextStyles.body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How each achievement is named, explained and drawn.
extension AchievementLabel on Achievement {
  String title(AppLocalizations l) => switch (this) {
    Achievement.firstSteps => l.achFirstStepsTitle,
    Achievement.streak3 => l.achStreak3Title,
    Achievement.streak7 => l.achStreak7Title,
    Achievement.fullDay => l.achFullDayTitle,
    Achievement.firstWord => l.achFirstWordTitle,
    Achievement.words10 => l.achWords10Title,
    Achievement.improving1 => l.achImproving1Title,
    Achievement.improving3 => l.achImproving3Title,
  };

  /// What unlocks it (also what it was won for).
  String goal(AppLocalizations l) => switch (this) {
    Achievement.firstSteps => l.achFirstStepsGoal,
    Achievement.streak3 => l.achStreak3Goal,
    Achievement.streak7 => l.achStreak7Goal,
    Achievement.fullDay => l.achFullDayGoal,
    Achievement.firstWord => l.achFirstWordGoal,
    Achievement.words10 => l.achWords10Goal,
    Achievement.improving1 => l.achImproving1Goal,
    Achievement.improving3 => l.achImproving3Goal,
  };

  ({IconData icon, Color background, Color foreground}) get look =>
      switch (this) {
        Achievement.firstSteps => (
          icon: Icons.flag_outlined,
          background: AppColors.mint,
          foreground: AppColors.greenDark,
        ),
        Achievement.streak3 => (
          icon: Icons.local_fire_department,
          background: AppColors.amberBg,
          foreground: AppColors.amberText,
        ),
        Achievement.streak7 => (
          icon: Icons.whatshot,
          background: AppColors.terraBg,
          foreground: AppColors.terraText,
        ),
        Achievement.fullDay => (
          icon: Icons.task_alt,
          background: AppColors.feedbackBg,
          foreground: AppColors.feedbackAccent,
        ),
        Achievement.firstWord => (
          icon: Icons.bookmark_added_outlined,
          background: AppColors.mint,
          foreground: AppColors.greenDark,
        ),
        Achievement.words10 => (
          icon: Icons.menu_book,
          background: AppColors.feedbackBg,
          foreground: AppColors.feedbackAccent,
        ),
        Achievement.improving1 => (
          icon: Icons.trending_up,
          background: AppColors.mint,
          foreground: AppColors.greenDark,
        ),
        Achievement.improving3 => (
          icon: Icons.rocket_launch_outlined,
          background: AppColors.amberBg,
          foreground: AppColors.amberText,
        ),
      };
}
