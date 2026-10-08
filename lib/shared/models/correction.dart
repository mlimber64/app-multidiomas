enum CorrectionCategory {
  grammar,
  vocabulary,
  pronunciation,
  naturalExpression,
  spelling,
  other;

  /// Unknown or missing values map to [other] so a provider quirk never
  /// drops a correction.
  static CorrectionCategory parse(Object? name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return other;
  }
}

/// One concrete fix for something the learner wrote. Provider-agnostic: the
/// AI layer produces it, the conversation stores it, and the Learning Engine
/// will consume it.
class Correction {
  const Correction({
    required this.original,
    required this.corrected,
    required this.explanation,
    this.naturalAlternative,
    this.category = CorrectionCategory.other,
    this.correctedTranslation,
  });

  final String original;
  final String corrected;
  final String explanation;

  /// A more idiomatic way to say it, when different from [corrected].
  final String? naturalAlternative;
  final CorrectionCategory category;

  /// [corrected] in the learner's support language, to help them understand
  /// it. A comprehension aid only: it never takes part in learning, and it is
  /// `null` when the AI gave none (older corrections never have one).
  final String? correctedTranslation;

  Map<String, Object?> toJson() => {
    'original': original,
    'corrected': corrected,
    'explanation': explanation,
    'naturalAlternative': naturalAlternative,
    'category': category.name,
    if (correctedTranslation != null)
      'correctedTranslation': correctedTranslation,
  };

  /// Lenient decoding of untrusted input (provider output or stored data).
  /// Returns `null` unless there is a usable original and correction.
  static Correction? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final original = _text(json['original']);
    final corrected = _text(json['corrected']);
    if (original == null || corrected == null) return null;
    return Correction(
      original: original,
      corrected: corrected,
      explanation: _text(json['explanation']) ?? '',
      naturalAlternative: _text(json['naturalAlternative']),
      category: CorrectionCategory.parse(json['category']),
      correctedTranslation: _text(json['correctedTranslation']),
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is Correction &&
      other.original == original &&
      other.corrected == corrected &&
      other.explanation == explanation &&
      other.naturalAlternative == naturalAlternative &&
      other.category == category &&
      other.correctedTranslation == correctedTranslation;

  @override
  int get hashCode => Object.hash(
    original,
    corrected,
    explanation,
    naturalAlternative,
    category,
    correctedTranslation,
  );
}
