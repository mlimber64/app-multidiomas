import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/theme/app_text_styles.dart';
import 'package:parla_con_me/app/theme/app_theme.dart';
import 'package:parla_con_me/app/theme/app_tokens.dart';
import 'package:parla_con_me/shared/ui/ui.dart';

// Rediseño, fase 1: tokens, tipografía, tema y componentes reutilizables.

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('tokens y tema', () {
    test('los colores del diseño tienen los valores indicados', () {
      expect(AppColors.bg, const Color(0xFFFBF7F0));
      expect(AppColors.celeste, const Color(0xFFBDE3F6));
      expect(AppColors.green, const Color(0xFF1A5C42));
      expect(AppColors.greenDark, const Color(0xFF14472F));
      expect(AppColors.navy, const Color(0xFF0F3A57));
      expect(AppColors.feedbackBg, const Color(0xFFE3F1FB));
      expect(AppColors.errorStrike, const Color(0xFFB3452B));
    });

    test('el tema usa el fondo crema y el verde como color primario', () {
      final theme = AppTheme.light;
      expect(theme.scaffoldBackgroundColor, AppColors.bg);
      expect(theme.colorScheme.primary, AppColors.green);
      expect(theme.colorScheme.secondary, AppColors.blue);
      expect(theme.colorScheme.surface, AppColors.surface);
      expect(theme.useMaterial3, isTrue);
    });

    test('Fraunces en títulos y Nunito en el resto', () {
      final text = AppTheme.light.textTheme;
      expect(text.titleLarge?.fontFamily, 'Fraunces');
      expect(text.headlineMedium?.fontFamily, 'Fraunces');
      expect(text.bodyMedium?.fontFamily, 'Nunito');
      expect(text.labelLarge?.fontFamily, 'Nunito');
      expect(AppTextStyles.word.fontFamily, 'Fraunces');
      expect(AppTextStyles.chat.fontFamily, 'Nunito');
    });

    test('los tamaños y pesos de la tipografía son los del diseño', () {
      expect(AppTextStyles.screenTitle.fontSize, 32);
      expect(AppTextStyles.chatTitle.fontSize, 28);
      expect(AppTextStyles.sectionTitle.fontSize, 22);
      expect(AppTextStyles.word.fontSize, 40);
      expect(AppTextStyles.statNumber.fontSize, 30);
      expect(AppTextStyles.chat.fontSize, 17);
      expect(AppTextStyles.chat.height, 1.45);
      expect(AppTextStyles.navLabel.fontSize, 11);
      expect(AppTextStyles.navLabel.fontWeight, FontWeight.w700);
      expect(AppTextStyles.navLabelActive.fontWeight, FontWeight.w800);
      expect(AppTextStyles.eyebrow.fontWeight, FontWeight.w800);
    });

    test('las fuentes están empaquetadas y declaradas', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: Nunito'));
      expect(pubspec, contains('family: Fraunces'));
      for (final f in [
        'assets/fonts/Nunito-Variable.ttf',
        'assets/fonts/Nunito-Italic-Variable.ttf',
        'assets/fonts/Fraunces-Variable.ttf',
      ]) {
        expect(File(f).existsSync(), isTrue, reason: f);
        expect(pubspec, contains(f));
      }
    });

    test('el tema oscuro sigue existiendo y no usa el rediseño', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.dark.scaffoldBackgroundColor, isNot(AppColors.bg));
    });
  });

  group('componentes', () {
    testWidgets('AppCard: borde de 1 px, radio y toque', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AppCard(
            radius: AppRadius.panel,
            onTap: () => taps++,
            child: const Text('hola'),
          ),
        ),
      );
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, AppColors.surface);
      expect(decoration.border, Border.all(color: AppColors.border));
      expect(decoration.borderRadius, BorderRadius.circular(AppRadius.panel));
      expect(decoration.boxShadow, isNull);
      await tester.tap(find.text('hola'));
      expect(taps, 1);
    });

    testWidgets('CelesteHeroCard: celeste, radio 28 y sombra azul', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const CelesteHeroCard(child: Text('x'))));
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(CelesteHeroCard),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, AppColors.celeste);
      expect(decoration.borderRadius, BorderRadius.circular(28));
      expect(decoration.boxShadow, AppShadows.hero);
      expect(AppShadows.hero.single.blurRadius, 24);
      expect(AppShadows.hero.single.offset, const Offset(0, 10));
    });

    testWidgets('PrimaryButton: alto 52, toque y estado deshabilitado', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PrimaryButton(
            label: 'Practicar',
            trailingIcon: Icons.arrow_forward,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(tester.getSize(find.byType(PrimaryButton)).height, 52);
      await tester.tap(find.text('Practicar'));
      expect(taps, 1);

      await tester.pumpWidget(
        _host(const PrimaryButton(label: 'Practicar', onPressed: null)),
      );
      await tester.tap(find.text('Practicar'));
      expect(taps, 1, reason: 'deshabilitado no responde');
    });

    testWidgets('PrimaryButton: las tres variantes tienen sus colores', (
      tester,
    ) async {
      Color? fill(PrimaryButtonVariant v) {
        return tester
            .widget<Material>(
              find.descendant(
                of: find.byType(PrimaryButton),
                matching: find.byType(Material),
              ),
            )
            .color;
      }

      for (final (variant, color) in [
        (PrimaryButtonVariant.blue, AppColors.blue),
        (PrimaryButtonVariant.green, AppColors.green),
        (PrimaryButtonVariant.outlinedGreen, AppColors.surface),
      ]) {
        await tester.pumpWidget(
          _host(PrimaryButton(label: 'x', onPressed: () {}, variant: variant)),
        );
        expect(fill(variant), color, reason: '$variant');
      }
    });

    testWidgets('AppActionChip: 34 de alto visual y 44 de área táctil', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppActionChip(label: 'Escuchar', onPressed: () => taps++)),
      );
      expect(tester.getSize(find.byType(AppActionChip)).height, 44);
      final visual = tester.getSize(
        find
            .descendant(
              of: find.byType(AppActionChip),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(visual.height, 34);
      // Un toque en la franja de 5 px sobre el chip visual también cuenta.
      final top = tester.getTopLeft(find.byType(AppActionChip));
      await tester.tapAt(top + const Offset(20, 2));
      expect(taps, 1);
    });

    testWidgets('AppActionChip seleccionado se anuncia como seleccionado', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AppActionChip(
            label: 'Corrígeme',
            variant: AppActionChipVariant.neutral,
            selected: true,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AppActionChip)),
        matchesSemantics(
          label: 'Corrígeme',
          isButton: true,
          isEnabled: true,
          isSelected: true,
          hasEnabledState: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('StatusChip: texto, icono y colores', (tester) async {
      await tester.pumpWidget(
        _host(
          const StatusChip(
            label: 'Por consolidar',
            icon: Icons.bookmark,
            background: AppColors.amberBg,
            foreground: AppColors.amberText,
          ),
        ),
      );
      expect(find.text('Por consolidar'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      final text = tester.widget<Text>(find.text('Por consolidar'));
      expect(text.style?.color, AppColors.amberText);
      expect(text.style?.fontSize, 12);
    });

    testWidgets('SegmentedPills: cambia al tocar otro ítem', (tester) async {
      var value = 'a';
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _host(
            SizedBox(
              width: 320,
              child: SegmentedPills<String>(
                items: const [('a', 'Uno'), ('b', 'Dos'), ('c', 'Tres')],
                selected: value,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );
      Color? colorOf(String label) {
        final container = tester.widget<AnimatedContainer>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          ),
        );
        return (container.decoration as BoxDecoration).color;
      }

      expect(colorOf('Uno'), Colors.white);
      expect(colorOf('Dos'), Colors.transparent);
      await tester.tap(find.text('Dos'));
      await tester.pumpAndSettle();
      expect(value, 'b');
      expect(colorOf('Dos'), Colors.white);
      expect(colorOf('Uno'), Colors.transparent);
    });

    testWidgets('SegmentProgress: tantos segmentos llenos como se piden', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 200,
            child: SegmentProgress(total: 3, filled: 2),
          ),
        ),
      );
      final colors = [
        for (final c in tester.widgetList<AnimatedContainer>(
          find.byType(AnimatedContainer),
        ))
          (c.decoration as BoxDecoration).color,
      ];
      expect(colors, [AppColors.green, AppColors.green, AppColors.track]);
    });

    testWidgets('IconTile e IconCircle dibujan su icono', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              IconTile(
                icon: Icons.school,
                background: AppColors.mint,
                foreground: AppColors.greenDark,
                size: 40,
              ),
              IconCircle(icon: Icons.volume_up, size: 44),
            ],
          ),
        ),
      );
      expect(find.byIcon(Icons.school), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(tester.getSize(find.byType(IconTile)), const Size(40, 40));
      expect(tester.getSize(find.byType(IconCircle)), const Size(44, 44));
    });

    testWidgets('SettingsList: filas con divisores y toque', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          SettingsList(
            children: [
              SettingsRow(label: 'Nivel', value: 'A1', onTap: () => taps++),
              SettingsRow(label: 'Áreas', value: 'Conversación', onTap: () {}),
            ],
          ),
        ),
      );
      expect(find.byType(Divider), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
      await tester.tap(find.text('A1'));
      expect(taps, 1);
    });

    testWidgets('ScreenHeader: título, subtítulo y widget a la derecha', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 360,
            child: ScreenHeader(
              title: 'Hablar',
              subtitle: 'Italiano',
              trailing: Icon(Icons.add_comment),
            ),
          ),
        ),
      );
      expect(find.text('Hablar'), findsOneWidget);
      expect(find.text('Italiano'), findsOneWidget);
      expect(find.byIcon(Icons.add_comment), findsOneWidget);
    });

    testWidgets('con el texto del sistema al 200 % nada se desborda', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 340,
            child: Column(
              children: [
                PrimaryButton(label: 'Empezar práctica', onPressed: () {}),
                const Wrap(
                  spacing: 8,
                  children: [
                    StatusChip(label: 'Por consolidar', icon: Icons.bookmark),
                    StatusChip(label: 'Alta'),
                  ],
                ),
                AppActionChip(label: 'Escuchar', onPressed: () {}),
              ],
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
