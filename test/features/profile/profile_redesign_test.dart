import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/profile/domain/language_pair.dart';
import 'package:parla_con_me/features/profile/presentation/profile_labels.dart';
import 'package:parla_con_me/shared/ui/ui.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

void main() {
  test('hay una frase de prueba de voz para cada idioma', () {
    for (final language in AppLanguage.values) {
      expect(voiceSampleText(language), isNotEmpty, reason: language.name);
    }
  });

  testWidgets('Perfil: filas de ajustes, probar voz y pie con candado', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryLocalStorage(), profile: onboardedProfile);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Profilo'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsRow), findsNWidgets(6));
    expect(find.text('Prova la voce'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byIcon(Icons.lock_outline),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
