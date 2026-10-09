import 'package:flutter/material.dart';

// NUEVO: paleta del rediseño. Todos los colores de la interfaz salen de aquí,
// con los nombres del sistema de diseño (crema, verde, celeste, ámbar...).
abstract final class AppColors {
  // Superficies y bordes.
  static const bg = Color(0xFFFBF7F0); // Fondo de todas las pantallas
  static const surface = Color(0xFFFFFFFF); // Tarjetas, nav, campos
  static const border = Color(0xFFE7E1D6); // Borde de tarjetas y nav
  static const surfaceSoft = Color(0xFFF1ECE2); // Franja y segmented control
  static const surfaceCream = Color(0xFFFFFCF6); // Accesos rápidos de Inicio
  static const divider = Color(0xFFEFE9DD); // Divisores, días futuros
  static const track = Color(0xFFE2DCCF); // Segmentos vacíos de palabra
  static const inputBorderIdle = Color(0xFFCFC8BA); // Chips de acción
  static const inputAreaBorder = Color(0xFFEDE6D9); // Línea sobre el input

  // Texto.
  static const ink = Color(0xFF1B2A22);
  static const muted = Color(0xFF5B6B62);
  static const placeholder = Color(0xFF6F7C74);

  // Verde: solo acentos.
  static const green = Color(0xFF1A5C42);
  static const greenDark = Color(0xFF14472F);
  static const mint = Color(0xFFD7EBDD);
  static const mintSoft = Color(0xFFEEF7F1);
  static const mintBorder = Color(0xFFCFE6D6);

  // Celeste: tarjetas grandes.
  static const celeste = Color(0xFFBDE3F6);
  static const navy = Color(0xFF0F3A57);
  static const blueText = Color(0xFF2F5E7C);
  static const blue = Color(0xFF1F6F9F);
  static const blueBorder = Color(0xFF7FB8DA);

  // Corrección.
  static const feedbackBg = Color(0xFFE3F1FB);
  static const feedbackBorder = Color(0xFFBFDDF1);
  static const feedbackText = Color(0xFF12384F);
  static const feedbackAccent = Color(0xFF12507A);
  static const feedbackChipBorder = Color(0xFF9CC9E6);
  static const feedbackSub = Color(0xFF4A6577);

  // Estados.
  static const amberBg = Color(0xFFFFF0D2);
  static const amberText = Color(0xFF7A4B00);
  static const terraBg = Color(0xFFF6E3DC);
  static const terraText = Color(0xFF8A3A22);
  static const errorStrike = Color(0xFFB3452B);
  static const errorText = Color(0xFF6B4A43);

  // Derivados con transparencia, tal como los define el diseño.
  /// Segmento vacío de la barra de la práctica (navy al 18 %).
  static const heroTrack = Color(0x2E0F3A57);

  /// Pista del anillo de nivel (navy al 15 %).
  static const ringTrack = Color(0x260F3A57);

  /// Pills y opciones sobre celeste (blanco al 55 % y 60 %).
  static const onCelesteSoft = Color(0x8CFFFFFF);
  static const onCelesteOption = Color(0x99FFFFFF);

  /// Chip del tema sobre celeste (blanco al 65 %).
  static const onCelesteChip = Color(0xA6FFFFFF);

  /// Sombras del diseño.
  static const heroShadow = Color(0x2E1F6F9F);
  static const wordShadow = Color(0x0F1B2A22);
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

  // NUEVO: radios del rediseño.
  /// Hero celeste y tarjeta de palabra.
  static const hero = 28.0;

  /// Tarjetas medianas.
  static const card = 24.0;

  /// Listas, switch y voz.
  static const panel = 22.0;

  /// Tarjetas pequeñas y filas.
  static const tile = 20.0;

  /// Botones primarios (alto 52).
  static const button = 26.0;
}

abstract final class AppSizes {
  /// Comfortable touch target for primary selectable rows and actions.
  static const minTouch = 56.0;

  /// Content is centered and capped on wide screens instead of stretching.
  static const maxContentWidth = 560.0;

  // NUEVO: medidas del rediseño.
  /// Área táctil mínima, aunque el chip visual sea más pequeño.
  static const tapTarget = 44.0;

  /// Alto de los botones primarios y del campo de texto.
  static const control = 52.0;

  /// Alto de la barra de navegación inferior sin la zona segura.
  static const navHeight = 68.0;
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

// NUEVO: sombras del diseño (el resto de tarjetas va solo con borde).
abstract final class AppShadows {
  /// Hero celeste.
  static const hero = [
    BoxShadow(
      color: AppColors.heroShadow,
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  /// Hero de la práctica ya completada (verde suave).
  static const success = [
    BoxShadow(color: Color(0x331A5C42), blurRadius: 24, offset: Offset(0, 10)),
  ];

  /// Tarjeta "Hablemos" (verde).
  static const talk = [
    BoxShadow(color: Color(0x331A5C42), blurRadius: 20, offset: Offset(0, 8)),
  ];

  /// Tarjeta de palabra.
  static const word = [
    BoxShadow(
      color: AppColors.wordShadow,
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  /// Ítem seleccionado del control segmentado.
  static const segment = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1)),
  ];
}
