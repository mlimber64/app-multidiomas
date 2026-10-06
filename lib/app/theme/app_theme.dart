import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Light and dark themes derived from the same tokens. The app follows the
/// system setting (`ThemeMode.system`).
///
/// Component conventions: cards and inputs use [AppRadius.md], buttons use
/// [AppRadius.pill]; screens pad with [AppSpacing.md]. Prefer theme styles
/// over per-widget overrides.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      secondary: AppColors.accent,
      brightness: brightness,
    );
    final isLight = brightness == Brightness.light;
    final base = ThemeData(brightness: brightness, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: isLight ? AppColors.cream : scheme.surface,
      textTheme: _textTheme(base.textTheme),
      cardTheme: CardThemeData(
        elevation: AppElevation.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }

  /// Typography uses the platform font (no font package) with heavier,
  /// tighter headings for a friendly-but-not-childish tone.
  static TextTheme _textTheme(TextTheme t) => t.copyWith(
    headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: t.bodyLarge?.copyWith(height: 1.4),
  );
}
