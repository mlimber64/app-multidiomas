/// The recurring *pattern* behind a correction, used to recognize "the same
/// mistake again".
///
/// A correction from the AI can come as a whole sentence or as a fragment
/// ("Ieri ho andato al supermercato." vs "ho andato"). To treat both as the
/// same mistake the texts are reduced to the smallest span of words that
/// differs, plus one neighbouring word of context when that span is tiny:
///
///   "Ieri ho andato al supermercato." -> "Ieri sono andato al supermercato."
///   pattern: "ho andato" -> "sono andato"
///
/// Comparison is case-insensitive and ignores surrounding punctuation, but
/// keeps accents (the "perche" -> "perché" mistake is only the accent).
///
/// Known limitations (deterministic MVP strategy, no NLP): different surface
/// forms of the same mistake ("ho andato" vs "abbiamo andato") are different
/// patterns; a rewrite of the whole sentence yields one long pattern that is
/// unlikely to repeat exactly.
class ErrorPattern {
  const ErrorPattern._({
    required this.original,
    required this.corrected,
    required this.key,
    required this.originalTokens,
    required this.correctedTokens,
    required this.coreOriginalTokens,
    required this.coreCorrectedTokens,
    required this.precedingToken,
    required this.fullOriginalTokens,
    required this.fullCorrectedTokens,
  });

  /// Display text of the pattern as the learner wrote it / corrected form.
  final String original;
  final String corrected;

  /// Stable identity: normalized `original -> corrected`.
  final String key;

  /// Normalized (lowercase) words of the pattern, with context.
  final List<String> originalTokens;
  final List<String> correctedTokens;

  /// Only the words that actually differ, without the context word.
  final List<String> coreOriginalTokens;
  final List<String> coreCorrectedTokens;

  /// The normalized word just before the differing words in the text the
  /// learner wrote, or `null` when they start the text. It is context for
  /// language rules (a subject before a verb); it is not part of the identity.
  final String? precedingToken;

  /// Every normalized word of the two texts the pattern was cut from. Context
  /// for language rules (a participle at the end of the sentence); not part of
  /// the identity.
  final List<String> fullOriginalTokens;
  final List<String> fullCorrectedTokens;

  /// `null` when there is nothing to learn from the pair: either side is
  /// empty, or both are the same text (not a mistake).
  static ErrorPattern? from(String original, String corrected) {
    final a = _tokenize(original);
    final b = _tokenize(corrected);
    if (a.isEmpty || b.isEmpty) return null;
    if (_sameNorm(a, b)) return null;

    var prefix = 0;
    final limit = a.length < b.length ? a.length : b.length;
    while (prefix < limit && a[prefix].norm == b[prefix].norm) {
      prefix++;
    }
    var suffix = 0;
    final suffixLimit = limit - prefix;
    while (suffix < suffixLimit &&
        a[a.length - 1 - suffix].norm == b[b.length - 1 - suffix].norm) {
      suffix++;
    }

    var aStart = prefix;
    var aEnd = a.length - suffix;
    var bStart = prefix;
    var bEnd = b.length - suffix;
    final coreA = a.sublist(aStart, aEnd);
    final coreB = b.sublist(bStart, bEnd);

    // A differing span made only of short words is ambiguous on its own
    // ("ho" -> "sono", "la" -> "il"), so keep one neighbouring word: to the
    // right if there is one, else to the left. Longer words stand alone
    // ("perche" -> "perché" is the same mistake in any sentence).
    final differing = [...coreA, ...coreB];
    final onlyShortWords = differing.every((t) => t.norm.length <= _shortWord);
    if (aEnd - aStart <= 2 && bEnd - bStart <= 2 && onlyShortWords) {
      if (suffix > 0) {
        aEnd++;
        bEnd++;
      } else if (prefix > 0) {
        aStart--;
        bStart--;
      }
    }

    final spanA = a.sublist(aStart, aEnd);
    final spanB = b.sublist(bStart, bEnd);
    final normA = spanA.map((t) => t.norm).toList();
    final normB = spanB.map((t) => t.norm).toList();
    return ErrorPattern._(
      original: joinTokens(spanA.map((t) => t.raw)),
      corrected: joinTokens(spanB.map((t) => t.raw)),
      key: '${joinTokens(normA)} -> ${joinTokens(normB)}',
      originalTokens: normA,
      correctedTokens: normB,
      coreOriginalTokens: coreA.map((t) => t.norm).toList(),
      coreCorrectedTokens: coreB.map((t) => t.norm).toList(),
      precedingToken: prefix > 0 ? a[prefix - 1].norm : null,
      fullOriginalTokens: [for (final t in a) t.norm],
      fullCorrectedTokens: [for (final t in b) t.norm],
    );
  }

