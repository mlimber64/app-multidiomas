import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/result/result.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../learning/domain/learning_summary.dart';
import '../../learning/presentation/learning_providers.dart';
import '../../review/domain/review_item.dart';
import '../../review/presentation/review_providers.dart';
import '../../voice/presentation/widgets/listen_button.dart';
import 'daily_routine_controller.dart';

/// A word of today's routine, as it is shown: the word, its meaning if the
/// memory has one, and, when a correction the learner received contains it, the
/// phrase with the word left blank (built by the existing exercise generator).
class RoutineWord {
  const RoutineWord({
    required this.id,
    required this.word,
    this.meaning,
    this.context,
  });

  final String id;
  final String word;
  final String? meaning;
  final String? context;
}

/// The words of the routine's third step, read from the learning memory by id.
/// A word that is no longer there is left out; nothing is made up.
final routineWordsProvider = FutureProvider.autoDispose<List<RoutineWord>>((
  ref,
) async {
  final ids = ref.watch(
    dailyRoutineProvider.select((r) => r.value?.step3.vocabularyIds),
  );
  if (ids == null || ids.isEmpty) return const [];
  final summary = await ref.watch(learningEngineProvider).summary();
  if (summary case Failure(:final failure)) throw failure;
  final learned = (summary as Success<LearnerLearningSummary>).value;
  final generator = ref.watch(exerciseGeneratorProvider);

  final words = <RoutineWord>[];
  for (final id in ids) {
    final match = [
      for (final w in learned.vocabularyItems)
        if (w.id == id) w,
    ];
    if (match.isEmpty) continue;
    final word = match.first;
    final exercise = generator.generate(
      ReviewItem.discovered(ReviewItemType.vocabulary, id, DateTime.now()),
      learned,
    );
    words.add(
      RoutineWord(
        id: id,
        word: word.word,
        meaning: word.meaning,
        context: switch (exercise) {
          Success(value: final e) => e.prompt,
          Failure() => null,
        },
      ),
    );
  }
  return words;
});

/// Step 3, "Consolida": the words to reinforce today, to read, hear and, when
/// there is a phrase for it, to recall. Finishing marks the step as done.
class VocabularyStepScreen extends ConsumerWidget {
  const VocabularyStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final words = ref.watch(routineWordsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.routineStep3Title)),
      body: SafeArea(
        child: ContentWidth(
          child: words.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ErrorStateView(
              message: l.routineError,
              onRetry: () => ref.invalidate(routineWordsProvider),
            ),
            data: (list) => Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Text(
                        l.wordsStepIntro,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final word in list) ...[
                        _WordCard(word: word),
                        const SizedBox(height: AppSpacing.md),
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
                    child: FilledButton(
                      onPressed: () async {
                        // The step is done when the learner says so.
                        await ref
                            .read(dailyRoutineProvider.notifier)
                            .completeStep(3);
                        if (context.mounted) {
                          context.go(AppRoutes.dailyRoutine);
                        }
                      },
                      child: Text(l.wordsStepFinish),
                    ),
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

class _WordCard extends StatefulWidget {
  const _WordCard({required this.word});

  final RoutineWord word;

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final word = widget.word;
    final context0 = word.context;
    // With a phrase to complete, the word is the answer: it stays hidden
    // until the learner asks.
    final showWord = context0 == null || _revealed;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (context0 != null) ...[
              Text(l.wordsStepContext, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(context0, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (showWord)
              Text(word.word, style: theme.textTheme.headlineSmall)
            else
              TextButton(
                onPressed: () => setState(() => _revealed = true),
                child: Text(l.wordsStepReveal),
              ),
            if (showWord && word.meaning != null && word.meaning!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(word.meaning!, style: theme.textTheme.bodyMedium),
              ),
            if (showWord)
              Align(
                alignment: Alignment.centerLeft,
                child: ListenButton(
                  speechKey: 'routine-word:${word.id}',
                  text: word.word,
                  label: l.listen,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
