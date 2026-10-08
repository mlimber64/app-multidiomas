import 'package:flutter/material.dart';

import 'app_text_styles.dart';
import 'app_tokens.dart';

/// Light theme of the redesign, built from the design tokens. The dark theme
/// is the one the app had before and is not part of the redesign (the app is
/// shown in light mode, see `ParlaConMeApp`).
///
/// Component conventions: cards are white with a 1 px border and no shadow,
/// primary buttons are 52 high with a 26 radius; screens pad with 20.
abstract final class AppTheme {
  // NUEVO: tema claro del rediseño.
  static ThemeData get light => _light();

  /// Not touched by the redesign: the app as it was, in dark.
  static ThemeData get dark => _legacyDark();

  static ThemeData _light() {
    // NUEVO: el esquema parte de la semilla verde y fija los tokens del diseño
    // en los roles que usan las pantallas aún no rediseñadas.
    final seeded = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
    );
    final scheme = seeded.copyWith(
      primary: AppColors.green,
      onPrimary: Colors.white,
      primaryContainer: AppColors.mint,
      onPrimaryContainer: AppColors.greenDark,
      secondary: AppColors.blue,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.celeste,
      onSecondaryContainer: AppColors.navy,
      tertiaryContainer: AppColors.feedbackBg,
      onTertiaryContainer: AppColors.feedbackText,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.bg,
      surfaceContainer: AppColors.surfaceSoft,
      surfaceContainerHigh: AppColors.surfaceSoft,
      surfaceContainerHighest: AppColors.divider,
      outline: AppColors.border,
      outlineVariant: AppColors.divider,
      error: AppColors.errorStrike,
      errorContainer: AppColors.terraBg,
      onErrorContainer: AppColors.terraText,
    );
    final text = AppTextStyles.textTheme;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: 'Nunito',
      textTheme: text,
      primaryTextTheme: text,
    );

    final radius26 = BorderRadius.circular(AppRadius.button);
    OutlineInputBorder inputBorder(Color color, [double width = 1.5]) =>
        OutlineInputBorder(
          borderRadius: radius26,
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      dividerColor: AppColors.divider,
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      splashColor: AppColors.green.withValues(alpha: 0.08),
      highlightColor: AppColors.green.withValues(alpha: 0.04),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.ink,
        iconTheme: const IconThemeData(color: AppColors.greenDark),
        titleTextStyle: AppTextStyles.screenTitle.copyWith(fontSize: 28),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(AppSizes.control),
          shape: RoundedRectangleBorder(borderRadius: radius26),
          textStyle: AppTextStyles.button,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(AppSizes.control),
          shape: RoundedRectangleBorder(borderRadius: radius26),
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.greenDark,
          backgroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(AppSizes.control),
          side: const BorderSide(color: AppColors.green, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: radius26),
          textStyle: AppTextStyles.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          textStyle: AppTextStyles.bodyStrong,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.greenDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppTextStyles.bodyStrong.copyWith(
          color: AppColors.placeholder,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        border: inputBorder(AppColors.inputBorderIdle),
        enabledBorder: inputBorder(AppColors.inputBorderIdle),
        focusedBorder: inputBorder(AppColors.green),
        errorBorder: inputBorder(AppColors.errorStrike),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.green
              : AppColors.track,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.mint,
        side: const BorderSide(color: AppColors.inputBorderIdle),
        shape: const StadiumBorder(),
        labelStyle: AppTextStyles.chip,
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: AppTextStyles.bodyStrong,
        subtitleTextStyle: AppTextStyles.small,
        iconColor: AppColors.muted,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.blue,
        linearTrackColor: AppColors.track,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.hero),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
      ),
    );
  }

  /// The theme the app had before the redesign, kept for dark mode.
  static ThemeData _legacyDark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      secondary: AppColors.terraText,
      brightness: Brightness.dark,
    );
    final base = ThemeData(brightness: Brightness.dark, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
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
}
