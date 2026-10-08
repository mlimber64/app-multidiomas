import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('it'),
  ];

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t save. Please try again.'**
  String get couldNotSave;

  /// No description provided for @letsTalk.
  ///
  /// In en, this message translates to:
  /// **'Let\'s talk'**
  String get letsTalk;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk'**
  String get navTalk;

  /// No description provided for @navLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get navLearn;

  /// No description provided for @navWords.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get navWords;

  /// No description provided for @navPath.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get navPath;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi!'**
  String get homeGreeting;

  /// No description provided for @homeReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to practice today?'**
  String get homeReady;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Practice with your AI teacher.'**
  String get heroSubtitle;

  /// No description provided for @quickConversation.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get quickConversation;

  /// No description provided for @quickReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get quickReview;

  /// No description provided for @journeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your journey'**
  String get journeyTitle;

  /// No description provided for @rowLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get rowLanguage;

  /// No description provided for @rowLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get rowLevel;

  /// No description provided for @rowGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get rowGoals;

  /// No description provided for @rowFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get rowFocus;

  /// No description provided for @noteStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Your journey starts here.'**
  String get noteStartTitle;

  /// No description provided for @noteStartBody.
  ///
  /// In en, this message translates to:
  /// **'Have your first conversation to start building your journey.'**
  String get noteStartBody;

  /// No description provided for @noteFocusTitle.
  ///
  /// In en, this message translates to:
  /// **'Your focus'**
  String get noteFocusTitle;

  /// No description provided for @noteImprovingTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re improving'**
  String get noteImprovingTitle;

  /// No description provided for @noteKeepPracticing.
  ///
  /// In en, this message translates to:
  /// **'Keep practicing in your conversations.'**
  String get noteKeepPracticing;

  /// No description provided for @noteImprovingIn.
  ///
  /// In en, this message translates to:
  /// **'You\'re improving in: {topics}'**
  String noteImprovingIn(String topics);

  /// No description provided for @levelA1.
  ///
  /// In en, this message translates to:
  /// **'A1 — Beginner'**
  String get levelA1;

  /// No description provided for @levelA2.
  ///
  /// In en, this message translates to:
  /// **'A2 — Elementary'**
  String get levelA2;

  /// No description provided for @levelB1.
  ///
  /// In en, this message translates to:
  /// **'B1 — Intermediate'**
  String get levelB1;

  /// No description provided for @levelB2.
  ///
  /// In en, this message translates to:
  /// **'B2 — Upper intermediate'**
  String get levelB2;

  /// No description provided for @levelNotSure.
  ///
  /// In en, this message translates to:
  /// **'I\'m not sure'**
  String get levelNotSure;

  /// No description provided for @goalSpeakConfidently.
  ///
  /// In en, this message translates to:
  /// **'Speak with more confidence'**
  String get goalSpeakConfidently;

  /// No description provided for @goalUnderstandListening.
  ///
  /// In en, this message translates to:
  /// **'Understand better when listening'**
  String get goalUnderstandListening;

  /// No description provided for @goalWriteBetter.
  ///
  /// In en, this message translates to:
  /// **'Write better'**
  String get goalWriteBetter;

  /// No description provided for @goalLiveAbroad.
  ///
  /// In en, this message translates to:
  /// **'Live better abroad'**
  String get goalLiveAbroad;

  /// No description provided for @goalWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get goalWork;

  /// No description provided for @goalStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get goalStudy;

  /// No description provided for @goalEverything.
  ///
  /// In en, this message translates to:
  /// **'A bit of everything'**
  String get goalEverything;

  /// No description provided for @focusConversation.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get focusConversation;

  /// No description provided for @focusGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get focusGrammar;

  /// No description provided for @focusVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary'**
  String get focusVocabulary;

  /// No description provided for @focusPronunciation.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation'**
  String get focusPronunciation;

  /// No description provided for @focusComprehension.
  ///
  /// In en, this message translates to:
  /// **'Comprehension'**
  String get focusComprehension;

  /// No description provided for @topicPassatoProssimo.
  ///
  /// In en, this message translates to:
  /// **'Passato prossimo'**
  String get topicPassatoProssimo;

  /// No description provided for @topicEssereVsAvere.
  ///
  /// In en, this message translates to:
  /// **'Essere vs avere'**
  String get topicEssereVsAvere;

  /// No description provided for @topicPrepositions.
  ///
  /// In en, this message translates to:
  /// **'Prepositions'**
  String get topicPrepositions;

  /// No description provided for @topicArticles.
  ///
  /// In en, this message translates to:
  /// **'Articles'**
  String get topicArticles;

  /// No description provided for @topicGender.
  ///
  /// In en, this message translates to:
  /// **'Noun gender'**
  String get topicGender;

  /// No description provided for @topicPlural.
  ///
  /// In en, this message translates to:
  /// **'Plurals'**
  String get topicPlural;

  /// No description provided for @topicAgreement.
  ///
  /// In en, this message translates to:
  /// **'Agreement'**
  String get topicAgreement;

  /// No description provided for @topicPronouns.
  ///
  /// In en, this message translates to:
  /// **'Pronouns'**
  String get topicPronouns;

  /// No description provided for @topicVerbConjugation.
  ///
  /// In en, this message translates to:
  /// **'Verb conjugation'**
  String get topicVerbConjugation;

  /// No description provided for @topicWordOrder.
  ///
  /// In en, this message translates to:
  /// **'Word order'**
  String get topicWordOrder;

  /// No description provided for @topicToBe.
  ///
  /// In en, this message translates to:
  /// **'The verb \"to be\"'**
  String get topicToBe;

  /// No description provided for @topicPresentContinuous.
  ///
  /// In en, this message translates to:
  /// **'Present continuous'**
  String get topicPresentContinuous;

  /// No description provided for @topicPastSimple.
  ///
  /// In en, this message translates to:
  /// **'Past simple'**
  String get topicPastSimple;

  /// No description provided for @topicPresentPerfect.
  ///
  /// In en, this message translates to:
  /// **'Present perfect'**
  String get topicPresentPerfect;

  /// No description provided for @topicThirdPersonSingular.
  ///
  /// In en, this message translates to:
  /// **'Third-person singular'**
  String get topicThirdPersonSingular;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Talk'**
  String get chatTitle;

  /// No description provided for @newConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get newConversation;

  /// No description provided for @suggestionDay.
  ///
  /// In en, this message translates to:
  /// **'My day'**
  String get suggestionDay;

  /// No description provided for @suggestionWork.
  ///
  /// In en, this message translates to:
  /// **'Let\'s talk about work'**
  String get suggestionWork;

  /// No description provided for @suggestionRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Let\'s have a conversation at a restaurant'**
  String get suggestionRestaurant;

  /// No description provided for @suggestionPractice.
  ///
  /// In en, this message translates to:
  /// **'I want to practice a little'**
  String get suggestionPractice;

  /// No description provided for @chatWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Hi! I\'m your language teacher.'**
  String get chatWelcomeTitle;

  /// No description provided for @chatWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What do you want to talk about today?'**
  String get chatWelcomeSubtitle;

  /// No description provided for @chatErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'I can\'t answer right now. Shall we try again?'**
  String get chatErrorGeneric;

  /// No description provided for @correctMe.
  ///
  /// In en, this message translates to:
  /// **'Correct me'**
  String get correctMe;

  /// No description provided for @correctMeHint.
  ///
  /// In en, this message translates to:
  /// **'The teacher will correct more carefully'**
  String get correctMeHint;

  /// No description provided for @composerHint.
  ///
  /// In en, this message translates to:
  /// **'Write in the language you are learning…'**
  String get composerHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @roleYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get roleYou;

  /// No description provided for @roleTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get roleTeacher;

  /// No description provided for @youWrote.
  ///
  /// In en, this message translates to:
  /// **'You wrote: '**
  String get youWrote;

  /// No description provided for @better.
  ///
  /// In en, this message translates to:
  /// **'Better: '**
  String get better;

  /// No description provided for @moreNatural.
  ///
  /// In en, this message translates to:
  /// **'More natural: {alternative}'**
  String moreNatural(String alternative);

  /// No description provided for @categoryGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get categoryGrammar;

  /// No description provided for @categoryVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary'**
  String get categoryVocabulary;

  /// No description provided for @categoryPronunciation.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation'**
  String get categoryPronunciation;

  /// No description provided for @categoryNaturalExpression.
  ///
  /// In en, this message translates to:
  /// **'Natural expression'**
  String get categoryNaturalExpression;

  /// No description provided for @categorySpelling.
  ///
  /// In en, this message translates to:
  /// **'Spelling'**
  String get categorySpelling;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get categoryOther;

  /// No description provided for @teacherTyping.
  ///
  /// In en, this message translates to:
  /// **'The teacher is typing'**
  String get teacherTyping;

  /// No description provided for @aiNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'The teacher is not configured yet. Add the Gemini API key (see the README).'**
  String get aiNotConfigured;

  /// No description provided for @aiNetwork.
  ///
  /// In en, this message translates to:
  /// **'I can\'t connect. Check your connection and we\'ll try again.'**
  String get aiNetwork;

  /// No description provided for @aiRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests in a short time. Wait a moment and we will try again.'**
  String get aiRateLimited;

  /// No description provided for @learnImprove.
  ///
  /// In en, this message translates to:
  /// **'What you can improve'**
  String get learnImprove;

  /// No description provided for @learnPriorities.
  ///
  /// In en, this message translates to:
  /// **'Your priorities'**
  String get learnPriorities;

  /// No description provided for @learnHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How to work on it'**
  String get learnHowTitle;

  /// No description provided for @learnHowBody.
  ///
  /// In en, this message translates to:
  /// **'These areas are trained by speaking: keep using them in your conversations and I will help you naturally.'**
  String get learnHowBody;

  /// No description provided for @learnDoingWellTitle.
  ///
  /// In en, this message translates to:
  /// **'You are doing well'**
  String get learnDoingWellTitle;

  /// No description provided for @learnDoingWellBody.
  ///
  /// In en, this message translates to:
  /// **'For now there are no urgent areas to reinforce. Keep talking with me.'**
  String get learnDoingWellBody;

  /// No description provided for @learnEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Here you will see what to improve'**
  String get learnEmptyTitle;

  /// No description provided for @learnEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When you talk to me, you will find here the areas worth focusing on.'**
  String get learnEmptyBody;

  /// No description provided for @topicProgressMade.
  ///
  /// In en, this message translates to:
  /// **'You have already made progress. Let us keep working on it.'**
  String get topicProgressMade;

  /// No description provided for @topicWorthFocus.
  ///
  /// In en, this message translates to:
  /// **'It is worth focusing here.'**
  String get topicWorthFocus;

  /// No description provided for @relatedTo.
  ///
  /// In en, this message translates to:
  /// **'Related to: {topics}'**
  String relatedTo(String topics);

  /// No description provided for @topicImprovingDetail.
  ///
  /// In en, this message translates to:
  /// **'You are improving: you use it better and better.'**
  String get topicImprovingDetail;

  /// No description provided for @topicProgressWorth.
  ///
  /// In en, this message translates to:
  /// **'You have already made progress, but it is still worth working on.'**
  String get topicProgressWorth;

  /// No description provided for @workingOn.
  ///
  /// In en, this message translates to:
  /// **'You are working on'**
  String get workingOn;

  /// No description provided for @recurringErrors.
  ///
  /// In en, this message translates to:
  /// **'Recurring mistakes'**
  String get recurringErrors;

  /// No description provided for @mistakes.
  ///
  /// In en, this message translates to:
  /// **'Mistakes'**
  String get mistakes;

  /// No description provided for @keepUsingIt.
  ///
  /// In en, this message translates to:
  /// **'Keep using it in your conversations.'**
  String get keepUsingIt;

  /// No description provided for @topicToConsolidate.
  ///
  /// In en, this message translates to:
  /// **'Still to consolidate'**
  String get topicToConsolidate;

  /// No description provided for @topicImprovingStatus.
  ///
  /// In en, this message translates to:
  /// **'You use it better and better'**
  String get topicImprovingStatus;

  /// No description provided for @correctOutOf.
  ///
  /// In en, this message translates to:
  /// **'Correct {correct, plural, =1{1 time} other{{correct} times}} out of {total}'**
  String correctOutOf(int correct, int total);

  /// No description provided for @errorPairSemantics.
  ///
  /// In en, this message translates to:
  /// **'You wrote {incorrect}, better {correct}'**
  String errorPairSemantics(String incorrect, String correct);

  /// No description provided for @vocabInUse.
  ///
  /// In en, this message translates to:
  /// **'You are using it'**
  String get vocabInUse;

  /// No description provided for @vocabUsedCorrectly.
  ///
  /// In en, this message translates to:
  /// **'You have already used it correctly'**
  String get vocabUsedCorrectly;

  /// No description provided for @vocabToConsolidate.
  ///
  /// In en, this message translates to:
  /// **'To consolidate'**
  String get vocabToConsolidate;

  /// No description provided for @overviewError.
  ///
  /// In en, this message translates to:
  /// **'I can\'t show your journey right now. Shall we try again?'**
  String get overviewError;

  /// No description provided for @progressIntro.
  ///
  /// In en, this message translates to:
  /// **'Here you see how your learning evolves, based on how you speak.'**
  String get progressIntro;

  /// No description provided for @progressEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re starting to get to know you.'**
  String get progressEmptyTitle;

  /// No description provided for @progressEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Talk to me and here you will see how your journey evolves.'**
  String get progressEmptyBody;

  /// No description provided for @progressToReinforce.
  ///
  /// In en, this message translates to:
  /// **'To reinforce'**
  String get progressToReinforce;

  /// No description provided for @progressRecurringSub.
  ///
  /// In en, this message translates to:
  /// **'You have written them more than once.'**
  String get progressRecurringSub;

  /// No description provided for @seeAllWords.
  ///
  /// In en, this message translates to:
  /// **'See all words'**
  String get seeAllWords;

  /// No description provided for @wordsHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your words'**
  String get wordsHeadline;

  /// No description provided for @wordsIntro.
  ///
  /// In en, this message translates to:
  /// **'The words you meet while talking with me.'**
  String get wordsIntro;

  /// No description provided for @wordsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your words will appear here'**
  String get wordsEmptyTitle;

  /// No description provided for @wordsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When you meet new words while talking with me, you will find them on this page.'**
  String get wordsEmptyBody;

  /// No description provided for @wordsToConsolidateTitle.
  ///
  /// In en, this message translates to:
  /// **'Words to consolidate'**
  String get wordsToConsolidateTitle;

  /// No description provided for @wordsToConsolidateSub.
  ///
  /// In en, this message translates to:
  /// **'You have met them: keep using them.'**
  String get wordsToConsolidateSub;

  /// No description provided for @wordsInUseTitle.
  ///
  /// In en, this message translates to:
  /// **'Words you are using'**
  String get wordsInUseTitle;

  /// No description provided for @wordsInUseSub.
  ///
  /// In en, this message translates to:
  /// **'You have already used them correctly several times.'**
  String get wordsInUseSub;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Your personal language teacher.'**
  String get welcomeTagline;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Practice a language in a personal way: we will ask you a few questions to get to know you, so you can start learning from where you are.'**
  String get welcomeBody;

  /// No description provided for @onbStart.
  ///
  /// In en, this message translates to:
  /// **'Let\'s start'**
  String get onbStart;

  /// No description provided for @onbFinish.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onbFinish;

  /// No description provided for @onbStepSemantics.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String onbStepSemantics(int step, int total);

  /// No description provided for @onbLanguagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your languages'**
  String get onbLanguagesTitle;

  /// No description provided for @supportLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Support language'**
  String get supportLanguageLabel;

  /// No description provided for @learnLanguageQuestion.
  ///
  /// In en, this message translates to:
  /// **'Language you want to learn'**
  String get learnLanguageQuestion;

  /// No description provided for @levelQuestion.
  ///
  /// In en, this message translates to:
  /// **'How well do you already know this language?'**
  String get levelQuestion;

  /// No description provided for @goalsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Why do you want to learn this language?'**
  String get goalsQuestion;

  /// No description provided for @focusQuestion.
  ///
  /// In en, this message translates to:
  /// **'What do you want to focus on?'**
  String get focusQuestion;

  /// No description provided for @selectionHint.
  ///
  /// In en, this message translates to:
  /// **'Choose {min} to {max} · {count} selected'**
  String selectionHint(int min, int max, int count);

  /// No description provided for @profileHeading.
  ///
  /// In en, this message translates to:
  /// **'Your learning'**
  String get profileHeading;

  /// No description provided for @uiLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get uiLanguageLabel;

  /// No description provided for @learningLanguageRow.
  ///
  /// In en, this message translates to:
  /// **'Language you are learning'**
  String get learningLanguageRow;

  /// No description provided for @supportSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Which language do you prefer for explanations?'**
  String get supportSheetTitle;

  /// No description provided for @learnSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Which language do you want to learn?'**
  String get learnSheetTitle;

  /// No description provided for @uiSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Which language do you want the app in?'**
  String get uiSheetTitle;

  /// No description provided for @rowAreas.
  ///
  /// In en, this message translates to:
  /// **'Areas'**
  String get rowAreas;

  /// No description provided for @profileLocalNote.
  ///
  /// In en, this message translates to:
  /// **'Your preferences stay on this device.'**
  String get profileLocalNote;

  /// No description provided for @reviewPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your review'**
  String get reviewPreparing;

  /// No description provided for @reviewError.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t prepare your review. Please try again.'**
  String get reviewError;

  /// No description provided for @exerciseProgress.
  ///
  /// In en, this message translates to:
  /// **'{position} of {total}'**
  String exerciseProgress(int position, int total);

  /// No description provided for @exerciseSemantics.
  ///
  /// In en, this message translates to:
  /// **'Exercise {position} of {total}'**
  String exerciseSemantics(int position, int total);

  /// No description provided for @instructionCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct the sentence'**
  String get instructionCorrect;

  /// No description provided for @instructionChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose the correct answer'**
  String get instructionChoose;

  /// No description provided for @instructionComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete the sentence'**
  String get instructionComplete;

  /// No description provided for @yourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get yourAnswer;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @correctAnswerTag.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get correctAnswerTag;

  /// No description provided for @feedbackCorrect.
  ///
  /// In en, this message translates to:
  /// **'Exactly!'**
  String get feedbackCorrect;

  /// No description provided for @feedbackIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Almost.'**
  String get feedbackIncorrect;

  /// No description provided for @yourAnswerWas.
  ///
  /// In en, this message translates to:
  /// **'Your answer: {answer}'**
  String yourAnswerWas(String answer);

  /// No description provided for @correctAnswerIs.
  ///
  /// In en, this message translates to:
  /// **'The correct answer is:'**
  String get correctAnswerIs;

  /// No description provided for @backToPath.
  ///
  /// In en, this message translates to:
  /// **'Back to your journey'**
  String get backToPath;

  /// No description provided for @reviewEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No review available'**
  String get reviewEmptyTitle;

  /// No description provided for @reviewEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'There are no exercises ready for now. Keep talking and we will come back here when there is something to review.'**
  String get reviewEmptyBody;

  /// No description provided for @reviewDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Review complete'**
  String get reviewDoneTitle;

  /// No description provided for @exercisesDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise completed} other{{count} exercises completed}}'**
  String exercisesDone(int count);

  /// No description provided for @correctCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 correct} other{{count} correct}}'**
  String correctCount(int count);

  /// No description provided for @toRetry.
  ///
  /// In en, this message translates to:
  /// **'{count} to retry'**
  String toRetry(int count);

  /// No description provided for @topicEtreVsAvoir.
  ///
  /// In en, this message translates to:
  /// **'Être vs avoir'**
  String get topicEtreVsAvoir;

  /// No description provided for @topicPasseCompose.
  ///
  /// In en, this message translates to:
  /// **'Passé composé'**
  String get topicPasseCompose;

  /// No description provided for @topicSerVsEstar.
  ///
  /// In en, this message translates to:
  /// **'Ser vs estar'**
  String get topicSerVsEstar;

  /// No description provided for @topicHabenVsSein.
  ///
  /// In en, this message translates to:
  /// **'Haben vs sein'**
  String get topicHabenVsSein;

  /// No description provided for @topicPerfekt.
  ///
  /// In en, this message translates to:
  /// **'Perfekt'**
  String get topicPerfekt;

  /// No description provided for @topicCases.
  ///
  /// In en, this message translates to:
  /// **'Cases (Kasus)'**
  String get topicCases;

  /// No description provided for @topicPorVsPara.
  ///
  /// In en, this message translates to:
  /// **'Por vs para'**
  String get topicPorVsPara;

  /// No description provided for @topicMeasureWords.
  ///
  /// In en, this message translates to:
  /// **'Measure words (量词)'**
  String get topicMeasureWords;

  /// No description provided for @topicStructuralParticles.
  ///
  /// In en, this message translates to:
  /// **'Particles 的 / 得 / 地'**
  String get topicStructuralParticles;

  /// No description provided for @topicAspectParticles.
  ///
  /// In en, this message translates to:
  /// **'Aspect particles (了, 过, 着)'**
  String get topicAspectParticles;

  /// No description provided for @topicNegation.
  ///
  /// In en, this message translates to:
  /// **'Negation (不 / 没)'**
  String get topicNegation;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @listenSlowly.
  ///
  /// In en, this message translates to:
  /// **'Slowly'**
  String get listenSlowly;

  /// No description provided for @spellIt.
  ///
  /// In en, this message translates to:
  /// **'Spell it'**
  String get spellIt;

  /// No description provided for @stopListening.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopListening;

  /// No description provided for @hearItRight.
  ///
  /// In en, this message translates to:
  /// **'Hear how it is said and written correctly:'**
  String get hearItRight;

  /// No description provided for @translationLabel.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translationLabel;

  /// No description provided for @teacherVoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Teacher\'s voice'**
  String get teacherVoiceLabel;

  /// No description provided for @teacherVoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Used when the teacher\'s messages are read aloud. The exact voice depends on the ones installed on your phone.'**
  String get teacherVoiceHint;

  /// No description provided for @voiceFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get voiceFemale;

  /// No description provided for @voiceMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get voiceMale;

  /// No description provided for @listenToMessage.
  ///
  /// In en, this message translates to:
  /// **'Listen to the message'**
  String get listenToMessage;

  /// No description provided for @noVoiceInstalled.
  ///
  /// In en, this message translates to:
  /// **'Your phone has no voice installed for this language. You can install one in Settings, Language, Text-to-speech output.'**
  String get noVoiceInstalled;

  /// No description provided for @speechFailed.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t play the audio.'**
  String get speechFailed;

  /// No description provided for @speakRepliesLabel.
  ///
  /// In en, this message translates to:
  /// **'Read replies aloud'**
  String get speakRepliesLabel;

  /// No description provided for @speakRepliesHint.
  ///
  /// In en, this message translates to:
  /// **'Replies to your voice messages are always read.'**
  String get speakRepliesHint;

  /// No description provided for @recordVoice.
  ///
  /// In en, this message translates to:
  /// **'Record a voice message'**
  String get recordVoice;

  /// No description provided for @recordingNow.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordingNow;

  /// No description provided for @recordingCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel the recording'**
  String get recordingCancel;

  /// No description provided for @recordingSend.
  ///
  /// In en, this message translates to:
  /// **'Send the voice message'**
  String get recordingSend;

  /// No description provided for @micDenied.
  ///
  /// In en, this message translates to:
  /// **'I need permission to use the microphone. You can turn it on in the phone settings.'**
  String get micDenied;

  /// No description provided for @micFailed.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t start recording.'**
  String get micFailed;

  /// No description provided for @recordingTooShort.
  ///
  /// In en, this message translates to:
  /// **'The recording was too short. Speak a little longer.'**
  String get recordingTooShort;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceMessage;

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get voiceListening;

  /// No description provided for @voiceNotUnderstood.
  ///
  /// In en, this message translates to:
  /// **'The audio was not understood'**
  String get voiceNotUnderstood;

  /// No description provided for @routineTitle.
  ///
  /// In en, this message translates to:
  /// **'Your practice for today'**
  String get routineTitle;

  /// No description provided for @routineIntro.
  ///
  /// In en, this message translates to:
  /// **'This is what is worth practicing today.'**
  String get routineIntro;

  /// No description provided for @routinePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your practice'**
  String get routinePreparing;

  /// No description provided for @routineError.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t prepare your practice for today. Please try again.'**
  String get routineError;

  /// No description provided for @routineStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Consolidate'**
  String get routineStep3Title;

  /// No description provided for @routineReviewDesc.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise to review} other{{count} exercises to review}}'**
  String routineReviewDesc(int count);

  /// No description provided for @routineReviewNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review today.'**
  String get routineReviewNone;

  /// No description provided for @routineWordsDesc.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word to consolidate} other{{count} words to consolidate}}'**
  String routineWordsDesc(int count);

  /// No description provided for @routineWordsNone.
  ///
  /// In en, this message translates to:
  /// **'No words to consolidate today.'**
  String get routineWordsNone;

  /// No description provided for @routineStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get routineStepDone;

  /// No description provided for @routineStepLocked.
  ///
  /// In en, this message translates to:
  /// **'Finish the previous step first.'**
  String get routineStepLocked;

  /// No description provided for @routineCtaStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get routineCtaStart;

  /// No description provided for @routineContinue.
  ///
  /// In en, this message translates to:
  /// **'Back to your practice'**
  String get routineContinue;

  /// No description provided for @routineCompleted.
  ///
  /// In en, this message translates to:
  /// **'Done for today! 🎉'**
  String get routineCompleted;

  /// No description provided for @routineCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve done today\'s practice. Come back tomorrow.'**
  String get routineCompletedBody;

  /// No description provided for @routineProgress.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total}'**
  String routineProgress(int done, int total);

  /// No description provided for @routineProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} steps done'**
  String routineProgressSemantics(int done, int total);

  /// No description provided for @situationIntroductionTitle.
  ///
  /// In en, this message translates to:
  /// **'Introduce yourself'**
  String get situationIntroductionTitle;

  /// No description provided for @situationIntroductionDesc.
  ///
  /// In en, this message translates to:
  /// **'You meet someone at a party: talk about where you live, what you do and what you enjoy.'**
  String get situationIntroductionDesc;

  /// No description provided for @situationYesterdayTitle.
  ///
  /// In en, this message translates to:
  /// **'What did you do yesterday?'**
  String get situationYesterdayTitle;

  /// No description provided for @situationYesterdayDesc.
  ///
  /// In en, this message translates to:
  /// **'A friend asks how yesterday went: tell them where you went and what you did.'**
  String get situationYesterdayDesc;

  /// No description provided for @situationWorkdayTitle.
  ///
  /// In en, this message translates to:
  /// **'Your day'**
  String get situationWorkdayTitle;

  /// No description provided for @situationWorkdayDesc.
  ///
  /// In en, this message translates to:
  /// **'A colleague asks about your day at work or study.'**
  String get situationWorkdayDesc;

  /// No description provided for @situationCafeTitle.
  ///
  /// In en, this message translates to:
  /// **'At the café'**
  String get situationCafeTitle;

  /// No description provided for @situationCafeDesc.
  ///
  /// In en, this message translates to:
  /// **'Order something to eat and drink and ask a question about the place.'**
  String get situationCafeDesc;

  /// No description provided for @situationDirectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'How do I get there?'**
  String get situationDirectionsTitle;

  /// No description provided for @situationDirectionsDesc.
  ///
  /// In en, this message translates to:
  /// **'You are in a town you do not know: ask how to get to a place.'**
  String get situationDirectionsDesc;

  /// No description provided for @situationShoppingTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get situationShoppingTitle;

  /// No description provided for @situationShoppingDesc.
  ///
  /// In en, this message translates to:
  /// **'Look for something to buy: ask about size, color and price.'**
  String get situationShoppingDesc;

  /// No description provided for @situationDescribingTitle.
  ///
  /// In en, this message translates to:
  /// **'Describe it'**
  String get situationDescribingTitle;

  /// No description provided for @situationDescribingDesc.
  ///
  /// In en, this message translates to:
  /// **'Describe a person or a place you know well and what you think of them.'**
  String get situationDescribingDesc;

  /// No description provided for @situationPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'Let’s make a plan'**
  String get situationPlansTitle;

  /// No description provided for @situationPlansDesc.
  ///
  /// In en, this message translates to:
  /// **'Plan the weekend or a trip with someone.'**
  String get situationPlansDesc;

  /// No description provided for @missionBanner.
  ///
  /// In en, this message translates to:
  /// **'Mission: {title}'**
  String missionBanner(String title);

  /// No description provided for @missionFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish the mission'**
  String get missionFinish;

  /// No description provided for @missionKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Write a little more to be able to finish.'**
  String get missionKeepGoing;

  /// No description provided for @wordsStepIntro.
  ///
  /// In en, this message translates to:
  /// **'Go over these words you have met.'**
  String get wordsStepIntro;

  /// No description provided for @wordsStepContext.
  ///
  /// In en, this message translates to:
  /// **'Complete:'**
  String get wordsStepContext;

  /// No description provided for @wordsStepReveal.
  ///
  /// In en, this message translates to:
  /// **'Show the word'**
  String get wordsStepReveal;

  /// No description provided for @wordsStepFinish.
  ///
  /// In en, this message translates to:
  /// **'I\'m done'**
  String get wordsStepFinish;

  /// No description provided for @guidanceReasonReviews.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You have 1 exercise to review.} other{You have {count} exercises to review.}}'**
  String guidanceReasonReviews(int count);

  /// No description provided for @guidanceReasonTopic.
  ///
  /// In en, this message translates to:
  /// **'Today we keep working on {topic}.'**
  String guidanceReasonTopic(String topic);

  /// No description provided for @guidanceReasonGoal.
  ///
  /// In en, this message translates to:
  /// **'We keep working on your goal: {goal}.'**
  String guidanceReasonGoal(String goal);

  /// No description provided for @guidanceReasonWords.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You have 1 word to consolidate.} other{You have {count} words to consolidate.}}'**
  String guidanceReasonWords(int count);

  /// No description provided for @guidanceStart.
  ///
  /// In en, this message translates to:
  /// **'Start your practice'**
  String get guidanceStart;

  /// No description provided for @guidanceContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue your practice'**
  String get guidanceContinue;

  /// No description provided for @guidanceCompleted.
  ///
  /// In en, this message translates to:
  /// **'Practice completed'**
  String get guidanceCompleted;

  /// No description provided for @guidanceStepDone.
  ///
  /// In en, this message translates to:
  /// **'{step}: done'**
  String guidanceStepDone(String step);

  /// No description provided for @guidanceStepPending.
  ///
  /// In en, this message translates to:
  /// **'{step}: to do'**
  String guidanceStepPending(String step);

  /// No description provided for @guidanceStepNone.
  ///
  /// In en, this message translates to:
  /// **'{step}: nothing today'**
  String guidanceStepNone(String step);

  /// No description provided for @homeStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String homeStreakDays(int count);

  /// No description provided for @streakLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1-day streak} other{{count}-day streak}}'**
  String streakLabel(int count);

  /// No description provided for @routineStartPractice.
  ///
  /// In en, this message translates to:
  /// **'Start practice'**
  String get routineStartPractice;

  /// No description provided for @routineHeroReview.
  ///
  /// In en, this message translates to:
  /// **'Review what you saw'**
  String get routineHeroReview;

  /// No description provided for @routineHeroTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk with your teacher'**
  String get routineHeroTalk;

  /// No description provided for @routineHeroWords.
  ///
  /// In en, this message translates to:
  /// **'Consolidate your words'**
  String get routineHeroWords;

  /// No description provided for @homeTileConversationSub.
  ///
  /// In en, this message translates to:
  /// **'Free talk'**
  String get homeTileConversationSub;

  /// No description provided for @homeTileLearnSub.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 area to reinforce} other{{count} areas to reinforce}}'**
  String homeTileLearnSub(int count);

  /// No description provided for @homeTileLearnNone.
  ///
  /// In en, this message translates to:
  /// **'What to reinforce'**
  String get homeTileLearnNone;

  /// No description provided for @homeTileReviewSub.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pending} other{{count} pending}}'**
  String homeTileReviewSub(int count);

  /// No description provided for @homeTileReviewNone.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get homeTileReviewNone;

  /// No description provided for @homeTileWordsSub.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 to consolidate} other{{count} to consolidate}}'**
  String homeTileWordsSub(int count);

  /// No description provided for @homeTileWordsNone.
  ///
  /// In en, this message translates to:
  /// **'Your vocabulary'**
  String get homeTileWordsNone;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority: {level}'**
  String priorityLabel(String level);

  /// No description provided for @learnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What to work on now'**
  String get learnSubtitle;

  /// No description provided for @wordsTabToConsolidate.
  ///
  /// In en, this message translates to:
  /// **'To consolidate'**
  String get wordsTabToConsolidate;

  /// No description provided for @wordsTabInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get wordsTabInUse;

  /// No description provided for @wordsTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get wordsTabAll;

  /// No description provided for @wordsNoMeaning.
  ///
  /// In en, this message translates to:
  /// **'No meaning saved yet'**
  String get wordsNoMeaning;

  /// No description provided for @wordUsesSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Not used correctly yet} =1{Used correctly once} other{Used correctly {count} times}}'**
  String wordUsesSemantics(int count);

  /// No description provided for @progressRingCaption.
  ///
  /// In en, this message translates to:
  /// **'{improving} of {total} areas improving'**
  String progressRingCaption(int improving, int total);

  /// No description provided for @progressWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get progressWeekTitle;

  /// No description provided for @weekInitials.
  ///
  /// In en, this message translates to:
  /// **'M,T,W,T,F,S,S'**
  String get weekInitials;

  /// No description provided for @weekSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No practice days this week} =1{1 practice day this week} other{{count} practice days this week}}'**
  String weekSemantics(int count);

  /// No description provided for @statWords.
  ///
  /// In en, this message translates to:
  /// **'Words met'**
  String get statWords;

  /// No description provided for @statImproving.
  ///
  /// In en, this message translates to:
  /// **'Areas improving'**
  String get statImproving;

  /// No description provided for @statReinforce.
  ///
  /// In en, this message translates to:
  /// **'Areas to reinforce'**
  String get statReinforce;

  /// No description provided for @voiceTest.
  ///
  /// In en, this message translates to:
  /// **'Test voice'**
  String get voiceTest;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
