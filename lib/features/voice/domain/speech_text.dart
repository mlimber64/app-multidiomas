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
  // No phone ships a Quechua voice. Quechua is written the way it sounds, so
  // a Latin American Spanish voice is the closest thing (it does not make the
  // ejective and aspirated consonants, or the uvular q).
  AppLanguage.quechua => 'es-US',
};

/// What a speech engine should say for [text], which is written to be read on
/// a screen: no emoji (an engine may read "smiling face" out loud), no markdown
/// marks (`**`, `_`, backticks, `#`, list bullets, quote marks at the start of
/// a line), links reduced to their words, and lines and spaces folded into
/// single spaces. Letters, digits, punctuation and every script are kept, so
/// the words and the pauses of the sentence stay as written. The visible text
/// is never changed: this only prepares what is spoken.
String spokenText(String text) {
  var spoken = text.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (m) => m[1] ?? '',
  );
  spoken = spoken.replaceAll(
    RegExp(r'^[ \t]{0,3}(?:#{1,6}|>|[-*+•])[ \t]+', multiLine: true),
    '',
  );
  spoken = spoken.replaceAll(RegExp(r'[*_`~]+'), '');
  spoken = spoken.replaceAll(
    RegExp(
      '[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B50}\u{2B55}\u{FE0F}\u{200D}\u{20E3}]',
      unicode: true,
    ),
    '',
  );
  return spoken.replaceAll(RegExp(r'\s+'), ' ').trim();
}

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
