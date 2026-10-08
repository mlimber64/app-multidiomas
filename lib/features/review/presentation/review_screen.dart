import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/empty_state_card.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/selectable_option_tile.dart';
import '../../daily_routine/domain/daily_routine.dart';
import '../../daily_routine/presentation/daily_routine_controller.dart';
import '../../learning/domain/grammar_topic.dart';
import '../../learning/presentation/learning_labels.dart';
import '../domain/exercise.dart';
import '../domain/review_session.dart';
import 'review_session_controller.dart';

/// "Ripassa": one review session. It only renders [ReviewSessionState] and
/// forwards `start`, `submitAnswer` and `continueSession` to the controller;
/// it never evaluates answers, schedules or touches storage.
///
/// With [routine] it is step 1 of the daily routine: up to three exercises,
/// only from the review items the routine chose, and finishing it marks the
/// step as done and goes back to the routine. The review itself works exactly
/// the same.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({this.routine = false, super.key});

  final bool routine;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  @override
  void initState() {
    super.initState();
    // Once per screen (never from build). Deferred: providers must not be
    // modified while the widget tree is being built.
    Future.microtask(() {
      if (!mounted) return;
      if (ref.read(reviewSessionControllerProvider).status ==
          ReviewSessionStatus.idle) {
        _start();
      }
    });
  }

  /// Starts (or restarts) the session: the usual one, or the routine's.
  void _start() {
    final controller = ref.read(reviewSessionControllerProvider.notifier);
    if (!widget.routine) {
      controller.start();
      return;
    }
    final chosen = ref.read(dailyRoutineProvider).value?.step1.itemIds;
    controller.start(size: ReviewStep.maxItems, onlyItems: chosen?.toSet());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewSessionControllerProvider);
    final controller = ref.read(reviewSessionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.quickReview)),
      body: SafeArea(
        child: ContentWidth(
          child: switch (state.status) {
            ReviewSessionStatus.idle || ReviewSessionStatus.loading => Center(
              child: Semantics(
                label: context.l10n.reviewPreparing,
                child: const CircularProgressIndicator(),
              ),
            ),
            ReviewSessionStatus.error => ErrorStateView(
              message: context.l10n.reviewError,
              onRetry: _start,
            ),
            ReviewSessionStatus.completed =>
              state.total == 0
                  ? _EmptySession(routine: widget.routine)
                  : _Completed(summary: state.summary, routine: widget.routine),
            ReviewSessionStatus.answering ||
            ReviewSessionStatus.submitting ||
            ReviewSessionStatus.feedback => _ExercisePage(
              state: state,
              controller: controller,
            ),
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise
// ---------------------------------------------------------------------------

class _ExercisePage extends StatelessWidget {
  const _ExercisePage({required this.state, required this.controller});

  final ReviewSessionState state;
  final ReviewSessionController controller;

  @override
  Widget build(BuildContext context) {
    final exercise = state.current;
    if (exercise == null) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      // A new exercise is a new widget: its answer is empty again.
      child: _ExerciseView(
        key: ValueKey(exercise.id),
        exercise: exercise,
        state: state,
        controller: controller,
      ),
    );
  }
}

class _ExerciseView extends StatefulWidget {
  const _ExerciseView({
    required this.exercise,
    required this.state,
    required this.controller,
    super.key,
  });

  final Exercise exercise;
  final ReviewSessionState state;
  final ReviewSessionController controller;

  @override
  State<_ExerciseView> createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<_ExerciseView> {
  final _text = TextEditingController();
  String? _selected;

  Exercise get _exercise => widget.exercise;
  ReviewSessionState get _state => widget.state;
  bool get _answering => _state.status == ReviewSessionStatus.answering;
  bool get _feedback => _state.status == ReviewSessionStatus.feedback;

  String get _answer =>
      _exercise.isMultipleChoice ? _selected ?? '' : _text.text;
  bool get _canCheck => _answering && _answer.trim().isNotEmpty;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _check() {
    if (!_canCheck) return;
    widget.controller.submitAnswer(_answer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcome = _state.outcome;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            children: [
              Semantics(
                label: context.l10n.exerciseSemantics(
                  _state.position,
                  _state.total,
                ),
                child: Text(
                  context.l10n.exerciseProgress(_state.position, _state.total),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _instruction(context.l10n),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _PromptCard(text: _promptText(context.l10n)),
              const SizedBox(height: AppSpacing.lg),
              if (_exercise.isMultipleChoice)
                _Options(
                  exercise: _exercise,
                  selected: _feedback ? outcome?.answer : _selected,
                  correct: _feedback ? outcome?.correctAnswer : null,
                  enabled: _answering,
                  onSelected: (o) => setState(() => _selected = o),
                )
              else
                TextField(
                  controller: _text,
                  enabled: _answering,
                  readOnly: !_answering,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _check(),
                  decoration: InputDecoration(
                    labelText: context.l10n.yourAnswer,
                    border: const OutlineInputBorder(),
                  ),
                ),
              if (outcome != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FadeSlideIn(child: _FeedbackCard(outcome: outcome)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: SizedBox(
            width: double.infinity,
            child: _feedback
                ? FilledButton(
                    onPressed: widget.controller.continueSession,
                    child: Text(context.l10n.continueAction),
                  )
                : FilledButton(
                    onPressed: _canCheck ? _check : null,
                    child: _state.status == ReviewSessionStatus.submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.l10n.check),
                  ),
          ),
        ),
      ],
    );
  }

  String _instruction(AppLocalizations l) => switch (_exercise.type) {
    ExerciseType.errorCorrection => l.instructionCorrect,
    ExerciseType.grammarChoice => l.instructionChoose,
    ExerciseType.vocabularyContext => l.instructionComplete,
  };

  /// The grammar prompt is the topic key; everything else is shown as is.
  String _promptText(AppLocalizations l) {
    if (_exercise.type != ExerciseType.grammarChoice) return _exercise.prompt;
    for (final t in GrammarTopic.values) {
      if (t.name == _exercise.prompt) return t.label(l);
    }
    return _exercise.prompt;
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(text, style: theme.textTheme.headlineSmall),
      ),
    );
  }
}

/// Single-choice options. After an answer: the chosen one is marked, and the
/// correct one is marked with its own icon and label, so it never relies on
/// color alone.
class _Options extends StatelessWidget {
  const _Options({
    required this.exercise,
    required this.selected,
    required this.correct,
    required this.enabled,
    required this.onSelected,
  });

  final Exercise exercise;
  final String? selected;

  /// Set only once the answer has been checked.
  final String? correct;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in exercise.options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: correct == null
                ? SelectableOptionTile(
                    title: option,
                    selected: option == selected,
                    onTap: () => onSelected(option),
                    enabled: enabled,
                  )
                : _CheckedOption(
                    title: option,
                    chosen: option == selected,
                    isCorrect: option == correct,
                  ),
          ),
      ],
    );
  }
}

