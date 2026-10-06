/// Learning data is kept per language inside the same memory. Records written
/// before the app taught several languages carry no language and are Italian
/// (the only language then): this is the one place that fact lives.
const legacyLanguageCode = 'it';

/// The identity of a learning item inside the memory: the plain [key] for the
/// legacy language (so every id written before stays valid), and `<code>:<key>`
/// for any other language, so two languages never share an id.
String scopedId(String languageCode, String key) =>
    languageCode == legacyLanguageCode ? key : '$languageCode:$key';
