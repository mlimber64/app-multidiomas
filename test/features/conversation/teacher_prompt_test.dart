import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_context.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';

import '../../support/other_language_rules.dart';

void main() {
  test('uses level, goal and focus from the profile', () {
    final text = buildTeacherInstruction(
      profile: const UserLearningProfile(
        level: LanguageLevel.a2,
        goals: {LearningGoal.liveAbroad},
        focusAreas: {LearningFocus.conversation},
        onboardingCompleted: true,
      ),
      correctionMode: false,
    );
    expect(
      text,
      startsWith(
        buildTeacherSystemPrompt(
          learning: AppLanguage.italian,
          support: AppLanguage.spanish,
        ),
      ),
    );
    expect(
      text,
      contains('refer ONLY to the learner\'s latest message'),
      reason: 'prevents repeating corrections of earlier turns',
    );
    expect(text, contains('Level A2'));
    expect(text, contains('live abroad where Italian is spoken'));
    expect(text, contains('Learning focus: conversation'));
    expect(text, isNot(contains('CORRECTION MODE')));
  });

  test('each level changes the guidance', () {
    String forLevel(LanguageLevel l) => buildTeacherInstruction(
      profile: UserLearningProfile(level: l),
      correctionMode: false,
    );
    final all = LanguageLevel.values.map(forLevel).toSet();
    expect(all, hasLength(LanguageLevel.values.length));
    expect(forLevel(LanguageLevel.b2), contains('Level B2'));
  });

  test('unknown level and empty profile add nothing invented', () {
    final text = buildTeacherInstruction(
      profile: const UserLearningProfile(level: LanguageLevel.notSure),
      correctionMode: false,
    );
    expect(text, contains('Level unknown'));
    expect(text, isNot(contains('goal')));
    expect(text, isNot(contains('Learning focus')));
    expect(
      buildTeacherInstruction(
        profile: UserLearningProfile.empty,
        correctionMode: false,
      ),
      contains('Level unknown'),
    );
  });

  test('correction mode adds the Correggimi instruction', () {
    final text = buildTeacherInstruction(
      profile: UserLearningProfile.empty,
      correctionMode: true,
    );
    expect(text, contains('CORRECTION MODE is ON'));
  });

  test('lists languages, level, all goals and all focus areas compactly', () {
    final text = buildTeacherInstruction(
      profile: const UserLearningProfile(
        level: LanguageLevel.a2,
        goals: {LearningGoal.speakConfidently, LearningGoal.work},
        focusAreas: {LearningFocus.grammar, LearningFocus.vocabulary},
        onboardingCompleted: true,
      ),
      correctionMode: false,
    );
    expect(text, contains('Support language: Spanish'));
    expect(text, contains('Learning language: Italian'));
    expect(text, contains('Level A2'));
    expect(
      text,
      contains('goals: speak with more confidence; use Italian at work'),
    );
    expect(text, contains('Learning focus: grammar, vocabulary'));
  });

  test('the languages come from the profile, nothing is fixed to Italian', () {
    final text = buildTeacherInstruction(
      profile: const UserLearningProfile(
        supportLanguage: AppLanguage.italian,
        learningLanguage: AppLanguage.spanish,
        goals: {LearningGoal.work},
      ),
      correctionMode: false,
    );
    expect(text, contains('Support language: Italian'));
    expect(text, contains('Learning language: Spanish'));
    expect(text, contains('language teacher helping a learner study Spanish'));
    expect(
      text,
      contains('support language, the one they already understand, is Italian'),
    );
    expect(text, contains('Talk in Spanish.'));
    expect(text, contains('Use Italian only when a correction is truly hard'));
    expect(text, contains('use Spanish at work'));
    expect(text, isNot(contains('Italian teacher')));
  });

  test('grammar topics are named by the rules of the learning language', () {
    const context = LearningContext(priorityTopics: [GrammarTopic.articles]);
    final italian = buildTeacherInstruction(
      profile: UserLearningProfile.empty,
      correctionMode: false,
      learningContext: context,
    );
    expect(italian, contains('- articles'));
    final other = buildTeacherInstruction(
      profile: UserLearningProfile.empty,
      correctionMode: false,
      learningContext: context,
      rules: const NoGrammarRules(AppLanguage.spanish),
    );
    expect(other, contains('- topic:articles'));
  });
}
