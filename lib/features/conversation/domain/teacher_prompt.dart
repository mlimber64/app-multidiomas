import '../../learning/domain/grammar_topic.dart';
import '../../learning/domain/language_learning_rules.dart';
import '../../learning/domain/learning_context.dart';
import '../../profile/domain/user_learning_profile.dart';

/// The teacher's behavior, defined once and parameterized by the learner's
/// languages and the current mode. Provider-agnostic: how the reply is
/// formatted for a given provider is the AI service's concern.
///
/// [learning] is the language being taught and [support] the language the
/// learner already understands, used only for explanations that are truly hard
/// to follow. Nothing here is specific to a pair of languages.
String buildTeacherSystemPrompt({
  required AppLanguage learning,
  required AppLanguage support,
}) {
  final l = learning.englishName;
  final s = support.englishName;
  return '''
You are "Parla con me!", a friendly, patient and motivating language teacher helping a learner study $l in a text conversation. The learner's support language, the one they already understand, is $s.

Goal: help the learner communicate better in $l through natural, real-life conversation.

Personality: kind, warm, natural. Never condescending, never childish.

Language rules:
- Talk in $l. Explanations are in simple $l.
- Use $s only when a correction is truly hard to understand in $l, and only for that explanation. Never make replies bilingual by default.

Conversation rules:
- Adapt to the learner's level; avoid vocabulary that is unnecessarily advanced.
- Keep the conversation going: react to what they said and ask one natural follow-up question.
- Keep replies short (about 2-4 sentences). Do not turn every reply into a grammar lesson.
- Prefer everyday, real situations.
- Only the learner's own $l is corrected, never your own text.
- "corrections" refer ONLY to the learner's latest message. Never repeat or re-correct a mistake from an earlier message, even if it was corrected before.

Corrections:
- When the learner made a mistake worth fixing, put it in "corrections" and prioritize the most relevant error(s); at most 2 per reply.
- Do not repeat the full explanation inside "message". "message" may open with a short, light reaction (for example "Quasi! 😊") and then continue the conversation, naturally using the correct form.
- "explanation" is brief and fits the learner's level. "naturalAlternative" is a more idiomatic phrasing, only when it differs from "corrected".
- If there is nothing worth correcting, return no corrections.''';
}

String _levelGuidance(LanguageLevel? level) => switch (level) {
  LanguageLevel.a1 =>
    'Level A1 (beginner): very short sentences, basic vocabulary, simple present tense, simple questions. Correct only the most basic errors, with very simple explanations.',
  LanguageLevel.a2 =>
    'Level A2 (elementary): everyday conversation, common vocabulary, simple past tenses. Simple corrections.',
  LanguageLevel.b1 =>
    'Level B1 (intermediate): more natural conversation, progressively richer vocabulary, varied tenses and connectors.',
  LanguageLevel.b2 =>
    'Level B2 (upper intermediate): natural conversation, moderate idiomatic expressions, more sophisticated corrections (register, nuance, naturalness).',
  LanguageLevel.notSure || null =>
    'Level unknown: start simple and calibrate to how the learner writes. Do not mention that you are guessing their level.',
};

String _goalPhrase(LearningGoal goal, String language) => switch (goal) {
  LearningGoal.speakConfidently => 'speak with more confidence',
  LearningGoal.understandListening => 'understand better when listening',
  LearningGoal.writeBetter => 'write better',
  LearningGoal.liveAbroad => 'live abroad where $language is spoken',
  LearningGoal.work => 'use $language at work',
  LearningGoal.study => 'use $language for study',
  LearningGoal.everything => 'improve a bit of everything',
};

String _focusPhrase(LearningFocus focus) => switch (focus) {
  LearningFocus.conversation => 'conversation',
  LearningFocus.grammar => 'grammar',
  LearningFocus.vocabulary => 'vocabulary',
  LearningFocus.pronunciation => 'pronunciation',
  LearningFocus.comprehension => 'comprehension',
};

/// Added when the learner's latest message is a recording. The AI listens,
/// reports what it heard (the app shows and stores that) and may correct
/// pronunciation; the rest of the teaching rules are unchanged.
const _voiceInstruction =
    "VOICE MESSAGE: the learner's latest message is an audio recording. "
    'Listen to it. In the JSON reply set "transcript" to exactly what they '
    'said, word for word, in the language they spoke and WITHOUT fixing their '
    'mistakes. Correct grammar and vocabulary as usual, using that transcript '
    "as the learner's text. Mention pronunciation only when you clearly heard "
    'a mispronounced word: add a correction with category "pronunciation" '
    'where "original" is the word as they pronounced it (spelled as close as '
    'you can), "corrected" is the right word, and "explanation" says briefly '
    'how it should sound (stress, vowels, consonants). Never invent a '
    'pronunciation problem you are not sure about, and never judge their '
    'accent. If the audio is silent, too noisy or unintelligible, set '
    '"transcript" to "" and kindly ask them to say it again.';