class _CheckedOption extends StatelessWidget {
  const _CheckedOption({
    required this.title,
    required this.chosen,
    required this.isCorrect,
  });

  final String title;
  final bool chosen;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tag = isCorrect
        ? context.l10n.correctAnswerTag
        : chosen
        ? context.l10n.yourAnswer
        : null;
    final highlight = isCorrect || chosen;
    final color = isCorrect ? scheme.primary : scheme.error;
    return Semantics(
      selected: chosen,
      label: [title, ?tag].join(', '),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: highlight ? color : scheme.outlineVariant,
            width: highlight ? 2 : 1,
          ),
          color: highlight ? color.withValues(alpha: 0.08) : scheme.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (tag != null)
                    Text(
                      tag,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                      ),
                    ),
                ],
              ),
            ),
            if (highlight)
              Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: color),
          ],
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.outcome});

  final AnswerOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final good = outcome.isCorrect;
    final color = good ? scheme.primary : scheme.error;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: color, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(good ? Icons.check_circle : Icons.info, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    good
                        ? context.l10n.feedbackCorrect
                        : context.l10n.feedbackIncorrect,
                    style: theme.textTheme.titleLarge?.copyWith(color: color),
                  ),
                ],
              ),
              if (!good) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.l10n.yourAnswerWas(outcome.answer.trim()),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.l10n.correctAnswerIs,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  outcome.correctAnswer,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (outcome.explanation.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(outcome.explanation, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// End states
// ---------------------------------------------------------------------------

/// How a finished review ends: back to the path, or, inside the daily routine,
/// marking its first step done and going on with the routine.
class _BackToPath extends ConsumerWidget {
  const _BackToPath({this.routine = false});

  final bool routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton(
    onPressed: () async {
      if (!routine) return context.go(AppRoutes.progress);
      // The routine's step is done when its review is finished.
      await ref.read(dailyRoutineProvider.notifier).completeStep(1);
      if (context.mounted) context.go(AppRoutes.dailyRoutine);
    },
    child: Text(
      routine ? context.l10n.routineContinue : context.l10n.backToPath,
    ),
  );
}

class _EmptySession extends StatelessWidget {
  const _EmptySession({this.routine = false});

  final bool routine;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        EmptyStateCard(
          icon: Icons.replay,
          title: context.l10n.reviewEmptyTitle,
          message: context.l10n.reviewEmptyBody,
          action: _BackToPath(routine: routine),
        ),
      ],
    );
  }
}

class _Completed extends StatelessWidget {
  const _Completed({required this.summary, this.routine = false});

  final bool routine;

  final ReviewSessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final lines = [
      l.exercisesDone(summary.attempted),
      l.correctCount(summary.correct),
      if (summary.incorrect > 0) l.toRetry(summary.incorrect),
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        FadeSlideIn(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(l.reviewDoneTitle, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  for (final line in lines)
                    Text(line, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.lg),
                  _BackToPath(routine: routine),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
