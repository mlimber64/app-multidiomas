import '../../profile/domain/language_pair.dart';
import 'error_pattern.dart';
import 'grammar_topic.dart';
import 'grammar_topic_inference.dart' show TopicInference;
import 'language_learning_rules.dart';
import 'learning_error.dart';
import 'rule_helpers.dart';
import 'success_detection.dart';

/// The English rules. Deliberately small and conservative, like any other
/// language's rules: a rule fires only on a precise, recognizable correction, and no topic
/// is better than a wrong topic. Covered: third-person singular `-s`, the
/// present continuous, past simple vs present perfect, the verb *to be*,
/// articles, prepositions and word order. Nothing here is a grammar of
/// English: anything else is left without a topic.
class EnglishLearningRules implements LanguageLearningRules {
  const EnglishLearningRules();

  static const _ruleConfidence = 0.8;

  @override
  AppLanguage get language => AppLanguage.english;

  @override
  bool isArticle(String word) => _articles.contains(word);

  @override
  TopicInference? inferGrammarTopics(ErrorPattern pattern) =>
      _thirdPersonRule(pattern) ??
      _continuousRule(pattern) ??
      _pastVsPerfectRule(pattern) ??
      _toBeRule(pattern) ??
      _articleRule(pattern) ??
      _prepositionRule(pattern) ??
      wordOrderInference(pattern);

  /// Literal evidence only (no structural variants): fewer, reliable successes.
  /// See [detectLiteralGrammarSuccesses].
  @override
  Map<GrammarTopic, double> detectGrammarSuccesses({
    required List<String> messageTokens,
    required Iterable<LearningError> knownErrors,
    required Set<String> errorKeysThisTurn,
    required Set<GrammarTopic> errorTopicsThisTurn,
  }) => detectLiteralGrammarSuccesses(
    messageTokens: messageTokens,
    knownErrors: knownErrors,
    errorKeysThisTurn: errorKeysThisTurn,
    errorTopicsThisTurn: errorTopicsThisTurn,
  );

  @override
  String? get teachingNote => null;

  @override
  String describeTopic(GrammarTopic topic) => switch (topic) {
    GrammarTopic.articles => 'Articles',
    GrammarTopic.toBe => 'Verb to be',
    GrammarTopic.pastSimple => 'Past simple',
    GrammarTopic.presentContinuous => 'Present continuous',
    GrammarTopic.presentPerfect => 'Present perfect',
    GrammarTopic.prepositions => 'Prepositions',
    GrammarTopic.thirdPersonSingular => 'Third-person singular',
    GrammarTopic.wordOrder => 'Word order',
    // Topics of other languages are not English topics.
    _ => topic.name,
  };

  // --- rules ---------------------------------------------------------------

