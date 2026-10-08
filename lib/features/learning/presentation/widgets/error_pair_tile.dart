import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/ui/app_card.dart';
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
    final topic = error.topic;
    return Semantics(
      container: true,
      label: context.l10n.errorPairSemantics(error.incorrect, error.correct),
      child: ExcludeSemantics(
        child: AppCard(
          radius: AppRadius.panel,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: error.incorrect,
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.errorStrike,
                        color: AppColors.errorText,
                      ),
                    ),
                    const TextSpan(text: '  →  '),
                    TextSpan(
                      text: error.correct,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                style: AppTextStyles.bodyStrong,
              ),
              if (showTopic && topic != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    topic.label(context.l10n),
                    style: AppTextStyles.small,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
