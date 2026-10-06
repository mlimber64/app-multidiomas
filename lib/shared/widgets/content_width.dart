import 'package:flutter/widgets.dart';

import '../../app/theme/app_tokens.dart';

/// Centers content and caps its width so layouts don't stretch on wide
/// screens (landscape, foldables).
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
      child: child,
    ),
  );
}
