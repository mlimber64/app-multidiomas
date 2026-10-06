import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/ui_language_providers.dart';
import 'package:parla_con_me/l10n/l10n.dart';

Map<String, dynamic> _arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _keys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// `{name}` placeholders of a message, also inside ICU plurals.
Set<String> _placeholders(String message) => RegExp(
  r'\{(\w+)(?:,|\})',
).allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  test('every interface language has exactly the same messages', () {
    final en = _arb('en');
    for (final code in [for (final l in availableUiLanguages) l.code]) {
      final arb = _arb(code);
      expect(_keys(arb), _keys(en), reason: code);
      expect(arb['@@locale'], code);
    }
  });

  test('no message is empty and placeholders match across languages', () {
    final en = _arb('en');
    for (final code in ['es', 'it']) {
      final arb = _arb(code);
      for (final key in _keys(en)) {
        final text = arb[key] as String;
        expect(text.trim(), isNotEmpty, reason: '$code/$key');
        expect(
          _placeholders(text),
          _placeholders(en[key] as String),
          reason: '$code/$key',
        );
      }
    }
  });

  test('the supported locales are exactly the interface languages', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      availableUiLanguages.map((l) => l.code).toSet(),
    );
  });

  test('messages resolve per language, with plurals', () async {
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final it = await AppLocalizations.delegate.load(const Locale('it'));
    expect(es.navHome, 'Inicio');
    expect(en.navHome, 'Home');
    expect(it.navPath, 'Percorso');
    expect(es.exercisesDone(1), '1 ejercicio completado');
    expect(en.exercisesDone(5), '5 exercises completed');
    expect(it.exercisesDone(5), '5 esercizi completati');
    expect(en.correctOutOf(1, 8), 'Correct 1 time out of 8');
    expect(it.correctOutOf(4, 8), 'Corretto 4 volte su 8');
  });

  test('a device language maps to an interface language, else English', () {
    expect(uiLanguageForLocale(const Locale('es', 'MX')), AppLanguage.spanish);
    expect(uiLanguageForLocale(const Locale('it')), AppLanguage.italian);
    expect(uiLanguageForLocale(const Locale('en', 'GB')), AppLanguage.english);
    expect(uiLanguageForLocale(const Locale('ja')), AppLanguage.english);
  });
}
