import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/shared/ui/ui.dart';

void main() {
  testWidgets('ProgressRing muestra el texto central y su etiqueta', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ProgressRing(
            value: 0.5,
            centerText: '1/2',
            semanticLabel: '1 de 2 áreas',
          ),
        ),
      ),
    );
    expect(find.text('1/2'), findsOneWidget);
    expect(find.bySemanticsLabel('1 de 2 áreas'), findsOneWidget);
    expect(t.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('ProgressRing tolera valores fuera de rango', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            ProgressRing(value: -1, centerText: '0'),
            ProgressRing(value: 3, centerText: '1'),
          ],
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });
}
