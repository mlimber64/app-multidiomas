import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/learning_overview.dart';
import '../learning_labels.dart';

/// One grammar topic with a plain-language reading of how it is going. Tap to
/// see the detail. State is carried by text and icon, never color alone.
class TopicTile extends StatelessWidget {
  const TopicTile({
    required this.view,
    required this.onTap,
    this.rank,
    super.key,
  });

  final TopicView view;
  final VoidCallback onTap;

  /// Position in a priority list (1-based), when the order matters.
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final improving = view.standing == TopicStanding.improving;
    final l = context.l10n;

    final status = view.hasProgress
        ? l.correctOutOf(view.successfulUses, view.appearances)
        : l.topicToConsolidate;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                if (rank != null) ...[
                  _RankBadge(rank: rank!),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        view.topic.label(l),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            improving ? Icons.trending_up : Icons.flag_outlined,
                            size: 18,
                            color: improving
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              improving ? l.topicImprovingStatus : status,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (view.hasProgress) ...[
                        const SizedBox(height: AppSpacing.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: view.correctShare,
                            minHeight: 6,
                            semanticsLabel: status,
                          ),
                        ),
                        if (improving)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              status,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}
