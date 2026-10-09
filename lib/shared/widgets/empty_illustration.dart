import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../ui/ui.dart';

/// The small picture of an empty state, drawn with icons: a big mint circle
/// with [icon], a blue badge ([badge]) at the top right and an amber spark
/// ([spark]) at the bottom left. Decorative: it says nothing a screen reader
/// needs, so it is left out of the semantics.
class EmptyIllustration extends StatelessWidget {
  const EmptyIllustration({
    required this.icon,
    this.badge = Icons.chat_bubble,
    this.spark = Icons.auto_awesome,
    super.key,
  });

  final IconData icon;
  final IconData badge;
  final IconData spark;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 132,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconCircle(
            icon: icon,
            size: 96,
            iconSize: 48,
            background: AppColors.mint,
            foreground: AppColors.greenDark,
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconCircle(
              icon: badge,
              size: 40,
              iconSize: 20,
              background: AppColors.feedbackBg,
              foreground: AppColors.feedbackAccent,
              border: AppColors.surface,
            ),
          ),
          Positioned(
            left: 4,
            bottom: 2,
            child: IconCircle(
              icon: spark,
              size: 32,
              iconSize: 17,
              background: AppColors.amberBg,
              foreground: AppColors.amberText,
              border: AppColors.surface,
            ),
          ),
        ],
      ),
    ),
  );
}
