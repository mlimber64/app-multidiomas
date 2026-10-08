// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get tryAgain => 'Riprova';

  @override
  String get save => 'Salva';

  @override
  String get back => 'Indietro';

  @override
  String get notSet => 'Non impostato';

  @override
  String get couldNotSave => 'Non sono riuscito a salvare. Riprova.';

  @override
  String get letsTalk => 'Parliamo';

  @override
  String get continueAction => 'Continua';

  @override
  String get navHome => 'Home';

  @override
  String get navTalk => 'Parla';

  @override
  String get navLearn => 'Impara';

  @override
  String get navWords => 'Parole';

  @override
  String get navPath => 'Percorso';

  @override
  String get navProfile => 'Profilo';

  @override
  String get homeGreeting => 'Ciao!';

  @override
  String get homeReady => 'Pronto a fare pratica oggi?';

  @override
  String get heroSubtitle => 'Fai pratica con il tuo insegnante AI.';

  @override
  String get quickConversation => 'Conversazione';

  @override
  String get quickReview => 'Ripassa';

  @override
  String get journeyTitle => 'Il tuo percorso';

  @override
  String get rowLanguage => 'Lingua';

  @override
  String get rowLevel => 'Livello';

  @override
  String get rowGoals => 'Obiettivi';

  @override
  String get rowFocus => 'Focus';

  @override
  String get noteStartTitle => 'Il tuo percorso inizia qui.';

  @override
  String get noteStartBody =>
      'Fai la tua prima conversazione per iniziare a costruire il tuo percorso.';

  @override
  String get noteFocusTitle => 'Il tuo focus';

  @override
  String get noteImprovingTitle => 'Stai migliorando';

  @override
  String get noteKeepPracticing => 'Continua a praticare nelle conversazioni.';

  @override
  String noteImprovingIn(String topics) {
    return 'Stai migliorando in: $topics';
  }

  @override
  String get levelA1 => 'A1 — Principiante';

  @override
  String get levelA2 => 'A2 — Elementare';

  @override
  String get levelB1 => 'B1 — Intermedio';

  @override
  String get levelB2 => 'B2 — Intermedio alto';

  @override
  String get levelNotSure => 'Non sono sicuro';

  @override
  String get goalSpeakConfidently => 'Parlare con più sicurezza';

  @override
  String get goalUnderstandListening => 'Capire meglio quando ascolto';

  @override
  String get goalWriteBetter => 'Scrivere meglio';

  @override
  String get goalLiveAbroad => 'Vivere meglio all’estero';

  @override
  String get goalWork => 'Lavoro';

  @override
  String get goalStudy => 'Studio';

  @override
  String get goalEverything => 'Un po\' di tutto';

  @override
  String get focusConversation => 'Conversazione';

  @override
  String get focusGrammar => 'Grammatica';

  @override
  String get focusVocabulary => 'Vocabolario';

  @override
  String get focusPronunciation => 'Pronuncia';

  @override
  String get focusComprehension => 'Comprensione';

  @override
  String get topicPassatoProssimo => 'Passato prossimo';

  @override
  String get topicEssereVsAvere => 'Essere e avere';

  @override
  String get topicPrepositions => 'Preposizioni';

  @override
  String get topicArticles => 'Articoli';

  @override
  String get topicGender => 'Genere dei nomi';

  @override
  String get topicPlural => 'Plurali';

  @override
  String get topicAgreement => 'Concordanza';

  @override
  String get topicPronouns => 'Pronomi';

  @override
  String get topicVerbConjugation => 'Coniugazione dei verbi';

  @override
  String get topicWordOrder => 'Ordine delle parole';

  @override
  String get topicToBe => 'Il verbo \"to be\"';

  @override
  String get topicPresentContinuous => 'Present continuous';

  @override
  String get topicPastSimple => 'Past simple';

  @override
  String get topicPresentPerfect => 'Present perfect';

  @override
  String get topicThirdPersonSingular => 'Terza persona singolare';

  @override
  String get chatTitle => 'Parla';

  @override
  String get newConversation => 'Nuova conversazione';

  @override
  String get suggestionDay => 'La mia giornata';

  @override
  String get suggestionWork => 'Parliamo del lavoro';

  @override
  String get suggestionRestaurant => 'Facciamo una conversazione al ristorante';

  @override
  String get suggestionPractice => 'Voglio fare un po’ di pratica';

  @override
  String get chatWelcomeTitle => 'Ciao! Sono il tuo insegnante di lingue.';

  @override
  String get chatWelcomeSubtitle => 'Di cosa vuoi parlare oggi?';

  @override
  String get chatErrorGeneric =>
      'Non riesco a rispondere in questo momento. Riproviamo?';

  @override
  String get correctMe => 'Correggimi';

  @override
  String get correctMeHint => 'Il professore correggerà con più attenzione';

  @override
  String get composerHint => 'Scrivi nella lingua che impari…';

  @override
  String get send => 'Invia';

  @override
  String get roleYou => 'Tu';

  @override
  String get roleTeacher => 'Insegnante';

  @override
  String get youWrote => 'Hai scritto: ';

  @override
  String get better => 'Meglio: ';

  @override
  String moreNatural(String alternative) {
    return 'Più naturale: $alternative';
  }

  @override
  String get categoryGrammar => 'Grammatica';

  @override
  String get categoryVocabulary => 'Vocabolario';

  @override
  String get categoryPronunciation => 'Pronuncia';

  @override
  String get categoryNaturalExpression => 'Espressione naturale';

  @override
  String get categorySpelling => 'Ortografia';

  @override
  String get categoryOther => 'Correzione';

  @override
  String get teacherTyping => 'Il professore sta scrivendo';

  @override
  String get aiNotConfigured =>
      'Il professore non è ancora configurato. Aggiungi la chiave API di Gemini (vedi README).';

  @override
  String get aiNetwork =>
      'Non riesco a connettermi. Controlla la connessione e riproviamo?';

  @override
  String get aiRateLimited =>
      'Troppe richieste in poco tempo. Aspetta un momento e riproviamo?';

  @override
  String get learnImprove => 'Cosa puoi migliorare';

  @override
  String get learnPriorities => 'Le tue priorità';

  @override
  String get learnHowTitle => 'Come lavorarci';

  @override
  String get learnHowBody =>
      'Queste aree si allenano parlando: continua a usarle nelle conversazioni e io ti aiuterò in modo naturale.';

  @override
  String get learnDoingWellTitle => 'Stai andando bene';

  @override
  String get learnDoingWellBody =>
      'Al momento non ci sono aree urgenti da rinforzare. Continua a parlare con me.';

  @override
  String get learnEmptyTitle => 'Qui vedrai cosa migliorare';

  @override
  String get learnEmptyBody =>
      'Quando parlerai con me, qui troverai le aree su cui vale la pena concentrarsi.';

  @override
  String get topicProgressMade =>
      'Hai già fatto progressi. Continuiamo a lavorarci.';

  @override
  String get topicWorthFocus => 'Vale la pena concentrarsi qui.';

  @override
  String relatedTo(String topics) {
    return 'Collegato a: $topics';
  }

  @override
  String get topicImprovingDetail => 'Stai migliorando: lo usi sempre meglio.';

  @override
  String get topicProgressWorth =>
      'Hai già fatto progressi, ma vale ancora la pena lavorarci.';

  @override
  String get workingOn => 'Stai lavorando su';

  @override
  String get recurringErrors => 'Errori ricorrenti';

  @override
  String get mistakes => 'Errori';

  @override
  String get keepUsingIt => 'Continua a usarlo nelle conversazioni.';

  @override
  String get topicToConsolidate => 'Ancora da consolidare';

  @override
  String get topicImprovingStatus => 'Lo usi sempre meglio';

  @override
  String correctOutOf(int correct, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      correct,
      locale: localeName,
      other: '$correct volte',
      one: '1 volta',
    );
    return 'Corretto $_temp0 su $total';
  }

  @override
  String errorPairSemantics(String incorrect, String correct) {
    return 'Hai scritto $incorrect, meglio $correct';
  }

  @override
  String get vocabInUse => 'La stai usando';

  @override
  String get vocabUsedCorrectly => 'L\'hai già usata correttamente';

  @override
  String get vocabToConsolidate => 'Da consolidare';

  @override
  String get overviewError =>
      'Non riesco a mostrare il tuo percorso in questo momento. Riproviamo?';

  @override
  String get progressIntro =>
      'Qui vedi come evolve il tuo apprendimento, in base a come parli.';

  @override
  String get progressEmptyTitle => 'Stiamo iniziando a conoscerti.';

  @override
  String get progressEmptyBody =>
      'Parla con me e qui vedrai come evolve il tuo percorso.';

  @override
  String get progressToReinforce => 'Da rinforzare';

  @override
  String get progressRecurringSub => 'Li hai scritti più di una volta.';

  @override
  String get seeAllWords => 'Vedi tutte le parole';

  @override
  String get wordsHeadline => 'Le tue parole';

  @override
  String get wordsIntro => 'Le parole che incontri parlando con me.';

  @override
  String get wordsEmptyTitle => 'Le tue parole appariranno qui';

  @override
  String get wordsEmptyBody =>
      'Quando incontrerai parole nuove parlando con me, le troverai in questa pagina.';

  @override
  String get wordsToConsolidateTitle => 'Parole da consolidare';

  @override
  String get wordsToConsolidateSub => 'Le hai incontrate: continua a usarle.';

  @override
  String get wordsInUseTitle => 'Parole che stai usando';

  @override
  String get wordsInUseSub => 'Le hai già usate correttamente più volte.';

  @override
  String get welcomeTagline => 'Il tuo insegnante di lingue personale.';

  @override
  String get welcomeBody =>
      'Pratica una lingua in modo personale: ti faremo qualche domanda per conoscerti, così potrai iniziare a imparare partendo da te.';

  @override
  String get onbStart => 'Iniziamo';

  @override
  String get onbFinish => 'Inizia';

  @override
  String onbStepSemantics(int step, int total) {
    return 'Passo $step di $total';
  }

  @override
  String get onbLanguagesTitle => 'Le tue lingue';

  @override
  String get supportLanguageLabel => 'Lingua di supporto';

  @override
  String get learnLanguageQuestion => 'Lingua che vuoi imparare';

  @override
  String get levelQuestion => 'Quanto conosci già questa lingua?';

  @override
  String get goalsQuestion => 'Perché vuoi imparare questa lingua?';

  @override
  String get focusQuestion => 'Su cosa vuoi concentrarti?';

  @override
  String selectionHint(int min, int max, int count) {
    return 'Scegli da $min a $max · $count selezionati';
  }

  @override
  String get profileHeading => 'Il tuo apprendimento';

  @override
  String get uiLanguageLabel => 'Lingua dell’app';

  @override
  String get learningLanguageRow => 'Lingua che impari';

  @override
  String get supportSheetTitle => 'Quale lingua preferisci per le spiegazioni?';

  @override
  String get learnSheetTitle => 'Quale lingua vuoi imparare?';

  @override
  String get uiSheetTitle => 'In quale lingua vuoi vedere l’app?';

  @override
  String get rowAreas => 'Aree';

  @override
  String get profileLocalNote =>
      'Le tue preferenze restano su questo dispositivo.';

  @override
  String get reviewPreparing => 'Preparo il ripasso';

  @override
  String get reviewError =>
      'Non sono riuscito a preparare il ripasso. Riprova.';

  @override
  String exerciseProgress(int position, int total) {
    return '$position di $total';
  }

  @override
  String exerciseSemantics(int position, int total) {
    return 'Esercizio $position di $total';
  }

  @override
  String get instructionCorrect => 'Correggi la frase';

  @override
  String get instructionChoose => 'Scegli la risposta corretta';

  @override
  String get instructionComplete => 'Completa la frase';

  @override
  String get yourAnswer => 'La tua risposta';

  @override
  String get check => 'Controlla';

  @override
  String get correctAnswerTag => 'Risposta corretta';

  @override
  String get feedbackCorrect => 'Esatto!';

  @override
  String get feedbackIncorrect => 'Quasi.';

  @override
  String yourAnswerWas(String answer) {
    return 'La tua risposta: $answer';
  }

  @override
  String get correctAnswerIs => 'La risposta corretta è:';

  @override
  String get backToPath => 'Torna al percorso';

  @override
  String get reviewEmptyTitle => 'Nessun ripasso disponibile';

  @override
  String get reviewEmptyBody =>
      'Per ora non ci sono esercizi pronti. Continua a parlare e torneremo qui quando ci sarà qualcosa da ripassare.';

  @override
  String get reviewDoneTitle => 'Ripasso completato';

  @override
  String exercisesDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count esercizi completati',
      one: '1 esercizio completato',
    );
    return '$_temp0';
  }

  @override
  String correctCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count corrette',
      one: '1 corretta',
    );
    return '$_temp0';
  }

  @override
  String toRetry(int count) {
    return '$count da riprovare';
  }

  @override
  String get topicEtreVsAvoir => 'Être e avoir';

  @override
  String get topicPasseCompose => 'Passé composé';

  @override
  String get topicSerVsEstar => 'Ser e estar';

  @override
  String get topicHabenVsSein => 'Haben e sein';

  @override
  String get topicPerfekt => 'Perfekt';

  @override
  String get topicCases => 'I casi (Kasus)';

  @override
  String get topicPorVsPara => 'Por e para';

  @override
  String get topicMeasureWords => 'Classificatori (量词)';

  @override
  String get topicStructuralParticles => 'Particelle 的 / 得 / 地';

  @override
  String get topicAspectParticles => 'Particelle di aspetto (了, 过, 着)';

  @override
  String get topicNegation => 'Negazione (不 / 没)';

  @override
  String get listen => 'Ascolta';

  @override
  String get listenSlowly => 'Piano';

  @override
  String get spellIt => 'Compita';

  @override
  String get stopListening => 'Ferma';

  @override
  String get hearItRight => 'Ascolta come si dice e si scrive correttamente:';

  @override
  String get translationLabel => 'Traduzione';

  @override
  String get teacherVoiceLabel => 'Voce dell\'insegnante';

  @override
  String get teacherVoiceHint =>
      'Usata quando i messaggi dell\'insegnante vengono letti ad alta voce. La voce esatta dipende da quelle installate sul telefono.';

  @override
  String get voiceFemale => 'Femminile';

  @override
  String get voiceMale => 'Maschile';

  @override
  String get listenToMessage => 'Ascolta il messaggio';

  @override
  String get noVoiceInstalled =>
      'Il telefono non ha una voce installata per questa lingua. Puoi installarla da Impostazioni, Lingua, Sintesi vocale.';

  @override
  String get speechFailed => 'Non sono riuscito a riprodurre l’audio.';

  @override
  String get speakRepliesLabel => 'Leggi le risposte ad alta voce';

  @override
  String get speakRepliesHint =>
      'Le risposte ai tuoi messaggi vocali vengono sempre lette.';

  @override
  String get recordVoice => 'Registra un messaggio vocale';

  @override
  String get recordingNow => 'Registrazione in corso';

  @override
  String get recordingCancel => 'Annulla la registrazione';

  @override
  String get recordingSend => 'Invia il messaggio vocale';

  @override
  String get micDenied =>
      'Mi serve il permesso di usare il microfono. Puoi attivarlo nelle impostazioni del telefono.';

  @override
  String get micFailed => 'Non sono riuscito a iniziare a registrare.';

  @override
  String get recordingTooShort =>
      'La registrazione è troppo breve. Parla un po’ più a lungo.';

  @override
  String get voiceMessage => 'Messaggio vocale';

  @override
  String get voiceListening => 'Sto ascoltando…';

  @override
  String get voiceNotUnderstood => 'L’audio non è stato compreso';

  @override
  String get routineTitle => 'La tua pratica di oggi';

  @override
  String get routineIntro =>
      'Queste sono le cose che ti conviene praticare oggi.';

  @override
  String get routinePreparing => 'Preparo la tua pratica';

  @override
  String get routineError =>
      'Non sono riuscito a preparare la tua pratica di oggi. Riprova.';

  @override
  String get routineStep3Title => 'Consolida';

  @override
  String routineReviewDesc(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count esercizi da ripassare',
      one: '1 esercizio da ripassare',
    );
    return '$_temp0';
  }

  @override
  String get routineReviewNone => 'Oggi non c’è niente da ripassare.';

  @override
  String routineWordsDesc(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parole da consolidare',
      one: '1 parola da consolidare',
    );
    return '$_temp0';
  }

  @override
  String get routineWordsNone => 'Oggi non ci sono parole da consolidare.';

  @override
  String get routineStepDone => 'Fatto';

  @override
  String get routineStepLocked => 'Prima completa il passo precedente.';

  @override
  String get routineCtaStart => 'Inizia';

  @override
  String get routineContinue => 'Continua la pratica';

  @override
  String get routineCompleted => 'Completata! 🎉';

  @override
  String get routineCompletedBody =>
      'Hai fatto la tua pratica di oggi. Torna domani.';

  @override
  String routineProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String routineProgressSemantics(int done, int total) {
    return '$done di $total passi fatti';
  }

  @override
  String get situationIntroductionTitle => 'Presentati';

  @override
  String get situationIntroductionDesc =>
      'Conosci qualcuno a una festa: parla di dove vivi, di cosa fai e dei tuoi interessi.';

  @override
  String get situationYesterdayTitle => 'Cosa hai fatto ieri?';

  @override
  String get situationYesterdayDesc =>
      'Un amico ti chiede com’è andata ieri: racconta dove sei stato e cosa hai fatto.';

  @override
  String get situationWorkdayTitle => 'La tua giornata';

  @override
  String get situationWorkdayDesc =>
      'Un collega ti chiede della tua giornata di lavoro o di studio.';

  @override
  String get situationCafeTitle => 'Al bar';

  @override
  String get situationCafeDesc =>
      'Ordina qualcosa da mangiare e da bere e fai una domanda sul locale.';

  @override
  String get situationDirectionsTitle => 'Come arrivo?';

  @override
  String get situationDirectionsDesc =>
      'Sei in una città che non conosci: chiedi la strada per un posto.';

  @override
  String get situationShoppingTitle => 'In negozio';

  @override
  String get situationShoppingDesc =>
      'Cerca qualcosa da comprare: chiedi taglia, colore e prezzo.';

  @override
  String get situationDescribingTitle => 'Descrivi';

  @override
  String get situationDescribingDesc =>
      'Descrivi una persona o un luogo che conosci bene e cosa pensi di loro.';

  @override
  String get situationPlansTitle => 'Facciamo un piano';

  @override
  String get situationPlansDesc =>
      'Organizza con qualcuno il fine settimana o un viaggio.';

  @override
  String missionBanner(String title) {
    return 'Missione: $title';
  }

  @override
  String get missionFinish => 'Termina la missione';

  @override
  String get missionKeepGoing => 'Scrivi ancora un po’ per poter terminare.';

  @override
  String get wordsStepIntro => 'Ripassa queste parole che hai incontrato.';

  @override
  String get wordsStepContext => 'Completa:';

  @override
  String get wordsStepReveal => 'Mostra la parola';

  @override
  String get wordsStepFinish => 'Ho finito';

  @override
  String guidanceReasonReviews(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hai $count esercizi da ripassare.',
      one: 'Hai 1 esercizio da ripassare.',
    );
    return '$_temp0';
  }

  @override
  String guidanceReasonTopic(String topic) {
    return 'Oggi lavoriamo ancora su $topic.';
  }

  @override
  String guidanceReasonGoal(String goal) {
    return 'Continuiamo a lavorare sul tuo obiettivo: $goal.';
  }

  @override
  String guidanceReasonWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hai $count parole da consolidare.',
      one: 'Hai 1 parola da consolidare.',
    );
    return '$_temp0';
  }

  @override
  String get guidanceStart => 'Inizia la tua pratica';

  @override
  String get guidanceContinue => 'Continua la tua pratica';

  @override
  String get guidanceCompleted => 'Pratica completata';

  @override
  String guidanceStepDone(String step) {
    return '$step: fatto';
  }

  @override
  String guidanceStepPending(String step) {
    return '$step: da fare';
  }

  @override
  String guidanceStepNone(String step) {
    return '$step: niente per oggi';
  }

  @override
  String homeStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String streakLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return 'Serie di $_temp0';
  }

  @override
  String get routineStartPractice => 'Inizia la pratica';

  @override
  String get routineHeroReview => 'Ripassa quello che hai visto';

  @override
  String get routineHeroTalk => 'Parla con il tuo insegnante';

  @override
  String get routineHeroWords => 'Consolida le tue parole';

  @override
  String get homeTileConversationSub => 'Parla liberamente';

  @override
  String homeTileLearnSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aree da rinforzare',
      one: '1 area da rinforzare',
    );
    return '$_temp0';
  }

  @override
  String get homeTileLearnNone => 'Cosa rinforzare';

  @override
  String homeTileReviewSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in sospeso',
      one: '1 in sospeso',
    );
    return '$_temp0';
  }

  @override
  String get homeTileReviewNone => 'Tutto in ordine';

  @override
  String homeTileWordsSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count da consolidare',
      one: '1 da consolidare',
    );
    return '$_temp0';
  }

  @override
  String get homeTileWordsNone => 'Il tuo vocabolario';

  @override
  String get priorityHigh => 'Alta';

  @override
  String get priorityMedium => 'Media';

  @override
  String get priorityLow => 'Bassa';

  @override
  String priorityLabel(String level) {
    return 'Priorità: $level';
  }

  @override
  String get learnSubtitle => 'Su cosa lavorare ora';

  @override
  String get wordsTabToConsolidate => 'Da consolidare';

  @override
  String get wordsTabInUse => 'In uso';

  @override
  String get wordsTabAll => 'Tutte';

  @override
  String get wordsNoMeaning => 'Ancora nessun significato salvato';

  @override
  String wordUsesSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usata correttamente $count volte',
      one: 'Usata correttamente una volta',
      zero: 'Ancora nessun uso corretto',
    );
    return '$_temp0';
  }
}