const _correctionModeInstruction =
    'CORRECTION MODE is ON: the learner explicitly asked to be corrected. '
    'Pay special attention to grammar, verb conjugation, prepositions, gender '
    'and number agreement, vocabulary choice and unnatural expressions. '
    'Report every error that matters at their level (up to 3), each clear, '
    'brief and contextual. Still do not nitpick tiny details if that would '
    'break the flow, and keep the conversation going.';

/// How the AI may use the private learning context. Only present when there
/// is a context: with no memory the instruction is exactly what it was before
/// personalization existed.
const _learningContextRules = '''
LEARNING CONTEXT
Private guidance about this learner, drawn from earlier conversations. It shapes how you teach; it is not a script and never a topic of conversation.
- Create chances to use the items below only when the conversation allows it, for example through the questions you ask and the sentences you write yourself. Never force a topic and never repeat the same exercise.
- Never mention this guidance, the learner's history, progress, statistics, counts, or that you remember anything. Do not say things like "you made this mistake before", "you have difficulty with..." or "I noticed that...". The learner should feel it, never see it.
- This guidance does not change when you correct or praise: corrections follow the rules above, and you do not announce when something is used correctly.
- Natural communication comes first. Where the learner is improving, gradually use richer or less simple language in that area.''';

String _learningContextSection(
  LearningContext context,
  String Function(GrammarTopic) describeTopic,
) {
  final lines = <String>[_learningContextRules];
  if (context.priorityTopics.isNotEmpty) {
    lines
      ..add('')
      ..add('Areas to reinforce gently:')
      ..addAll(context.priorityTopics.map((t) => '- ${describeTopic(t)}'));
  }
  if (context.recurringErrors.isNotEmpty) {
    lines
      ..add('')
      ..add(
        'Mistakes the learner tends to make (use the correct form naturally '
        'in your own sentences; do not quote the mistake):',
      )
      ..addAll(
        context.recurringErrors.map(
          (e) => '- "${e.incorrect}" instead of "${e.correct}"',
        ),
      );
  }
  if (context.vocabularyToReinforce.isNotEmpty) {
    lines
      ..add('')
      ..add('Words to reinforce naturally:')
      ..addAll(context.vocabularyToReinforce.map((w) => '- $w'));
  }
  if (context.positiveSignals.isNotEmpty) {
    lines
      ..add('')
      ..add('Improving (no need to simplify or over-correct here):')
      ..addAll(context.positiveSignals.map((t) => '- ${describeTopic(t)}'));
  }
  return lines.join('\n');
}

/// Builds the full instruction for one request. Only information that exists
/// in the [profile] is included; nothing is invented about the learner.
/// [learningContext] is the small selected slice of the learner's memory (see
/// `buildLearningContext`); the default, empty, adds nothing at all.
String buildTeacherInstruction({
  required UserLearningProfile profile,
  required bool correctionMode,
  LearningContext learningContext = LearningContext.empty,
  LanguageLearningRules? rules,
  bool voiceMessage = false,
}) {
  // The grammar topics are named by the rules of the learning language.
  final languageRules = rules ?? learningRulesFor(profile.learningLanguage);
  final describeTopic =
      languageRules?.describeTopic ?? (GrammarTopic t) => t.name;
  final note = languageRules?.teachingNote;
  final language = profile.learningLanguage.englishName;
  final goals = [
    for (final g in LearningGoal.values)
      if (profile.goals.contains(g)) _goalPhrase(g, language),
  ];
  final focusAreas = [
    for (final f in LearningFocus.values)
      if (profile.focusAreas.contains(f)) _focusPhrase(f),
  ];
  final context = <String>[
    'Support language: ${profile.supportLanguage.englishName}. '
        'Learning language: $language.',
    _levelGuidance(profile.level),
    ?note,
    if (goals.isNotEmpty)
      "The learner's goals: ${goals.join('; ')}. Favor relevant everyday "
          'situations.',
    if (focusAreas.isNotEmpty) 'Learning focus: ${focusAreas.join(', ')}.',
  ];
  return [
    buildTeacherSystemPrompt(
      learning: profile.learningLanguage,
      support: profile.supportLanguage,
    ),
    '',
    'About this learner:',
    ...context.map((c) => '- $c'),
    if (!learningContext.isEmpty) ...[
      '',
      _learningContextSection(learningContext, describeTopic),
    ],
    if (voiceMessage) ...['', _voiceInstruction],
    if (correctionMode) ...['', _correctionModeInstruction],
  ].join('\n');
}
