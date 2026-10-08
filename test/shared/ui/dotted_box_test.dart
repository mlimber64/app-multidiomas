import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/shared/ui/ui.dart';

void main() {
  testWidgets('DottedBox pinta su contenido con un borde punteado', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Center(child: DottedBox(child: Text('hueco'))),
      ),
    );
    expect(find.text('hueco'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DottedBox),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    expect(t.takeException(), isNull);
  });
}
