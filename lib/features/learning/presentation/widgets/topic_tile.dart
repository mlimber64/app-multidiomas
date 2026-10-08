import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
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
    final improving = view.standing == TopicStanding.improving;
    final l = context.l10n;

    final status = view.hasProgress
        ? l.correctOutOf(view.successfulUses, view.appearances)
        : l.topicToConsolidate;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
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
                  Text(view.topic.label(l), style: AppTextStyles.rowTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        improving ? Icons.trending_up : Icons.flag_outlined,
                        size: 18,
                        color: improving ? AppColors.green : AppColors.muted,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          improving ? l.topicImprovingStatus : status,
                          style: AppTextStyles.small,
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
                        color: AppColors.green,
                        backgroundColor: AppColors.track,
                        semanticsLabel: status,
                      ),
                    ),
                    if (improving)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(status, style: AppTextStyles.small),
                      ),
                  ],
                  // NUEVO: prioridad derivada de la parte de usos correctos
                  // (no hay un dato de prioridad en la memoria): solo en la
                  // lista de prioridades.
                  if (rank != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _PriorityChip(share: view.correctShare),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

// NUEVO: el puesto en la lista de prioridades, en un círculo menta.
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.mint,
      shape: BoxShape.circle,
    ),
    child: Text(
      '$rank',
      style: AppTextStyles.rowTitle.copyWith(color: AppColors.greenDark),
    ),
  );
}

// NUEVO: etiqueta Alta / Media / Baja según la parte de usos correctos
// (menos de un tercio: alta; menos de dos tercios: media; si no, baja).
class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, background, foreground) = share < 0.34
        ? (l.priorityHigh, AppColors.terraBg, AppColors.terraText)
        : share < 0.67
        ? (l.priorityMedium, AppColors.amberBg, AppColors.amberText)
        : (l.priorityLow, AppColors.mint, AppColors.greenDark);
    return Semantics(
      label: l.priorityLabel(label),
      excludeSemantics: true,
      child: StatusChip(
        label: label,
        background: background,
        foreground: foreground,
      ),
    );
  }
}
