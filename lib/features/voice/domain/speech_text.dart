import '../../profile/domain/language_pair.dart';

/// The BCP-47 tag of the voice used to read [language] aloud.
String speechLocaleTag(AppLanguage language) => switch (language) {
  AppLanguage.spanish => 'es-ES',
  AppLanguage.english => 'en-US',
  AppLanguage.italian => 'it-IT',
  AppLanguage.french => 'fr-FR',
  AppLanguage.portuguese => 'pt-BR',
  AppLanguage.german => 'de-DE',
  AppLanguage.mandarin => 'zh-CN',
};

/// [text] written so a speech engine reads it letter by letter: each letter,
/// digit or Chinese character on its own, separated by commas (the engine
/// pauses and names each one), and a full stop between words. Punctuation and
/// apostrophes are not spelled.
///
/// "il computer" -> "i, l. c, o, m, p, u, t, e, r"
String spellOut(String text) {
  final words = <String>[];
  for (final word in text.trim().split(RegExp(r'\s+'))) {
    final letters = [
      for (final rune in word.runes)
        if (RegExp(
          r'[\p{L}\p{N}]',
          unicode: true,
        ).hasMatch(String.fromCharCode(rune)))
          String.fromCharCode(rune),
    ];
    if (letters.isNotEmpty) words.add(letters.join(', '));
  }
  return words.join('. ');
}
