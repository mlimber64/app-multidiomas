import 'package:flutter/material.dart';

import 'app_tokens.dart';

// NUEVO: estilos de texto del rediseño. Fraunces para títulos y números
// grandes, Nunito para todo lo demás. Son fuentes variables: además del
// `fontWeight` se fija el eje `wght` (y `opsz` en Fraunces) para que el peso
// exacto del diseño se vea igual en cualquier dispositivo.
abstract final class AppTextStyles {
  static const _fraunces = 'Fraunces';
  static const _nunito = 'Nunito';

  static FontWeight _weight(int w) => FontWeight.values[(w ~/ 100) - 1];

  static TextStyle _serif(
    double size,
    int weight, {
    double height = 1.2,
    Color color = AppColors.ink,
  }) => TextStyle(
    fontFamily: _fraunces,
    fontSize: size,
    fontWeight: _weight(weight),
    height: height,
    color: color,
    fontVariations: [
      FontVariation('wght', weight.toDouble()),
      FontVariation('opsz', size.clamp(9, 144).toDouble()),
    ],
  );

  static TextStyle _sans(
    double size,
    int weight, {
    double height = 1.35,
    Color color = AppColors.ink,
    double letterSpacing = 0,
    FontStyle? fontStyle,
  }) => TextStyle(
    fontFamily: _nunito,
    fontSize: size,
    fontWeight: _weight(weight),
    height: height,
    color: color,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );

  // --- Títulos (Fraunces) ---------------------------------------------------

  /// Título de pantalla: 32 / 700, interlineado 1.1.
  static final screenTitle = _serif(32, 700, height: 1.1);

  /// Título de la pantalla Hablar: 28 / 700.
  static final chatTitle = _serif(28, 700, height: 1.1);

  /// Título de sección: 22 / 700.
  static final sectionTitle = _serif(22, 700);

  /// Título de hero: 26 / 700 (ejercicio, práctica).
  static final heroTitle = _serif(26, 700, height: 1.2, color: AppColors.navy);

  /// Título de hero del nivel: 24 / 700.
  static final heroTitleLevel = _serif(
    24,
    700,
    height: 1.2,
    color: AppColors.navy,
  );

  /// Título de hero del perfil: 22 / 700.
  static final heroTitleProfile = _serif(
    22,
    700,
    height: 1.2,
    color: AppColors.navy,
  );

  /// Palabra destacada: 40 / 700.
  static final word = _serif(40, 700, height: 1.1, color: AppColors.greenDark);

  /// Número de estadística: 30 / 700.
  static final statNumber = _serif(
    30,
    700,
    height: 1.1,
    color: AppColors.greenDark,
  );

  // --- Texto (Nunito) -------------------------------------------------------

  /// Subtítulo de pantalla: 15 / 600, muted.
  static final screenSubtitle = _sans(15, 600, color: AppColors.muted);

  /// Etiqueta en mayúsculas: 12 / 800, letterSpacing 0.08em (≈ 1.0).
  /// El texto debe pasarse ya en mayúsculas.
  static final eyebrow = _sans(
    12,
    800,
    color: AppColors.muted,
    letterSpacing: 1.0,
  );

  /// Texto de chat: 17 / 700, interlineado 1.45.
  static final chat = _sans(17, 700, height: 1.45);

  /// Cuerpo / título de fila: 15–16 / 800.
  static final rowTitle = _sans(15, 800);
  static final bodyStrong = _sans(16, 800);

  /// Texto secundario: 13–14 / 600.
  static final body = _sans(14, 600, height: 1.4);
  static final small = _sans(13, 600, color: AppColors.muted);

  /// Etiqueta del nav: 11 / 700 (activa 800).
  static final navLabel = _sans(11, 700, height: 1.2, color: AppColors.muted);
  static final navLabelActive = _sans(
    11,
    800,
    height: 1.2,
    color: AppColors.greenDark,
  );

  /// Texto de chips y botones pequeños: 13 / 800.
  static final chip = _sans(13, 800, height: 1.2);

  /// Etiqueta de estado: 12 / 800.
  static final status = _sans(12, 800, height: 1.2);

  /// Botón primario: 16 / 800.
  static final button = _sans(16, 800, height: 1.2);

  /// Cursiva secundaria (traducciones): 14 / 600.
  static final italic = _sans(
    14,
    600,
    height: 1.4,
    color: AppColors.muted,
    fontStyle: FontStyle.italic,
  );

  // --- Tema de Material -----------------------------------------------------

  /// Los estilos de Material con las fuentes del diseño, para que cualquier
  /// widget que lea el tema (también las pantallas aún no rediseñadas) herede
  /// la tipografía.
  static TextTheme get textTheme => TextTheme(
    displayLarge: _serif(40, 700, height: 1.1),
    displayMedium: _serif(36, 700, height: 1.1),
    displaySmall: screenTitle,
    headlineLarge: screenTitle,
    headlineMedium: screenTitle.copyWith(fontSize: 28),
    headlineSmall: _serif(24, 700, height: 1.2),
    titleLarge: sectionTitle,
    titleMedium: _sans(16, 800),
    titleSmall: _sans(14, 800),
    bodyLarge: _sans(16, 600, height: 1.4),
    bodyMedium: _sans(14, 600, height: 1.4),
    bodySmall: _sans(13, 600, height: 1.4, color: AppColors.muted),
    labelLarge: _sans(14, 800, height: 1.2),
    labelMedium: _sans(12, 700, height: 1.2),
    labelSmall: _sans(11, 700, height: 1.2),
  );
}
