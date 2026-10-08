import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

// NUEVO: tarjeta blanca del diseño: borde de 1 px, sin sombra salvo que se
// pida, radio configurable y feedback sutil al tocar.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.radius = AppRadius.card,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.shadow,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;

  /// Para tarjetas que son un solo botón (se anuncian como botón).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: content,
      );
    }
    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
        boxShadow: shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
    if (onTap != null && semanticLabel != null) {
      card = Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

// NUEVO: tarjeta grande celeste (hero) con la sombra azul del diseño.
class CelesteHeroCard extends StatelessWidget {
  const CelesteHeroCard({
    required this.child,
    this.radius = AppRadius.hero,
    this.padding = const EdgeInsets.all(22),
    this.onTap,
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: radius,
    padding: padding,
    color: AppColors.celeste,
    borderColor: Colors.transparent,
    shadow: AppShadows.hero,
    onTap: onTap,
    child: child,
  );
}
