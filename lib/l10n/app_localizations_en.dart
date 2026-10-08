// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tryAgain => 'Try again';

  @override
  String get save => 'Save';

  @override
  String get back => 'Back';

  @override
  String get notSet => 'Not set';

  @override
  String get couldNotSave => 'I couldn\'t save. Please try again.';

  @override
  String get letsTalk => 'Let\'s talk';

  @override
  String get continueAction => 'Continue';

  @override
  String get navHome => 'Home';

  @override
  String get navTalk => 'Talk';

  @override
  String get navLearn => 'Learn';

  @override
  String get navWords => 'Words';

  @override
  String get navPath => 'Progress';

  @override
  String get navProfile => 'Profile';

  @override
  String get homeGreeting => 'Hi! 👋';

  @override
  String get homeReady => 'Ready to practice today?';

  @override
  String get heroSubtitle => 'Practice with your AI teacher.';

  @override
  String get quickConversation => 'Conversation';

  @override
  String get quickReview => 'Review';

  @override
  String get journeyTitle => 'Your journey';

  @override
  String get rowLanguage => 'Language';

  @override
  String get rowLevel => 'Level';

  @override
  String get rowGoals => 'Goals';

  @override
  String get rowFocus => 'Focus';

  @override
  String get noteStartTitle => 'Your journey starts here.';

  @override
  String get noteStartBody =>
      'Have your first conversation to start building your journey.';

  @override
  String get noteFocusTitle => 'Your focus';

  @override
  String get noteImprovingTitle => 'You\'re improving';

  @override
  String get noteKeepPracticing => 'Keep practicing in your conversations.';

  @override
  String noteImprovingIn(String topics) {
    return 'You\'re improving in: $topics';
  }

  @override
  String get levelA1 => 'A1 — Beginner';

  @override
  String get levelA2 => 'A2 — Elementary';

  @override
  String get levelB1 => 'B1 — Intermediate';

  @override
  String get levelB2 => 'B2 — Upper intermediate';

  @override
  String get levelNotSure => 'I\'m not sure';

  @override
  String get goalSpeakConfidently => 'Speak with more confidence';

  @override
  String get goalUnderstandListening => 'Understand better when listening';

  @override
  String get goalWriteBetter => 'Write better';

  @override
  String get goalLiveAbroad => 'Live better abroad';

  @override
  String get goalWork => 'Work';

  @override
  String get goalStudy => 'Study';

  @override
  String get goalEverything => 'A bit of everything';

  @override
  String get focusConversation => 'Conversation';

  @override
  String get focusGrammar => 'Grammar';

  @override
  String get focusVocabulary => 'Vocabulary';

  @override
  String get focusPronunciation => 'Pronunciation';

  @override
  String get focusComprehension => 'Comprehension';

  @override
  String get topicPassatoProssimo => 'Passato prossimo';

  @override
  String get topicEssereVsAvere => 'Essere vs avere';

  @override
  String get topicPrepositions => 'Prepositions';

  @override
  String get topicArticles => 'Articles';

  @override
  String get topicGender => 'Noun gender';

  @override
  String get topicPlural => 'Plurals';

  @override
  String get topicAgreement => 'Agreement';

  @override
  String get topicPronouns => 'Pronouns';

  @override
  String get topicVerbConjugation => 'Verb conjugation';

  @override
  String get topicWordOrder => 'Word order';

  @override
  String get topicToBe => 'The verb \"to be\"';

  @override
  String get topicPresentContinuous => 'Present continuous';

  @override
  String get topicPastSimple => 'Past simple';

  @override
  String get topicPresentPerfect => 'Present perfect';

  @override
  String get topicThirdPersonSingular => 'Third-person singular';

  @override
  String get chatTitle => 'Talk';

  @override
  String get newConversation => 'New conversation';

  @override
  String get suggestionDay => 'My day';

  @override
  String get suggestionWork => 'Let\'s talk about work';

  @override
  String get suggestionRestaurant =>
      'Let\'s have a conversation at a restaurant';

  @override
  String get suggestionPractice => 'I want to practice a little';

  @override
  String get chatWelcomeTitle => 'Hi! I\'m your language teacher.';

  @override
  String get chatWelcomeSubtitle => 'What do you want to talk about today?';

  @override
  String get chatErrorGeneric =>
      'I can\'t answer right now. Shall we try again?';

  @override
  String get correctMe => 'Correct me';

  @override
  String get correctMeHint => 'The teacher will correct more carefully';

  @override
  String get composerHint => 'Write in the language you are learning…';

  @override
  String get send => 'Send';

  @override
  String get roleYou => 'You';

  @override
  String get roleTeacher => 'Teacher';

  @override
  String get youWrote => 'You wrote: ';

  @override
  String get better => 'Better: ';

  @override
  String moreNatural(String alternative) {
    return 'More natural: $alternative';
  }

  @override
  String get categoryGrammar => 'Grammar';

  @override
  String get categoryVocabulary => 'Vocabulary';

  @override
  String get categoryPronunciation => 'Pronunciation';

  @override
  String get categoryNaturalExpression => 'Natural expression';

  @override
  String get categorySpelling => 'Spelling';

  @override
  String get categoryOther => 'Correction';

  @override
  String get teacherTyping => 'The teacher is typing';

  @override
  String get aiNotConfigured =>
      'The teacher is not configured yet. Add the Gemini API key (see the README).';

  @override
  String get aiNetwork =>
      'I can\'t connect. Check your connection and we\'ll try again.';

  @override
  String get aiRateLimited =>
      'Too many requests in a short time. Wait a moment and we will try again.';

  @override
  String get learnImprove => 'What you can improve';

  @override
  String get learnPriorities => 'Your priorities';

  @override
  String get learnHowTitle => 'How to work on it';

  @override
  String get learnHowBody =>
      'These areas are trained by speaking: keep using them in your conversations and I will help you naturally.';

  @override
  String get learnDoingWellTitle => 'You are doing well';

  @override
  String get learnDoingWellBody =>
      'For now there are no urgent areas to reinforce. Keep talking with me.';

  @override
  String get learnEmptyTitle => 'Here you will see what to improve';

  @override
  String get learnEmptyBody =>
      'When you talk to me, you will find here the areas worth focusing on.';

  @override
  String get topicProgressMade =>
      'You have already made progress. Let us keep working on it.';

  @override
  String get topicWorthFocus => 'It is worth focusing here.';

  @override
  String relatedTo(String topics) {
    return 'Related to: $topics';
  }

  @override
  String get topicImprovingDetail =>
      'You are improving: you use it better and better.';

  @override
  String get topicProgressWorth =>
      'You have already made progress, but it is still worth working on.';

  @override
  String get workingOn => 'You are working on';

  @override
  String get recurringErrors => 'Recurring mistakes';

  @override
  String get mistakes => 'Mistakes';

  @override
  String get keepUsingIt => 'Keep using it in your conversations.';

  @override
  String get topicToConsolidate => 'Still to consolidate';

  @override
  String get topicImprovingStatus => 'You use it better and better';

  @override
  String correctOutOf(int correct, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      correct,
      locale: localeName,
      other: '$correct times',
      one: '1 time',
    );
    return 'Correct $_temp0 out of $total';
  }

  @override
  String errorPairSemantics(String incorrect, String correct) {
    return 'You wrote $incorrect, better $correct';
  }

  @override
  String get vocabInUse => 'You are using it';

  @override
  String get vocabUsedCorrectly => 'You have already used it correctly';

  @override
  String get vocabToConsolidate => 'To consolidate';

  @override
  String get overviewError =>
      'I can\'t show your journey right now. Shall we try again?';

  @override
  String get progressIntro =>
      'Here you see how your learning evolves, based on how you speak.';

  @override
  String get progressEmptyTitle => 'We\'re starting to get to know you.';

  @override
  String get progressEmptyBody =>
      'Talk to me and here you will see how your journey evolves.';

  @override
  String get progressToReinforce => 'To reinforce';

  @override
  String get progressRecurringSub => 'You have written them more than once.';

  @override
  String get seeAllWords => 'See all words';

  @override
  String get wordsHeadline => 'Your words';

  @override
  String get wordsIntro => 'The words you meet while talking with me.';

  @override
  String get wordsEmptyTitle => 'Your words will appear here';

  @override
  String get wordsEmptyBody =>
      'When you meet new words while talking with me, you will find them on this page.';

  @override
  String get wordsToConsolidateTitle => 'Words to consolidate';

  @override
  String get wordsToConsolidateSub => 'You have met them: keep using them.';

  @override
  String get wordsInUseTitle => 'Words you are using';

  @override
  String get wordsInUseSub =>
      'You have already used them correctly several times.';

  @override
  String get welcomeTagline => 'Your personal language teacher.';

  @override
  String get welcomeBody =>
      'Practice a language in a personal way: we will ask you a few questions to get to know you, so you can start learning from where you are.';

  @override
  String get onbStart => 'Let\'s start';

  @override
  String get onbFinish => 'Start';

  @override
  String onbStepSemantics(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get onbLanguagesTitle => 'Your languages';

  @override
  String get supportLanguageLabel => 'Support language';

  @override
  String get learnLanguageQuestion => 'Language you want to learn';

  @override
  String get levelQuestion => 'How well do you already know this language?';

  @override
  String get goalsQuestion => 'Why do you want to learn this language?';

  @override
  String get focusQuestion => 'What do you want to focus on?';

  @override
  String selectionHint(int min, int max, int count) {
    return 'Choose $min to $max · $count selected';
  }

  @override
  String get profileHeading => 'Your learning';

  @override
  String get uiLanguageLabel => 'App language';

  @override
  String get learningLanguageRow => 'Language you are learning';

  @override
  String get supportSheetTitle =>
      'Which language do you prefer for explanations?';

  @override
  String get learnSheetTitle => 'Which language do you want to learn?';

  @override
  String get uiSheetTitle => 'Which language do you want the app in?';

  @override
  String get rowAreas => 'Areas';

  @override
  String get profileLocalNote => 'Your preferences stay on this device.';

  @override
  String get reviewPreparing => 'Preparing your review';

  @override
  String get reviewError =>
      'I couldn\'t prepare your review. Please try again.';

  @override
  String exerciseProgress(int position, int total) {
    return '$position of $total';
  }

  @override
  String exerciseSemantics(int position, int total) {
    return 'Exercise $position of $total';
  }

  @override
  String get instructionCorrect => 'Correct the sentence';

  @override
  String get instructionChoose => 'Choose the correct answer';

  @override
  String get instructionComplete => 'Complete the sentence';

  @override
  String get yourAnswer => 'Your answer';

  @override
  String get check => 'Check';

  @override
  String get correctAnswerTag => 'Correct answer';

  @override
  String get feedbackCorrect => 'Exactly!';

  @override
  String get feedbackIncorrect => 'Almost.';

  @override
  String yourAnswerWas(String answer) {
    return 'Your answer: $answer';
  }

  @override
  String get correctAnswerIs => 'The correct answer is:';

  @override
  String get backToPath => 'Back to your journey';

  @override
  String get reviewEmptyTitle => 'No review available';

  @override
  String get reviewEmptyBody =>
      'There are no exercises ready for now. Keep talking and we will come back here when there is something to review.';

  @override
  String get reviewDoneTitle => 'Review complete';

  @override
  String exercisesDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises completed',
      one: '1 exercise completed',
    );
    return '$_temp0';
  }

  @override
  String correctCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count correct',
      one: '1 correct',
    );
    return '$_temp0';
  }

  @override
  String toRetry(int count) {
    return '$count to retry';
  }

  @override
  String get topicEtreVsAvoir => 'Être vs avoir';

  @override
  String get topicPasseCompose => 'Passé composé';

  @override
  String get topicSerVsEstar => 'Ser vs estar';

  @override
  String get topicHabenVsSein => 'Haben vs sein';

  @override
  String get topicPerfekt => 'Perfekt';

  @override
  String get topicCases => 'Cases (Kasus)';

  @override
  String get topicPorVsPara => 'Por vs para';

  @override
  String get topicMeasureWords => 'Measure words (量词)';

  @override
  String get topicStructuralParticles => 'Particles 的 / 得 / 地';

  @override
  String get topicAspectParticles => 'Aspect particles (了, 过, 着)';

  @override
  String get topicNegation => 'Negation (不 / 没)';

  @override
  String get listen => 'Listen';

  @override
  String get listenSlowly => 'Slowly';

  @override
  String get spellIt => 'Spell it';

  @override
  String get stopListening => 'Stop';

  @override
  String get hearItRight => 'Hear how it is said and written correctly:';

  @override
  String get translationLabel => 'Translation';

  @override
  String get teacherVoiceLabel => 'Teacher\'s voice';

  @override
  String get teacherVoiceHint =>
      'Used when the teacher\'s messages are read aloud. The exact voice depends on the ones installed on your phone.';

  @override
  String get voiceFemale => 'Female';

  @override
  String get voiceMale => 'Male';

  @override
  String get listenToMessage => 'Listen to the message';

  @override
  String get noVoiceInstalled =>
      'Your phone has no voice installed for this language. You can install one in Settings, Language, Text-to-speech output.';

  @override
  String get speechFailed => 'I couldn\'t play the audio.';

  @override
  String get speakRepliesLabel => 'Read replies aloud';

  @override
  String get speakRepliesHint =>
      'Replies to your voice messages are always read.';

  @override
  String get recordVoice => 'Record a voice message';

  @override
  String get recordingNow => 'Recording';

  @override
  String get recordingCancel => 'Cancel the recording';

  @override
  String get recordingSend => 'Send the voice message';

  @override
  String get micDenied =>
      'I need permission to use the microphone. You can turn it on in the phone settings.';

  @override
  String get micFailed => 'I couldn\'t start recording.';

  @override
  String get recordingTooShort =>
      'The recording was too short. Speak a little longer.';

  @override
  String get voiceMessage => 'Voice message';

  @override
  String get voiceListening => 'Listening…';

  @override
  String get voiceNotUnderstood => 'The audio was not understood';

  @override
  String get routineTitle => 'Your practice for today';

  @override
  String get routineIntro => 'This is what is worth practicing today.';

  @override
  String get routinePreparing => 'Preparing your practice';

  @override
  String get routineError =>
      'I couldn\'t prepare your practice for today. Please try again.';

  @override
  String get routineStep3Title => 'Consolidate';

  @override
  String routineReviewDesc(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises to review',
      one: '1 exercise to review',
    );
    return '$_temp0';
  }

  @override
  String get routineReviewNone => 'Nothing to review today.';

  @override
  String routineWordsDesc(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words to consolidate',
      one: '1 word to consolidate',
    );
    return '$_temp0';
  }

  @override
  String get routineWordsNone => 'No words to consolidate today.';

  @override
  String get routineStepDone => 'Done';

  @override
  String get routineStepLocked => 'Finish the previous step first.';

  @override
  String get routineCtaStart => 'Start';

  @override
  String get routineContinue => 'Back to your practice';

  @override
  String get routineCompleted => 'Done for today! 🎉';

  @override
  String get routineCompletedBody =>
      'You\'ve done today\'s practice. Come back tomorrow.';

  @override
  String routineProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String routineProgressSemantics(int done, int total) {
    return '$done of $total steps done';
  }

  @override
  String get situationIntroductionTitle => 'Introduce yourself';

  @override
  String get situationIntroductionDesc =>
      'You meet someone at a party: talk about where you live, what you do and what you enjoy.';

  @override
  String get situationYesterdayTitle => 'What did you do yesterday?';

  @override
  String get situationYesterdayDesc =>
      'A friend asks how yesterday went: tell them where you went and what you did.';

  @override
  String get situationWorkdayTitle => 'Your day';

  @override
  String get situationWorkdayDesc =>
      'A colleague asks about your day at work or study.';

  @override
  String get situationCafeTitle => 'At the café';

  @override
  String get situationCafeDesc =>
      'Order something to eat and drink and ask a question about the place.';

  @override
  String get situationDirectionsTitle => 'How do I get there?';

  @override
  String get situationDirectionsDesc =>
      'You are in a town you do not know: ask how to get to a place.';

  @override
  String get situationShoppingTitle => 'Shopping';

  @override
  String get situationShoppingDesc =>
      'Look for something to buy: ask about size, color and price.';

  @override
  String get situationDescribingTitle => 'Describe it';

  @override
  String get situationDescribingDesc =>
      'Describe a person or a place you know well and what you think of them.';

  @override
  String get situationPlansTitle => 'Let’s make a plan';

  @override
  String get situationPlansDesc => 'Plan the weekend or a trip with someone.';

  @override
  String missionBanner(String title) {
    return 'Mission: $title';
  }

  @override
  String get missionFinish => 'Finish the mission';

  @override
  String get missionKeepGoing => 'Write a little more to be able to finish.';

  @override
  String get wordsStepIntro => 'Go over these words you have met.';

  @override
  String get wordsStepContext => 'Complete:';

  @override
  String get wordsStepReveal => 'Show the word';

  @override
  String get wordsStepFinish => 'I\'m done';

  @override
  String guidanceReasonReviews(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You have $count exercises to review.',
      one: 'You have 1 exercise to review.',
    );
    return '$_temp0';
  }

  @override
  String guidanceReasonTopic(String topic) {
    return 'Today we keep working on $topic.';
  }

  @override
  String guidanceReasonGoal(String goal) {
    return 'We keep working on your goal: $goal.';
  }

  @override
  String guidanceReasonWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You have $count words to consolidate.',
      one: 'You have 1 word to consolidate.',
    );
    return '$_temp0';
  }

  @override
  String get guidanceStart => 'Start your practice';

  @override
  String get guidanceContinue => 'Continue your practice';

  @override
  String get guidanceCompleted => 'Practice completed';

  @override
  String guidanceStepDone(String step) {
    return '$step: done';
  }

  @override
  String guidanceStepPending(String step) {
    return '$step: to do';
  }

  @override
  String guidanceStepNone(String step) {
    return '$step: nothing today';
  }
}