  /// Normalized (lowercase, edge punctuation removed) words of any text, the
  /// same way patterns are built, for comparing a learner's message with a
  /// stored pattern.
  static List<String> tokensOf(String text) => [
    for (final t in _tokenize(text)) t.norm,
  ];

  /// Whether [needle] appears as consecutive words inside [haystack]. An empty
  /// needle never matches.
  static bool containsSequence(List<String> haystack, List<String> needle) {
    if (needle.isEmpty || needle.length > haystack.length) return false;
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      var matches = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }

  static bool _sameNorm(List<_Token> a, List<_Token> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].norm != b[i].norm) return false;
    }
    return true;
  }

  /// Whether [token] is a single Han character (Chinese writes no spaces
  /// between words, so each character is a token of its own).
  static bool isHan(String token) =>
      token.runes.length == 1 && _han.hasMatch(token);

  /// Tokens written back as text: a space between words, none between two Han
  /// characters. For any other script this is a plain join with spaces.
  static String joinTokens(Iterable<String> tokens) {
    final out = StringBuffer();
    String? previous;
    for (final t in tokens) {
      if (previous != null && !_attached(previous, t)) out.write(' ');
      out.write(t);
      previous = t;
    }
    return out.toString();
  }

  /// No space between two Han characters, nor between one and a blank
  /// (`____`) standing for a missing word in a Chinese sentence.
  static bool _attached(String a, String b) =>
      (isHan(a) && isHan(b)) ||
      (isHan(a) && _blank.hasMatch(b)) ||
      (_blank.hasMatch(a) && isHan(b));

  static final _blank = RegExp(r'^_+$');

  static List<_Token> _tokenize(String text) {
    final tokens = <_Token>[];
    for (final part in text.replaceAll('’', "'").split(RegExp(r'\s+'))) {
      for (final piece in _pieces(part)) {
        final raw = piece.replaceAll(_edgePunctuation, '');
        if (raw.isEmpty) continue;
        tokens.add(_Token(raw, raw.toLowerCase()));
      }
    }
    return tokens;
  }

  /// A whitespace-separated chunk cut into its words: every Han character on
  /// its own, everything else in runs (so "iPhone很好" is iPhone, 很, 好).
  static Iterable<String> _pieces(String chunk) sync* {
    final run = StringBuffer();
    for (final rune in chunk.runes) {
      final char = String.fromCharCode(rune);
      if (_han.hasMatch(char)) {
        if (run.isNotEmpty) {
          yield run.toString();
          run.clear();
        }
        yield char;
      } else {
        run.write(char);
      }
    }
    if (run.isNotEmpty) yield run.toString();
  }

  static final _han = RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]');

  /// Words up to this length (articles, auxiliaries, prepositions) need
  /// context to identify a mistake.
  static const _shortWord = 4;

  static final _edgePunctuation = RegExp(
    r'^[.,;:!?¿¡"“”«»()\[\]，。！？；：、（）《》【】…]+|'
    r'[.,;:!?¿¡"“”«»()\[\]，。！？；：、（）《》【】…]+$',
  );
}

class _Token {
  const _Token(this.raw, this.norm);
  final String raw;
  final String norm;
}
