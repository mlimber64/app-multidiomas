import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../domain/learning_overview.dart';
import 'learning_providers.dart';

/// Gives a screen the learner's overview, handling the three states once for
/// every screen: loading, a friendly retry if the memory cannot be read, and
/// the data. While the overview refreshes, the previous data stays on screen.
class OverviewBuilder extends ConsumerWidget {
  const OverviewBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, LearningOverview overview)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(learningOverviewProvider);
    final data = overview.value;
    if (data != null) return builder(context, data);
    if (overview.hasError) {
      return ErrorStateView(
        message: context.l10n.overviewError,
        onRetry: () => ref.invalidate(learningOverviewProvider),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
