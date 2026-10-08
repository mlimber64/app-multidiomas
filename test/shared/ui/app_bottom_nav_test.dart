import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/theme/app_theme.dart';
import 'package:parla_con_me/app/theme/app_tokens.dart';
import 'package:parla_con_me/shared/ui/ui.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

// Rediseño, fase 2: la barra de navegación inferior compartida.

const _items = [
  AppBottomNavItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Inicio',
  ),
  AppBottomNavItem(
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    label: 'Hablar',
  ),
  AppBottomNavItem(
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    label: 'Aprender',
  ),
];

Widget _host({required int selected, required ValueChanged<int> onSelected}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      bottomNavigationBar: AppBottomNav(
        items: _items,
        selectedIndex: selected,
        onSelected: onSelected,
      ),
    ),
  );
}

void main() {
  group('AppBottomNav', () {
    testWidgets('el activo lleva la píldora mint, icono relleno y texto 800', (
      tester,
    ) async {
      await tester.pumpWidget(_host(selected: 1, onSelected: (_) {}));

      // Icono relleno solo en el activo; los demás, contorno.
      expect(find.byIcon(Icons.chat_bubble), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);

      Color? pill(String label) {
        final box = tester.widget<AnimatedContainer>(
          find
              .ancestor(
                of: find.byIcon(
                  label == 'Hablar' ? Icons.chat_bubble : Icons.home_outlined,
                ),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        return (box.decoration as BoxDecoration).color;
      }

      expect(pill('Hablar'), AppColors.mint);
      expect(pill('Inicio'), Colors.transparent);

      final active = tester.widget<Text>(find.text('Hablar'));
      final idle = tester.widget<Text>(find.text('Inicio'));
      expect(active.style?.fontWeight, FontWeight.w800);
      expect(active.style?.color, AppColors.greenDark);
      expect(idle.style?.fontWeight, FontWeight.w700);
      expect(idle.style?.color, AppColors.muted);
      expect(active.style?.fontSize, 11);
    });

    testWidgets('la píldora mide 56 × 30', (tester) async {
      await tester.pumpWidget(_host(selected: 0, onSelected: (_) {}));
      final size = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.home),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(size, const Size(56, 30));
    });

    testWidgets('tocar un destino avisa de su índice', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(_host(selected: 0, onSelected: tapped.add));
      await tester.tap(find.text('Aprender'));
      await tester.tap(find.text('Inicio'));
      expect(tapped, [2, 0]);
    });

    testWidgets('cada destino es un botón con área táctil de 44 o más', (
      tester,
    ) async {
      await tester.pumpWidget(_host(selected: 0, onSelected: (_) {}));
      for (final label in ['Inicio', 'Hablar', 'Aprender']) {
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        expect(node.getSemanticsData().label, label);
        final size = tester.getSize(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        );
        expect(size.height, greaterThanOrEqualTo(44), reason: label);
        expect(size.width, greaterThanOrEqualTo(44), reason: label);
      }
      expect(
        tester.getSemantics(find.bySemanticsLabel('Inicio')),
        isSemantics(isSelected: true, isButton: true),
      );
    });

    testWidgets('tiene borde superior de 1 px y fondo blanco', (tester) async {
      await tester.pumpWidget(_host(selected: 0, onSelected: (_) {}));
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppBottomNav),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, AppColors.surface);
      expect(
        decoration.border,
        const Border(top: BorderSide(color: AppColors.border)),
      );
    });

    testWidgets('con el texto del sistema al 200 % no se desborda', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: AppBottomNav(
              items: _items,
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('la app muestra la misma barra en las seis pestañas, con la '
      'activa marcada', (tester) async {
    await pumpApp(tester, InMemoryLocalStorage(), profile: onboardedProfile);
    final tabs = ['Home', 'Parla', 'Impara', 'Parole', 'Percorso', 'Profilo'];
    for (var i = 0; i < tabs.length; i++) {
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text(tabs[i]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomNav), findsOneWidget, reason: tabs[i]);
      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.selectedIndex, i, reason: tabs[i]);
      expect(nav.items.map((e) => e.label), tabs);
    }
  });
}