  /// "he go to work" -> "he goes to work": the verb gains its third-person
  /// `-s` and the word before it is he / she / it.
  TopicInference? _thirdPersonRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length == 1 &&
        b.length == 1 &&
        _thirdPersonSubjects.contains(p.precedingToken) &&
        _isThirdPersonForm(a.first, b.first)) {
      return const TopicInference(
        topics: [GrammarTopic.thirdPersonSingular],
        confidence: _ruleConfidence,
      );
    }
    return null;
  }

  /// "I am go" -> "I am going"; "I going" -> "I am going".
  TopicInference? _continuousRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length == 1 &&
        b.length == 1 &&
        _be.contains(p.precedingToken) &&
        _isIngForm(a.first, b.first)) {
      return const TopicInference(
        topics: [GrammarTopic.presentContinuous],
        confidence: _ruleConfidence,
      );
    }
    final c = p.correctedTokens;
    // The verb to be was left out: "she working" -> "she is working".
    final added = b;
    if (a.isEmpty && added.length == 1 && _be.contains(added.first)) {
      final at = c.indexOf(added.first);
      if (at + 1 < c.length && _looksLikeIng(c[at + 1])) {
        return const TopicInference(
          topics: [GrammarTopic.presentContinuous, GrammarTopic.toBe],
          confidence: _ruleConfidence,
        );
      }
    }
    return null;
  }

  /// "I have seen him yesterday" -> "I saw him yesterday" and the reverse.
  TopicInference? _pastVsPerfectRule(ErrorPattern p) {
    final o = p.originalTokens;
    final c = p.correctedTokens;

    // A plain tense swap of one verb: "go" -> "went".
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    if (a.length == 1 && b.length == 1 && _isPastOf(a.first, b.first)) {
      return const TopicInference(
        topics: [GrammarTopic.pastSimple],
        confidence: _ruleConfidence,
      );
    }

    // have/has + participle  ->  the past simple of the same verb.
    for (var i = 0; i + 1 < o.length; i++) {
      if (_have.contains(o[i]) && _pastOfParticiple(o[i + 1]) != null) {
        final past = _pastOfParticiple(o[i + 1])!;
        if (c.contains(past) && !c.contains(o[i])) {
          return const TopicInference(
            topics: [GrammarTopic.pastSimple, GrammarTopic.presentPerfect],
            confidence: _ruleConfidence,
          );
        }
      }
    }
    // The past simple where the present perfect is needed.
    for (var i = 0; i + 1 < c.length; i++) {
      if (_have.contains(c[i]) && _pastOfParticiple(c[i + 1]) != null) {
        final past = _pastOfParticiple(c[i + 1])!;
        if (o.contains(past) && !o.contains(c[i])) {
          return const TopicInference(
            topics: [GrammarTopic.presentPerfect, GrammarTopic.pastSimple],
            confidence: _ruleConfidence,
          );
        }
      }
    }
    return null;
  }

  /// "he are" -> "he is"; "she tired" -> "she is tired".
  TopicInference? _toBeRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    final swapped =
        a.isNotEmpty &&
        b.isNotEmpty &&
        a.length <= 2 &&
        b.length <= 2 &&
        [...a, ...b].every(_be.contains);
    final omitted = a.isEmpty && b.length == 1 && _be.contains(b.first);
    if (swapped || omitted) {
      return const TopicInference(
        topics: [GrammarTopic.toBe],
        confidence: _ruleConfidence,
      );
    }
    return null;
  }

  /// "I have car" -> "I have a car", "the life" -> "life".
  TopicInference? _articleRule(ErrorPattern p) =>
      functionWordInference(p, _articles, GrammarTopic.articles);

  /// "in Monday" -> "on Monday".
  TopicInference? _prepositionRule(ErrorPattern p) {
    final a = p.coreOriginalTokens;
    final b = p.coreCorrectedTokens;
    // A swap only: a preposition added or dropped is not safely a preposition
    // issue ("to" is also the infinitive marker).
    if (a.isEmpty || b.isEmpty) return null;
    return functionWordInference(p, _prepositions, GrammarTopic.prepositions);
  }

  // --- vocabulary of the rules ---------------------------------------------

  static const _articles = {'a', 'an', 'the'};
  static const _be = {'am', 'is', 'are', 'was', 'were'};
  static const _have = {'have', 'has'};
  static const _thirdPersonSubjects = {'he', 'she', 'it'};

  static const _prepositions = {
    'in',
    'on',
    'at',
    'to',
    'for',
    'of',
    'with',
    'from',
    'by',
    'about',
    'into',
    'over',
    'under',
    'between',
    'during',
    'since',
    'until',
    'before',
    'after',
  };

  /// Irregular verbs: base -> (past simple, past participle).
  static const _irregular = <String, (String, String)>{
    'go': ('went', 'gone'),
    'see': ('saw', 'seen'),
    'eat': ('ate', 'eaten'),
    'buy': ('bought', 'bought'),
    'make': ('made', 'made'),
    'take': ('took', 'taken'),
    'come': ('came', 'come'),
    'get': ('got', 'got'),
    'give': ('gave', 'given'),
    'know': ('knew', 'known'),
    'write': ('wrote', 'written'),
    'do': ('did', 'done'),
    'say': ('said', 'said'),
    'tell': ('told', 'told'),
    'find': ('found', 'found'),
    'leave': ('left', 'left'),
    'meet': ('met', 'met'),
    'run': ('ran', 'run'),
    'speak': ('spoke', 'spoken'),
    'drink': ('drank', 'drunk'),
    'bring': ('brought', 'brought'),
    'have': ('had', 'had'),
  };

  /// "go" -> "goes", "study" -> "studies", "have" -> "has".
  static bool _isThirdPersonForm(String base, String form) {
    if (base == 'have') return form == 'has';
    if (base.length < 2) return false;
    if (form == '${base}s' || form == '${base}es') return true;
    return base.endsWith('y') &&
        form == '${base.substring(0, base.length - 1)}ies';
  }

  /// "go" -> "going", "make" -> "making", "run" -> "running".
  static bool _isIngForm(String base, String form) {
    if (base.length < 2 || !form.endsWith('ing')) return false;
    final stem = form.substring(0, form.length - 3);
    if (stem == base) return true;
    if (base.endsWith('e') && stem == base.substring(0, base.length - 1)) {
      return true;
    }
    return stem.length == base.length + 1 &&
        stem.startsWith(base) &&
        stem[stem.length - 1] == base[base.length - 1];
  }

  static bool _looksLikeIng(String word) =>
      word.length > 4 && word.endsWith('ing');

  /// Whether [past] is the past simple of the verb [base]: an irregular one
  /// from the table, or a regular `-ed` (`-d`, `-ied`) form.
  static bool _isPastOf(String base, String past) {
    final irregular = _irregular[base];
    if (irregular != null) return irregular.$1 == past;
    if (base.length < 3 || _irregular.values.any((v) => v.$1 == base)) {
      return false;
    }
    if (past == '${base}ed' || past == '${base}d') return true;
    return base.endsWith('y') &&
        past == '${base.substring(0, base.length - 1)}ied';
  }

  /// The past simple matching a participle ("seen" -> "saw"; a regular
  /// "-ed" participle is its own past), or `null` when unknown.
  static String? _pastOfParticiple(String participle) {
    for (final entry in _irregular.entries) {
      if (entry.value.$2 == participle && entry.value.$1 != participle) {
        return entry.value.$1;
      }
    }
    return participle.length > 3 && participle.endsWith('ed')
        ? participle
        : null;
  }
}
