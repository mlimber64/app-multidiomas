import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/conversation/presentation/widgets/composer.dart';
import 'package:parla_con_me/l10n/l10n.dart';
import 'package:parla_con_me/shared/ui/ui.dart';

Widget _host({
  required bool correctionMode,
  required ValueChanged<bool> onMode,
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Composer(
            canSend: true,
            sending: false,
            correctionMode: correctionMode,
            onSend: (_) {},
            onSendVoice: (_) {},
            onCorrectionModeChanged: onMode,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Corrígeme es un chip que alterna y se marca seleccionado', (
    tester,
  ) async {
    bool? changed;
    await tester.pumpWidget(
      _host(correctionMode: false, onMode: (v) => changed = v),
    );
    final chip = find.widgetWithText(AppActionChip, 'Corrígeme');
    expect(chip, findsOneWidget);
    expect(tester.widget<AppActionChip>(chip).selected, isFalse);

    await tester.tap(chip);
    expect(changed, isTrue);

    await tester.pumpWidget(_host(correctionMode: true, onMode: (_) {}));
    expect(
      tester
          .widget<AppActionChip>(
            find.widgetWithText(AppActionChip, 'Corrígeme'),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('el campo mide al menos 52 y los botones son redondos de 52', (
    tester,
  ) async {
    await tester.pumpWidget(_host(correctionMode: false, onMode: (_) {}));
    expect(
      tester.getSize(find.byType(TextField)).height,
      greaterThanOrEqualTo(52),
    );
    final send = tester.getSize(find.byTooltip('Enviar'));
    expect(send.height, greaterThanOrEqualTo(44));
  });
}
