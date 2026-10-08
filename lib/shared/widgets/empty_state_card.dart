import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';
import '../ui/ui.dart';

/// A friendly "nothing here yet" block: it should read as the start of
/// something, not as something broken. No numbers, no zeros.
/// Rediseño: tarjeta blanca con un círculo menta para el icono.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconCircle(
              icon: icon,
              size: 52,
              iconSize: 28,
              background: AppColors.mint,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: AppTextStyles.body),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
