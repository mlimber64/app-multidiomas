import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/shared/ui/app_bottom_nav.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('Home shows the saved profile and an honest empty state', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryLocalStorage(), profile: onboardedProfile);

    expect(find.text('Il tuo percorso'), findsOneWidget);
    expect(find.text('A2 — Elementare'), findsOneWidget);
    expect(find.text('Parlare con più sicurezza'), findsOneWidget);
    expect(find.text('Conversazione'), findsWidgets);
    expect(find.text('Il tuo percorso inizia qui.'), findsOneWidget);
  });

  testWidgets('main CTA and quick actions navigate to their areas', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryLocalStorage(), profile: onboardedProfile);

    Future<void> goHomeAndTap(String text, String expectedTitle) async {
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text('Home'),
        ),
      );
      await tester.pumpAndSettle();
      // Quick actions are Cards; the hero CTA is not. This avoids matching
      // the identically named bottom-navigation labels.
      final inCard = find.descendant(
        of: find.byType(Card),
        matching: find.text(text),
      );
      await tester.tap(inCard.evaluate().isNotEmpty ? inCard : find.text(text));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(expectedTitle),
        ),
        findsOneWidget,
        reason: text,
      );
    }

    await goHomeAndTap('Parliamo', 'Parla');
    await goHomeAndTap('Impara', 'Impara');
    await goHomeAndTap('Parole', 'Parole');
  });
}
