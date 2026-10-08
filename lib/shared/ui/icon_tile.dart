import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

// NUEVO: cuadro con esquinas redondeadas y un icono centrado (accesos
// rápidos de Inicio, filas de Aprender).
class IconTile extends StatelessWidget {
  const IconTile({
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 40,
    this.radius = 12,
    super.key,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: size * 0.55, color: foreground),
    ),
  );
}

// NUEVO: círculo con un icono (botones redondos de cabecera y de voz).
class IconCircle extends StatelessWidget {
  const IconCircle({
    required this.icon,
    required this.size,
    this.background = AppColors.surface,
    this.foreground = AppColors.greenDark,
    this.border,
    this.iconSize,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;
  final Color? border;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: background,
      shape: BoxShape.circle,
      border: border == null ? null : Border.all(color: border!),
    ),
    child: Icon(icon, size: iconSize ?? size * 0.5, color: foreground),
  );
}
