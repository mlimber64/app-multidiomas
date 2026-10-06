import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../learning/presentation/learning_labels.dart';
import '../../learning/presentation/learning_providers.dart';
import '../../profile/domain/user_learning_profile.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../profile/presentation/profile_labels.dart';

/// Hub of the app: greeting, the main call to action, quick access to the
/// areas, and the learner's saved preferences. No learning statistics exist
/// yet, so none are shown.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userLearningProfileProvider);
    final theme = Theme.of(context);
    final l = context.l10n;
    const step = Duration(milliseconds: 70);

    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.homeGreeting, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(l.homeReady, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(delay: step, child: const _HeroCard()),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(delay: step * 2, child: const _QuickActions()),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: step * 3,
                child: _JourneyCard(profile: profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );
    return Semantics(
      button: true,
      child: Material(
        color: scheme.primary,
        shape: shape,
        elevation: AppElevation.raised,
        child: InkWell(
          customBorder: shape,
          onTap: () => context.go(AppRoutes.conversation),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.letsTalk,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: scheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        context.l10n.heroSubtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(Icons.arrow_forward, color: scheme.onPrimary, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    // "Ripassa" opens the review session above the shell; the rest are tabs.
    final l = context.l10n;
    final actions = [
      (Icons.chat_bubble_outline, l.quickConversation, AppRoutes.conversation),
      (Icons.school_outlined, l.navLearn, AppRoutes.learning),
      (Icons.replay, l.quickReview, AppRoutes.review),
      (Icons.menu_book_outlined, l.navWords, AppRoutes.vocabulary),
    ];
    Widget row(int start) => Row(
      children: [
        for (var i = start; i < start + 2; i++) ...[
          if (i > start) const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _QuickActionTile(
              icon: actions[i].$1,
              label: actions[i].$2,
              onTap: () => actions[i].$3 == AppRoutes.review
                  ? context.push(actions[i].$3)
                  : context.go(actions[i].$3),
            ),
          ),
        ],
      ],
    );
    return Column(
      children: [
        row(0),
        const SizedBox(height: AppSpacing.md),
        row(2),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouch + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.profile});

  final UserLearningProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.journeyTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            _InfoRow(l.rowLanguage, profile.learningLanguage.label),
            _InfoRow(l.rowLevel, profile.level?.label(l)),
            _InfoRow(
              l.rowGoals,
              joinLabels(
                l,
                LearningGoal.values,
                profile.goals,
                (g) => g.label(l),
              ),
            ),
            _InfoRow(
              l.rowFocus,
              joinLabels(
                l,
                LearningFocus.values,
                profile.focusAreas,
                (f) => f.label(l),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _LearningNote(),
          ],
        ),
      ),
    );
  }
}

/// What the app has learned so far, in one small block: an invitation while
/// there is nothing yet, otherwise the learner's current focus and what is
/// improving. While the memory loads, or if it cannot be read, nothing is
/// shown: Home never blocks or complains about it.
class _LearningNote extends ConsumerWidget {
  const _LearningNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final overview = ref.watch(learningOverviewProvider).value;
    if (overview == null) return const SizedBox.shrink();
    if (overview.isEmpty) {
      return _NoteBlock(title: l.noteStartTitle, lines: [l.noteStartBody]);
    }
    if (!overview.hasTopics) return const SizedBox.shrink();

    final focus = overview.toReinforce.firstOrNull;
    final improving = overview.improving
        .take(2)
        .map((t) => t.topic.label(l))
        .toList();
    return _NoteBlock(
      title: focus != null ? l.noteFocusTitle : l.noteImprovingTitle,
      onTap: () => context.go(AppRoutes.progress),
      lines: [
        if (focus != null) ...[focus.topic.label(l), l.noteKeepPracticing],
        if (focus == null) improving.join(', '),
        if (focus != null && improving.isNotEmpty)
          l.noteImprovingIn(improving.join(', ')),
      ],
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.title, required this.lines, this.onTap});

  final String title;
  final List<String> lines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onPrimaryContainer,
    );
    return Material(
      color: scheme.primaryContainer,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    for (final line in lines) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(line, style: style),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? context.l10n.notSet,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
