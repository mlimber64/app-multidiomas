// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get save => 'Guardar';

  @override
  String get back => 'Atrás';

  @override
  String get notSet => 'Sin definir';

  @override
  String get couldNotSave => 'No he podido guardar. Inténtalo de nuevo.';

  @override
  String get letsTalk => 'Hablemos';

  @override
  String get continueAction => 'Continuar';

  @override
  String get navHome => 'Inicio';

  @override
  String get navTalk => 'Hablar';

  @override
  String get navLearn => 'Aprender';

  @override
  String get navWords => 'Palabras';

  @override
  String get navPath => 'Progreso';

  @override
  String get navProfile => 'Perfil';

  @override
  String get homeGreeting => '¡Hola!';

  @override
  String get homeReady => '¿Listo para practicar hoy?';

  @override
  String get heroSubtitle => 'Practica con tu profesor de IA.';

  @override
  String get quickConversation => 'Conversación';

  @override
  String get quickReview => 'Repasar';

  @override
  String get journeyTitle => 'Tu recorrido';

  @override
  String get rowLanguage => 'Idioma';

  @override
  String get rowLevel => 'Nivel';

  @override
  String get rowGoals => 'Objetivos';

  @override
  String get rowFocus => 'Enfoque';

  @override
  String get noteStartTitle => 'Tu recorrido empieza aquí.';

  @override
  String get noteStartBody =>
      'Haz tu primera conversación para empezar a construir tu recorrido.';

  @override
  String get noteFocusTitle => 'Tu enfoque';

  @override
  String get noteImprovingTitle => 'Estás mejorando';

  @override
  String get noteKeepPracticing => 'Sigue practicando en las conversaciones.';

  @override
  String noteImprovingIn(String topics) {
    return 'Estás mejorando en: $topics';
  }

  @override
  String get levelA1 => 'A1 — Principiante';

  @override
  String get levelA2 => 'A2 — Elemental';

  @override
  String get levelB1 => 'B1 — Intermedio';

  @override
  String get levelB2 => 'B2 — Intermedio alto';

  @override
  String get levelNotSure => 'No estoy seguro';

  @override
  String get goalSpeakConfidently => 'Hablar con más seguridad';

  @override
  String get goalUnderstandListening => 'Entender mejor al escuchar';

  @override
  String get goalWriteBetter => 'Escribir mejor';

  @override
  String get goalLiveAbroad => 'Vivir mejor en el extranjero';

  @override
  String get goalWork => 'Trabajo';

  @override
  String get goalStudy => 'Estudios';

  @override
  String get goalEverything => 'Un poco de todo';

  @override
  String get focusConversation => 'Conversación';

  @override
  String get focusGrammar => 'Gramática';

  @override
  String get focusVocabulary => 'Vocabulario';

  @override
  String get focusPronunciation => 'Pronunciación';

  @override
  String get focusComprehension => 'Comprensión';

  @override
  String get topicPassatoProssimo => 'Passato prossimo';

  @override
  String get topicEssereVsAvere => 'Essere vs avere';

  @override
  String get topicPrepositions => 'Preposiciones';

  @override
  String get topicArticles => 'Artículos';

  @override
  String get topicGender => 'Género de los sustantivos';

  @override
  String get topicPlural => 'Plurales';

  @override
  String get topicAgreement => 'Concordancia';

  @override
  String get topicPronouns => 'Pronombres';

  @override
  String get topicVerbConjugation => 'Conjugación verbal';

  @override
  String get topicWordOrder => 'Orden de las palabras';

  @override
  String get topicToBe => 'El verbo \"to be\"';

  @override
  String get topicPresentContinuous => 'Present continuous';

  @override
  String get topicPastSimple => 'Past simple';

  @override
  String get topicPresentPerfect => 'Present perfect';

  @override
  String get topicThirdPersonSingular => 'Tercera persona del singular';

  @override
  String get chatTitle => 'Hablar';

  @override
  String get newConversation => 'Nueva conversación';

  @override
  String get suggestionDay => 'Mi día';

  @override
  String get suggestionWork => 'Hablemos del trabajo';

  @override
  String get suggestionRestaurant =>
      'Hagamos una conversación en un restaurante';

  @override
  String get suggestionPractice => 'Quiero practicar un poco';

  @override
  String get chatWelcomeTitle => '¡Hola! Soy tu profesor de idiomas.';

  @override
  String get chatWelcomeSubtitle => '¿De qué quieres hablar hoy?';

  @override
  String get chatErrorGeneric =>
      'No puedo responder en este momento. ¿Lo intentamos otra vez?';

  @override
  String get correctMe => 'Corrígeme';

  @override
  String get correctMeHint => 'El profesor corregirá con más atención';

  @override
  String get composerHint => 'Escribe en el idioma que aprendes…';

  @override
  String get send => 'Enviar';

  @override
  String get roleYou => 'Tú';

  @override
  String get roleTeacher => 'Profesor';

  @override
  String get youWrote => 'Escribiste: ';

  @override
  String get better => 'Mejor: ';

  @override
  String moreNatural(String alternative) {
    return 'Más natural: $alternative';
  }

  @override
  String get categoryGrammar => 'Gramática';

  @override
  String get categoryVocabulary => 'Vocabulario';

  @override
  String get categoryPronunciation => 'Pronunciación';

  @override
  String get categoryNaturalExpression => 'Expresión natural';

  @override
  String get categorySpelling => 'Ortografía';

  @override
  String get categoryOther => 'Corrección';

  @override
  String get teacherTyping => 'El profesor está escribiendo';

  @override
  String get aiNotConfigured =>
      'El profesor aún no está configurado. Añade la clave de API de Gemini (consulta el README).';

  @override
  String get aiNetwork =>
      'No consigo conectarme. Comprueba la conexión y lo intentamos de nuevo.';

  @override
  String get aiRateLimited =>
      'Demasiadas solicitudes en poco tiempo. Espera un momento y lo intentamos de nuevo.';

  @override
  String get learnImprove => 'Qué puedes mejorar';

  @override
  String get learnPriorities => 'Tus prioridades';

  @override
  String get learnHowTitle => 'Cómo trabajarlo';

  @override
  String get learnHowBody =>
      'Estas áreas se entrenan hablando: sigue usándolas en las conversaciones y te ayudaré de forma natural.';

  @override
  String get learnDoingWellTitle => 'Vas muy bien';

  @override
  String get learnDoingWellBody =>
      'Por ahora no hay áreas urgentes que reforzar. Sigue hablando conmigo.';

  @override
  String get learnEmptyTitle => 'Aquí verás qué mejorar';

  @override
  String get learnEmptyBody =>
      'Cuando hables conmigo, aquí encontrarás las áreas en las que vale la pena concentrarse.';

  @override
  String get topicProgressMade => 'Ya has avanzado. Sigamos trabajándolo.';

  @override
  String get topicWorthFocus => 'Vale la pena concentrarse aquí.';

  @override
  String relatedTo(String topics) {
    return 'Relacionado con: $topics';
  }

  @override
  String get topicImprovingDetail => 'Estás mejorando: lo usas cada vez mejor.';

  @override
  String get topicProgressWorth =>
      'Ya has avanzado, pero todavía vale la pena trabajarlo.';

  @override
  String get workingOn => 'Estás trabajando en';

  @override
  String get recurringErrors => 'Errores recurrentes';

  @override
  String get mistakes => 'Errores';

  @override
  String get keepUsingIt => 'Sigue usándolo en las conversaciones.';

  @override
  String get topicToConsolidate => 'Todavía por consolidar';

  @override
  String get topicImprovingStatus => 'Lo usas cada vez mejor';

  @override
  String correctOutOf(int correct, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      correct,
      locale: localeName,
      other: '$correct veces',
      one: '1 vez',
    );
    return 'Correcto $_temp0 de $total';
  }

  @override
  String errorPairSemantics(String incorrect, String correct) {
    return 'Escribiste $incorrect, mejor $correct';
  }

  @override
  String get vocabInUse => 'La estás usando';

  @override
  String get vocabUsedCorrectly => 'Ya la has usado correctamente';

  @override
  String get vocabToConsolidate => 'Por consolidar';

  @override
  String get overviewError =>
      'No puedo mostrar tu recorrido en este momento. ¿Lo intentamos otra vez?';

  @override
  String get progressIntro =>
      'Aquí ves cómo evoluciona tu aprendizaje, según cómo hablas.';

  @override
  String get progressEmptyTitle => 'Estamos empezando a conocerte.';

  @override
  String get progressEmptyBody =>
      'Habla conmigo y aquí verás cómo evoluciona tu recorrido.';

  @override
  String get progressToReinforce => 'Por reforzar';

  @override
  String get progressRecurringSub => 'Los has escrito más de una vez.';

  @override
  String get seeAllWords => 'Ver todas las palabras';

  @override
  String get wordsHeadline => 'Tus palabras';

  @override
  String get wordsIntro => 'Las palabras que encuentras hablando conmigo.';

  @override
  String get wordsEmptyTitle => 'Tus palabras aparecerán aquí';

  @override
  String get wordsEmptyBody =>
      'Cuando encuentres palabras nuevas hablando conmigo, las verás en esta página.';

  @override
  String get wordsToConsolidateTitle => 'Palabras por consolidar';

  @override
  String get wordsToConsolidateSub => 'Las has encontrado: sigue usándolas.';

  @override
  String get wordsInUseTitle => 'Palabras que estás usando';

  @override
  String get wordsInUseSub => 'Ya las has usado correctamente varias veces.';

  @override
  String get welcomeTagline => 'Tu profesor de idiomas personal.';

  @override
  String get welcomeBody =>
      'Practica un idioma de forma personal: te haremos unas preguntas para conocerte y así podrás empezar a aprender a partir de ti.';

  @override
  String get onbStart => 'Empezar';

  @override
  String get onbFinish => 'Comenzar';

  @override
  String onbStepSemantics(int step, int total) {
    return 'Paso $step de $total';
  }

  @override
  String get onbLanguagesTitle => 'Tus idiomas';

  @override
  String get supportLanguageLabel => 'Idioma de apoyo';

  @override
  String get learnLanguageQuestion => 'Idioma que quieres aprender';

  @override
  String get levelQuestion => '¿Cuánto sabes ya de este idioma?';

  @override
  String get goalsQuestion => '¿Por qué quieres aprender este idioma?';

  @override
  String get focusQuestion => '¿En qué quieres concentrarte?';

  @override
  String selectionHint(int min, int max, int count) {
    return 'Elige de $min a $max · $count seleccionados';
  }

  @override
  String get profileHeading => 'Tu aprendizaje';

  @override
  String get uiLanguageLabel => 'Idioma de la app';

  @override
  String get learningLanguageRow => 'Idioma que aprendes';

  @override
  String get supportSheetTitle =>
      '¿Qué idioma prefieres para las explicaciones?';

  @override
  String get learnSheetTitle => '¿Qué idioma quieres aprender?';

  @override
  String get uiSheetTitle => '¿En qué idioma quieres ver la app?';

  @override
  String get rowAreas => 'Áreas';

  @override
  String get profileLocalNote =>
      'Tus preferencias se quedan en este dispositivo.';

  @override
  String get reviewPreparing => 'Preparando el repaso';

  @override
  String get reviewError =>
      'No he podido preparar el repaso. Inténtalo de nuevo.';

  @override
  String exerciseProgress(int position, int total) {
    return '$position de $total';
  }

  @override
  String exerciseSemantics(int position, int total) {
    return 'Ejercicio $position de $total';
  }

  @override
  String get instructionCorrect => 'Corrige la frase';

  @override
  String get instructionChoose => 'Elige la respuesta correcta';

  @override
  String get instructionComplete => 'Completa la frase';

  @override
  String get yourAnswer => 'Tu respuesta';

  @override
  String get check => 'Comprobar';

  @override
  String get correctAnswerTag => 'Respuesta correcta';

  @override
  String get feedbackCorrect => '¡Exacto!';

  @override
  String get feedbackIncorrect => 'Casi.';

  @override
  String yourAnswerWas(String answer) {
    return 'Tu respuesta: $answer';
  }

  @override
  String get correctAnswerIs => 'La respuesta correcta es:';

  @override
  String get backToPath => 'Volver al recorrido';

  @override
  String get reviewEmptyTitle => 'No hay repasos disponibles';

  @override
  String get reviewEmptyBody =>
      'Por ahora no hay ejercicios listos. Sigue hablando y volveremos aquí cuando haya algo que repasar.';

  @override
  String get reviewDoneTitle => 'Repaso completado';

  @override
  String exercisesDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ejercicios completados',
      one: '1 ejercicio completado',
    );
    return '$_temp0';
  }

  @override
  String correctCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count correctos',
      one: '1 correcto',
    );
    return '$_temp0';
  }

  @override
  String toRetry(int count) {
    return '$count para repetir';
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
  String get topicCases => 'Los casos (Kasus)';

  @override
  String get topicPorVsPara => 'Por vs para';

  @override
  String get topicMeasureWords => 'Clasificadores (量词)';

  @override
  String get topicStructuralParticles => 'Partículas 的 / 得 / 地';

  @override
  String get topicAspectParticles => 'Partículas de aspecto (了, 过, 着)';

  @override
  String get topicNegation => 'Negación (不 / 没)';

  @override
  String get listen => 'Escuchar';

  @override
  String get listenSlowly => 'Despacio';

  @override
  String get spellIt => 'Deletrear';

  @override
  String get stopListening => 'Detener';

  @override
  String get hearItRight => 'Escucha cómo se dice y se escribe bien:';

  @override
  String get translationLabel => 'Traducción';

  @override
  String get teacherVoiceLabel => 'Voz del profesor';

  @override
  String get teacherVoiceHint =>
      'Se usa al leer en voz alta los mensajes del profesor. La voz exacta depende de las que tengas instaladas en el teléfono.';

  @override
  String get voiceFemale => 'Femenina';

  @override
  String get voiceMale => 'Masculina';

  @override
  String get listenToMessage => 'Escuchar el mensaje';

  @override
  String get noVoiceInstalled =>
      'Tu teléfono no tiene una voz instalada para este idioma. Puedes instalarla en Ajustes, Idioma, Salida de texto a voz.';

  @override
  String get speechFailed => 'No he podido reproducir el audio.';

  @override
  String get speakRepliesLabel => 'Leer las respuestas en voz alta';

  @override
  String get speakRepliesHint =>
      'Las respuestas a tus mensajes de voz siempre se leen.';

  @override
  String get recordVoice => 'Grabar un mensaje de voz';

  @override
  String get recordingNow => 'Grabando';

  @override
  String get recordingCancel => 'Cancelar la grabación';

  @override
  String get recordingSend => 'Enviar el mensaje de voz';

  @override
  String get micDenied =>
      'Necesito permiso para usar el micrófono. Puedes activarlo en los ajustes del teléfono.';

  @override
  String get micFailed => 'No he podido empezar a grabar.';

  @override
  String get recordingTooShort =>
      'La grabación fue demasiado corta. Mantén el mensaje un poco más.';

  @override
  String get voiceMessage => 'Mensaje de voz';

  @override
  String get voiceListening => 'Escuchando…';

  @override
  String get voiceNotUnderstood => 'No se entendió el audio';

  @override
  String get routineTitle => 'Tu práctica de hoy';

  @override
  String get routineIntro => 'Esto es lo que te conviene practicar hoy.';

  @override
  String get routinePreparing => 'Preparando tu práctica';

  @override
  String get routineError =>
      'No he podido preparar tu práctica de hoy. Inténtalo de nuevo.';

  @override
  String get routineStep3Title => 'Consolida';

  @override
  String routineReviewDesc(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ejercicios para repasar',
      one: '1 ejercicio para repasar',
    );
    return '$_temp0';
  }

  @override
  String get routineReviewNone => 'Hoy no hay nada que repasar.';

  @override
  String routineWordsDesc(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palabras para consolidar',
      one: '1 palabra para consolidar',
    );
    return '$_temp0';
  }

  @override
  String get routineWordsNone => 'Hoy no hay palabras para consolidar.';

  @override
  String get routineStepDone => 'Hecho';

  @override
  String get routineStepLocked => 'Primero termina el paso anterior.';

  @override
  String get routineCtaStart => 'Empezar';

  @override
  String get routineContinue => 'Seguir con la práctica';

  @override
  String get routineCompleted => '¡Completada! 🎉';

  @override
  String get routineCompletedBody =>
      'Has hecho tu práctica de hoy. Vuelve mañana.';

  @override
  String routineProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String routineProgressSemantics(int done, int total) {
    return '$done de $total pasos hechos';
  }

  @override
  String get situationIntroductionTitle => 'Preséntate';

  @override
  String get situationIntroductionDesc =>
      'Conoces a alguien en una fiesta: habla de dónde vives, a qué te dedicas y qué te gusta.';

  @override
  String get situationYesterdayTitle => '¿Qué hiciste ayer?';

  @override
  String get situationYesterdayDesc =>
      'Un amigo te pregunta cómo te fue ayer: cuéntale adónde fuiste y qué hiciste.';

  @override
  String get situationWorkdayTitle => 'Tu jornada';

  @override
  String get situationWorkdayDesc =>
      'Un compañero te pregunta por tu día de trabajo o de estudio.';

  @override
  String get situationCafeTitle => 'En la cafetería';

  @override
  String get situationCafeDesc =>
      'Pide algo de comer y de beber y haz una pregunta sobre el local.';

  @override
  String get situationDirectionsTitle => '¿Cómo llego?';

  @override
  String get situationDirectionsDesc =>
      'Estás en una ciudad que no conoces: pregunta cómo llegar a un sitio.';

  @override
  String get situationShoppingTitle => 'De compras';

  @override
  String get situationShoppingDesc =>
      'Busca algo que comprar: pregunta por la talla, el color y el precio.';

  @override
  String get situationDescribingTitle => 'Describe';

  @override
  String get situationDescribingDesc =>
      'Describe a una persona o un lugar que conoces bien y qué piensas de ellos.';

  @override
  String get situationPlansTitle => 'Hagamos un plan';

  @override
  String get situationPlansDesc =>
      'Organiza con alguien el fin de semana o un viaje.';

  @override
  String missionBanner(String title) {
    return 'Misión: $title';
  }

  @override
  String get missionFinish => 'Terminar la misión';

  @override
  String get missionKeepGoing => 'Escribe un poco más para poder terminar.';

  @override
  String get wordsStepIntro => 'Repasa estas palabras que has encontrado.';

  @override
  String get wordsStepContext => 'Completa:';

  @override
  String get wordsStepReveal => 'Mostrar la palabra';

  @override
  String get wordsStepFinish => 'He terminado';

  @override
  String guidanceReasonReviews(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tienes $count ejercicios para repasar.',
      one: 'Tienes 1 ejercicio para repasar.',
    );
    return '$_temp0';
  }

  @override
  String guidanceReasonTopic(String topic) {
    return 'Hoy seguimos trabajando en $topic.';
  }

  @override
  String guidanceReasonGoal(String goal) {
    return 'Seguimos trabajando en tu objetivo: $goal.';
  }

  @override
  String guidanceReasonWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tienes $count palabras para consolidar.',
      one: 'Tienes 1 palabra para consolidar.',
    );
    return '$_temp0';
  }

  @override
  String get guidanceStart => 'Empieza tu práctica';

  @override
  String get guidanceContinue => 'Continúa tu práctica';

  @override
  String get guidanceCompleted => 'Práctica completada';

  @override
  String guidanceStepDone(String step) {
    return '$step: hecho';
  }

  @override
  String guidanceStepPending(String step) {
    return '$step: por hacer';
  }

  @override
  String guidanceStepNone(String step) {
    return '$step: nada por hoy';
  }

  @override
  String homeStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String streakLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return 'Racha de $_temp0';
  }

  @override
  String get routineStartPractice => 'Empezar práctica';

  @override
  String get routineHeroReview => 'Repasa lo que viste';

  @override
  String get routineHeroTalk => 'Habla con tu profesor';

  @override
  String get routineHeroWords => 'Consolida tus palabras';

  @override
  String get homeTileConversationSub => 'Habla libre';

  @override
  String homeTileLearnSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count áreas a reforzar',
      one: '1 área a reforzar',
    );
    return '$_temp0';
  }

  @override
  String get homeTileLearnNone => 'Qué reforzar';

  @override
  String homeTileReviewSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pendientes',
      one: '1 pendiente',
    );
    return '$_temp0';
  }

  @override
  String get homeTileReviewNone => 'Todo al día';

  @override
  String homeTileWordsSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count por consolidar',
      one: '1 por consolidar',
    );
    return '$_temp0';
  }

  @override
  String get homeTileWordsNone => 'Tu vocabulario';

  @override
  String get priorityHigh => 'Alta';

  @override
  String get priorityMedium => 'Media';

  @override
  String get priorityLow => 'Baja';

  @override
  String priorityLabel(String level) {
    return 'Prioridad: $level';
  }

  @override
  String get learnSubtitle => 'Qué reforzar ahora';
}
