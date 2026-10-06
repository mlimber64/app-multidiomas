import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_local_storage.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('returning user lands on Home and can switch areas', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryLocalStorage(), profile: onboardedProfile);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Iniziamo'), findsNothing);
    expect(find.text('Ciao! 👋'), findsOneWidget);

    for (final area in ['Parla', 'Impara', 'Parole', 'Percorso', 'Profilo']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(area),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(area)),
        findsOneWidget,
        reason: area,
      );
    }
  });
}
