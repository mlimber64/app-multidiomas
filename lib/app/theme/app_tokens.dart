import 'package:flutter/material.dart';

/// Brand palette: Italian-inspired but modern. Green is the primary
/// identity, terracotta the warm accent, on a soft cream surface.
abstract final class AppColors {
  static const primary = Color(0xFF1F7A5A); // basil green
  static const accent = Color(0xFFD9653B); // terracotta
  static const cream = Color(0xFFFAF6EE);
  static const ink = Color(0xFF1B2B26);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 24.0;
  static const pill = 999.0;
}

abstract final class AppSizes {
  /// Comfortable touch target for primary selectable rows and actions.
  static const minTouch = 56.0;

  /// Content is centered and capped on wide screens instead of stretching.
  static const maxContentWidth = 560.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 300);
}

abstract final class AppElevation {
  static const none = 0.0;
  static const card = 1.0;
  static const raised = 3.0;
}
