import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/shared/ui/ui.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

// El título de pantalla: la AppBar o, en las pantallas rediseñadas, el
// ScreenHeader.
final _screenTitle = find.byWidgetPredicate(
  (w) => w is AppBar || w is ScreenHeader,
);

void main() {
  testWidgets('Home shows the saved profile and an honest empty state', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryLocalStorage(), profile: onboardedProfile);

    expect(find.text('IL TUO PERCORSO'), findsOneWidget);
    expect(find.text('A2 · Elementare'), findsOneWidget);
    expect(find.text('Conversazione'), findsWidgets);
    // Sin memoria todavía: los accesos lo dicen con honestidad, sin números.
    expect(find.text('Tutto in ordine'), findsOneWidget);
    expect(find.text('Il tuo vocabolario'), findsOneWidget);
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
      // Los accesos son AppCard: así no se confunden con las etiquetas,
      // iguales, de la barra inferior.
      await tester.tap(
        find.descendant(of: find.byType(AppCard), matching: find.text(text)),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _screenTitle, matching: find.text(expectedTitle)),
        findsOneWidget,
        reason: text,
      );
    }

    await goHomeAndTap('Parliamo', 'Parla');
    await goHomeAndTap('Impara', 'Impara');
    await goHomeAndTap('Parole', 'Parole');
  });
}
