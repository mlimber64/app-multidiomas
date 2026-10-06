import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/learning_overview.dart';
import '../learning_labels.dart';

/// A mistake and its correct form, with the topic it belongs to.
class ErrorPairTile extends StatelessWidget {
  const ErrorPairTile({required this.error, this.showTopic = true, super.key});

  final ErrorView error;
  final bool showTopic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topic = error.topic;
    return Semantics(
      container: true,
      label: context.l10n.errorPairSemantics(error.incorrect, error.correct),
      child: ExcludeSemantics(
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: error.incorrect,
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const TextSpan(text: '  →  '),
                      TextSpan(
                        text: error.correct,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  style: theme.textTheme.titleMedium,
                ),
                if (showTopic && topic != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      topic.label(context.l10n),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
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
