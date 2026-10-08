import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/shared/ui/app_bottom_nav.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_overview.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/learning/presentation/widgets/error_pair_tile.dart';
import 'package:parla_con_me/features/learning/presentation/widgets/topic_tile.dart';
import 'package:parla_con_me/features/learning/presentation/widgets/vocabulary_tile.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';
import '../../support/learning_fixtures.dart';
import '../../support/pump_app.dart';

/// Opens the app over a controlled memory. The window is made tall: lists
/// build lazily, so on a phone-sized test window anything below the fold does
/// not exist yet (a real user scrolls), which would hide what is asserted.
Future<void> _open(
  WidgetTester tester,
  FakeMemoryRepository repo, {
  InMemoryLocalStorage? storage,
}) async {
  await pumpApp(
    tester,
    storage ?? InMemoryLocalStorage(),
    profile: onboardedProfile,
    overrides: [learningRepositoryProvider.overrideWithValue(repo)],
  );
  tester.view.physicalSize = const Size(1080, 9000);
  await tester.pumpAndSettle();
}

Future<void> _goTo(WidgetTester tester, String tab) async {
  await tester.tap(
    find.descendant(of: find.byType(AppBottomNav), matching: find.text(tab)),
  );
  await tester.pumpAndSettle();
}

Finder _inTiles<T extends Widget>(String text) =>
    find.descendant(of: find.byType(T), matching: find.text(text));

/// A memory with a bit of everything.
FakeMemoryRepository _fullMemory() => FakeMemoryRepository(
  summaryOf(
    topics: [
      topicOf(GrammarTopic.passatoProssimo, errors: 1, successes: 5),
      topicOf(GrammarTopic.articles, errors: 3),
      topicOf(GrammarTopic.essereVsAvere, errors: 4, successes: 1),
    ],
    errors: [
      errorOf(
        'ho andato',
        'sono andato',
        frequency: 4,
        topic: GrammarTopic.essereVsAvere,
      ),
      errorOf(
        'la problema',
        'il problema',
        frequency: 2,
        topic: GrammarTopic.articles,
      ),
    ],
    vocabulary: [
      wordOf('prenotazione', meaning: 'reserva'),
      wordOf('appuntamento'),
      wordOf('scontrino', exposure: 5, successes: 5),
      wordOf('biglietto'),
    ],
  ),
);

const _technical = [
  'confidence',
  'frequency',
  'exposure',
  'priorityScore',
  'LearningSignal',
  'XP',
  'streak',
  '%',
];

void _expectNoTechnicalLanguage() {
  for (final word in _technical) {
    expect(find.textContaining(word), findsNothing, reason: word);
  }
  expect(
    find.textContaining('imparat'),
    findsNothing,
    reason: 'nothing is claimed as learned',
  );
}

void main() {
  group('Percorso', () {
    testWidgets('empty memory: a friendly start, no zeros, no placeholder', (
      tester,
    ) async {
      await _open(tester, FakeMemoryRepository());
      await _goTo(tester, 'Percorso');

      expect(find.text('Il tuo percorso'), findsOneWidget);
      expect(find.text('Stiamo iniziando a conoscerti.'), findsOneWidget);
      expect(
        find.text('Parla con me e qui vedrai come evolve il tuo percorso.'),
        findsOneWidget,
      );
      expect(find.text('Prossimamente'), findsNothing);
      expect(find.text('Stai migliorando'), findsNothing);
      expect(find.text('Da rinforzare'), findsNothing);
      _expectNoTechnicalLanguage();
      expect(find.text('0'), findsNothing);
    });

    testWidgets(
      'full memory: improving, to reinforce, recurring errors and words',
      (tester) async {
        await _open(tester, _fullMemory());
        await _goTo(tester, 'Percorso');

        expect(find.text('Stai migliorando'), findsOneWidget);
        expect(_inTiles<TopicTile>('Passato prossimo'), findsOneWidget);
        expect(find.text('Da rinforzare'), findsOneWidget);
        expect(_inTiles<TopicTile>('Articoli'), findsOneWidget);
        expect(_inTiles<TopicTile>('Essere e avere'), findsOneWidget);
        expect(find.text('Errori ricorrenti'), findsOneWidget);
        expect(find.byType(ErrorPairTile), findsNWidgets(2));
        expect(
          find.textContaining('sono andato', findRichText: true),
          findsWidgets,
        );
        expect(find.text('Parole'), findsWidgets);
        expect(find.text('Vedi tutte le parole'), findsOneWidget);
        _expectNoTechnicalLanguage();
      },
    );

    testWidgets('improvement is not listed among the weaknesses', (
      tester,
    ) async {
      await _open(tester, _fullMemory());
      await _goTo(tester, 'Percorso');

      final improvingY = tester.getTopLeft(find.text('Stai migliorando')).dy;
      final reinforceY = tester.getTopLeft(find.text('Da rinforzare')).dy;
      final passatoY = tester
          .getTopLeft(_inTiles<TopicTile>('Passato prossimo'))
          .dy;
      final articlesY = tester.getTopLeft(_inTiles<TopicTile>('Articoli')).dy;
      expect(passatoY, greaterThan(improvingY));
      expect(
        passatoY,
        lessThan(reinforceY),
        reason: 'passato prossimo sits under "Stai migliorando"',
      );
      expect(articlesY, greaterThan(reinforceY));
    });

    testWidgets('progress is shown as real evidence in human words', (
      tester,
    ) async {
      await _open(tester, _fullMemory());
      await _goTo(tester, 'Percorso');
      expect(find.text('Corretto 5 volte su 6'), findsOneWidget);
      expect(find.text('Lo usi sempre meglio'), findsOneWidget);
      expect(
        find.text('Ancora da consolidare'),
        findsOneWidget,
        reason: 'articles: no correct use seen yet',
      );
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('only errors: reinforce and recurring, nothing else', (
      tester,
    ) async {
      await _open(
        tester,
        FakeMemoryRepository(
          summaryOf(
            topics: [topicOf(GrammarTopic.articles, errors: 2)],
            errors: [
              errorOf(
                'la problema',
                'il problema',
                topic: GrammarTopic.articles,
              ),
            ],
          ),
        ),
      );
      await _goTo(tester, 'Percorso');
      expect(find.text('Da rinforzare'), findsOneWidget);
      expect(find.text('Errori ricorrenti'), findsOneWidget);
      expect(find.text('Stai migliorando'), findsNothing);
      expect(find.text('Vedi tutte le parole'), findsNothing);
      expect(find.text('Stiamo iniziando a conoscerti.'), findsNothing);
    });

    testWidgets('only vocabulary: words, no empty state', (tester) async {
      await _open(
        tester,
        FakeMemoryRepository(summaryOf(vocabulary: [wordOf('prenotazione')])),
      );
      await _goTo(tester, 'Percorso');
      expect(find.byType(VocabularyTile), findsOneWidget);
      expect(find.text('Vedi tutte le parole'), findsOneWidget);
      expect(find.text('Stiamo iniziando a conoscerti.'), findsNothing);
      expect(find.text('Da rinforzare'), findsNothing);
    });

    testWidgets('only progress: improving, no weaknesses', (tester) async {
      await _open(
        tester,
        FakeMemoryRepository(
          summaryOf(
            topics: [topicOf(GrammarTopic.gender, errors: 1, successes: 4)],
          ),
        ),
      );
      await _goTo(tester, 'Percorso');
      expect(find.text('Stai migliorando'), findsOneWidget);
      expect(find.text('Da rinforzare'), findsNothing);
    });

    testWidgets('lists stay short however big the memory is', (tester) async {
      await _open(
        tester,
        FakeMemoryRepository(
          summaryOf(
            topics: [
              for (final t in GrammarTopic.values) topicOf(t, errors: 3),
            ],
            errors: [
              for (var i = 0; i < 12; i++)
                errorOf('sbaglio$i', 'giusto$i', frequency: 3),
            ],
            vocabulary: [for (var i = 0; i < 20; i++) wordOf('parola$i')],
          ),
        ),
      );
      await _goTo(tester, 'Percorso');
      await tester.scrollUntilVisible(
        find.text('Vedi tutte le parole'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byType(TopicTile, skipOffstage: false),
        findsNWidgets(overviewMaxTopics),
      );
      expect(
        find.byType(ErrorPairTile, skipOffstage: false),
        findsNWidgets(overviewMaxRecurringErrors),
      );
      expect(
        find.byType(VocabularyTile, skipOffstage: false),
        findsNWidgets(3),
      );
    });

    testWidgets(
      'a topic opens a detail with the real mistakes behind it, not an exercise',
      (tester) async {
        await _open(tester, _fullMemory());
        await _goTo(tester, 'Percorso');

        await tester.tap(_inTiles<TopicTile>('Articoli'));
        await tester.pumpAndSettle();

        expect(find.text('Vale la pena concentrarsi qui.'), findsOneWidget);
        expect(find.text('Errori ricorrenti'), findsWidgets);
        expect(
          find.textContaining('il problema', findRichText: true),
          findsWidgets,
        );
        expect(
          find.text('Continua a usarlo nelle conversazioni.'),
          findsOneWidget,
        );
        expect(find.text('Parliamo'), findsOneWidget);
        expect(find.textContaining('esercizio'), findsNothing);
        expect(find.textContaining('Inizia'), findsNothing);
      },
    );

    testWidgets('the detail connects related topics', (tester) async {
      await _open(tester, _fullMemory());
      await _goTo(tester, 'Percorso');
      await tester.tap(_inTiles<TopicTile>('Essere e avere'));
      await tester.pumpAndSettle();
      expect(find.text('Stai lavorando su'), findsOneWidget);
      expect(find.text('• Passato prossimo'), findsOneWidget);
      expect(
        find.text('Hai già fatto progressi, ma vale ancora la pena lavorarci.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'unreadable memory: a friendly error with retry, then it recovers',
      (tester) async {
        final repo = _fullMemory()..failing = true;
        await _open(tester, repo);
        await _goTo(tester, 'Percorso');

        expect(
          find.text(
            'Non riesco a mostrare il tuo percorso in questo momento. Riproviamo?',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('StorageFailure'), findsNothing);
        expect(find.textContaining('disk error'), findsNothing);

        repo.failing = false;
        await tester.tap(find.text('Riprova'));
        await tester.pumpAndSettle();
        expect(find.text('Stai migliorando'), findsOneWidget);
        expect(find.text('Riprova'), findsNothing);
      },
    );

    testWidgets('while the memory loads there is a spinner, then the content', (
      tester,
    ) async {
      final repo = _fullMemory()..gate = Completer<void>();
      await _open(tester, repo);
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text('Percorso'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('Stiamo iniziando a conoscerti.'),
        findsNothing,
        reason: 'no false empty state while loading',
      );

      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Stai migliorando'), findsOneWidget);
    });
  });

  group('Impara', () {
    testWidgets('empty memory: an invitation, not an empty table', (
      tester,
    ) async {
      await _open(tester, FakeMemoryRepository());
      await _goTo(tester, 'Impara');
      expect(find.text('Qui vedrai cosa migliorare'), findsOneWidget);
      expect(find.text('Prossimamente'), findsNothing);
      _expectNoTechnicalLanguage();
    });

    testWidgets('priorities are ranked and the top one is the focus', (
      tester,
    ) async {
      await _open(
        tester,
        FakeMemoryRepository(
          summaryOf(
            topics: [
              topicOf(GrammarTopic.articles, errors: 2),
              topicOf(GrammarTopic.essereVsAvere, errors: 5, successes: 1),
              topicOf(GrammarTopic.prepositions, errors: 4),
            ],
          ),
        ),
      );
      await _goTo(tester, 'Impara');

      expect(find.text('Cosa puoi migliorare'), findsOneWidget);
      expect(find.text('Le tue priorità'), findsOneWidget);
      final order = [
        tester.getTopLeft(_inTiles<TopicTile>('Essere e avere')).dy,
        tester.getTopLeft(_inTiles<TopicTile>('Preposizioni')).dy,
        tester.getTopLeft(_inTiles<TopicTile>('Articoli')).dy,
      ];
      expect(
        order,
        orderedEquals([...order]..sort()),
        reason: 'ranked by the memory priority',
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // The hero is the top priority; it already shows some progress.
      expect(
        find.text('Hai già fatto progressi. Continuiamo a lavorarci.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'without any correct use yet the focus is neutral, not congratulating',
      (tester) async {
        await _open(
          tester,
          FakeMemoryRepository(
            summaryOf(topics: [topicOf(GrammarTopic.articles, errors: 3)]),
          ),
        );
        await _goTo(tester, 'Impara');
        expect(find.text('Vale la pena concentrarsi qui.'), findsOneWidget);
        expect(find.textContaining('progressi'), findsNothing);
      },
    );

    testWidgets('explains how to work on it: by talking. No exercises exist', (
      tester,
    ) async {
      await _open(
        tester,
        FakeMemoryRepository(
          summaryOf(topics: [topicOf(GrammarTopic.articles, errors: 3)]),
        ),
      );
      await _goTo(tester, 'Impara');
      expect(find.text('Come lavorarci'), findsOneWidget);
      expect(find.textContaining('nelle conversazioni'), findsOneWidget);
      expect(find.textContaining('esercizio'), findsNothing);
      expect(find.textContaining('Quiz'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Parliamo'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Parla')),
        findsOneWidget,
      );
    });

    testWidgets('a priority opens the detail', (tester) async {
      await _open(
        tester,
        FakeMemoryRepository(
          summaryOf(topics: [topicOf(GrammarTopic.articles, errors: 3)]),
        ),
      );
      await _goTo(tester, 'Impara');
      await tester.tap(_inTiles<TopicTile>('Articoli'));
      await tester.pumpAndSettle();
      expect(
        find.text('Continua a usarlo nelle conversazioni.'),
        findsOneWidget,
      );
    });

    testWidgets('only improvement: good news, no priorities', (tester) async {
      await _open(
        tester,
        FakeMemoryRepository(
          summaryOf(
            topics: [topicOf(GrammarTopic.articles, errors: 1, successes: 4)],
          ),
        ),
      );
      await _goTo(tester, 'Impara');
      expect(find.text('Stai andando bene'), findsOneWidget);
      expect(find.text('Le tue priorità'), findsNothing);
      expect(_inTiles<TopicTile>('Articoli'), findsOneWidget);
    });

    testWidgets('unreadable memory: friendly error', (tester) async {
      await _open(tester, FakeMemoryRepository()..failing = true);
      await _goTo(tester, 'Impara');
      expect(find.text('Riprova'), findsOneWidget);
    });
  });

  group('Parole', () {
    testWidgets('empty memory: words will appear here', (tester) async {
      await _open(tester, FakeMemoryRepository());
      await _goTo(tester, 'Parole');
      expect(find.text('Le tue parole appariranno qui'), findsOneWidget);
      expect(find.text('Prossimamente'), findsNothing);
      expect(find.byType(VocabularyTile), findsNothing);
    });

    testWidgets('words appear in the section the memory can justify', (
      tester,
    ) async {
      await _open(tester, _fullMemory());
      await _goTo(tester, 'Parole');

      expect(find.text('Le tue parole'), findsOneWidget);
      expect(find.text('Parole da consolidare'), findsOneWidget);
      expect(find.text('Parole che stai usando'), findsOneWidget);
      expect(find.text('prenotazione'), findsOneWidget);
      expect(
        find.text('reserva'),
        findsOneWidget,
        reason: 'the meaning shows when it exists',
      );
      expect(find.text('scontrino'), findsOneWidget);
      expect(find.text('La stai usando'), findsOneWidget);
      expect(find.text('Da consolidare'), findsNWidgets(3));
      expect(find.byType(VocabularyTile), findsNWidgets(4));
      _expectNoTechnicalLanguage();
    });

    testWidgets(
      'a word with some correct use says so, without calling it learned',
      (tester) async {
        await _open(
          tester,
          FakeMemoryRepository(
            summaryOf(
              vocabulary: [wordOf('appuntamento', exposure: 3, successes: 1)],
            ),
          ),
        );
        await _goTo(tester, 'Parole');
        expect(find.text("L'hai già usata correttamente"), findsOneWidget);
        expect(find.text('Parole da consolidare'), findsOneWidget);
        expect(find.text('Parole che stai usando'), findsNothing);
      },
    );

    testWidgets('only words in use: only that section', (tester) async {
      await _open(
        tester,
        FakeMemoryRepository(
          summaryOf(
            vocabulary: [wordOf('scontrino', exposure: 5, successes: 5)],
          ),
        ),
      );
      await _goTo(tester, 'Parole');
      expect(find.text('Parole che stai usando'), findsOneWidget);
      expect(find.text('Parole da consolidare'), findsNothing);
    });

    testWidgets('unreadable memory: friendly error', (tester) async {
      await _open(tester, FakeMemoryRepository()..failing = true);
      await _goTo(tester, 'Parole');
      expect(find.text('Riprova'), findsOneWidget);
    });
  });

  group('Home', () {
    testWidgets('empty memory keeps the invitation to the first conversation', (
      tester,
    ) async {
      await _open(tester, FakeMemoryRepository());
      expect(find.text('Il tuo percorso inizia qui.'), findsOneWidget);
      expect(find.text('Il tuo focus'), findsNothing);
      expect(find.text('Parliamo'), findsOneWidget);
    });

    testWidgets('with learning it shows the real focus and what is improving', (
      tester,
    ) async {
      await _open(tester, _fullMemory());
      expect(find.text('Il tuo percorso inizia qui.'), findsNothing);
      expect(find.text('Il tuo focus'), findsOneWidget);
      expect(find.text('Essere e avere'), findsOneWidget);
      expect(
        find.text('Continua a praticare nelle conversazioni.'),
        findsOneWidget,
      );
      expect(
        find.text('Stai migliorando in: Passato prossimo'),
        findsOneWidget,
      );
      expect(
        find.text('Parliamo'),
        findsOneWidget,
        reason: 'the conversation stays the main call to action',
      );
      _expectNoTechnicalLanguage();

      // Declared profile and learned memory are separate things on screen.
      expect(find.text('A2 · Elementare'), findsOneWidget);
    });

    testWidgets('only improvement: just the good news', (tester) async {
      await _open(
        tester,
        FakeMemoryRepository(
          summaryOf(
            topics: [topicOf(GrammarTopic.gender, errors: 1, successes: 4)],
          ),
        ),
      );
      expect(find.text('Stai migliorando'), findsOneWidget);
      expect(find.text('Genere dei nomi'), findsOneWidget);
      expect(find.text('Il tuo focus'), findsNothing);
    });

    testWidgets('only words: nothing invented', (tester) async {
      await _open(
        tester,
        FakeMemoryRepository(summaryOf(vocabulary: [wordOf('prenotazione')])),
      );
      expect(find.text('Il tuo percorso inizia qui.'), findsNothing);
      expect(find.text('Il tuo focus'), findsNothing);
      expect(find.text('Parliamo'), findsOneWidget);
    });

    testWidgets('an unreadable memory never disturbs Home', (tester) async {
      await _open(tester, FakeMemoryRepository()..failing = true);
      expect(find.text('Parliamo'), findsOneWidget);
      expect(find.text('Il tuo percorso inizia qui.'), findsNothing);
      // Only the routine card reports it, on its own, with its own retry.
      expect(
        find.text(
          'Non sono riuscito a preparare la tua pratica di oggi. Riprova.',
        ),
        findsOneWidget,
      );
      expect(find.text('Riprova'), findsOneWidget);
    });

    testWidgets('the focus opens Percorso', (tester) async {
      await _open(tester, _fullMemory());
      await tester.tap(find.text('Il tuo focus'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Percorso'),
        ),
        findsOneWidget,
      );
      expect(find.text('Stai migliorando'), findsOneWidget);
    });
  });

  testWidgets(
    'the screens only talk to providers: they never touch storage themselves',
    (tester) async {
      final storage = SpyLocalStorage();
      await _open(tester, _fullMemory(), storage: storage);
      for (final tab in ['Percorso', 'Impara', 'Parole', 'Home']) {
        await _goTo(tester, tab);
      }
      // Only the daily routine's own repositories (its plan and the review
      // memory it asks the ReviewEngine about) touch storage, never a screen.
      expect(
        storage.accessedKeys.toSet().difference({
          'daily_routine',
          'review_memory',
        }),
        isEmpty,
      );
    },
  );

  testWidgets('declared preferences and learned memory are independent', (
    tester,
  ) async {
    final repo = _fullMemory();
    await _open(tester, repo);
    await _goTo(tester, 'Profilo');
    await tester.tap(find.text('Livello'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B2 — Intermedio alto'));
    await tester.pumpAndSettle();
    expect(find.text('B2 — Intermedio alto'), findsOneWidget);

    await _goTo(tester, 'Percorso');
    expect(find.text('Stai migliorando'), findsOneWidget);
    expect(find.text('Da rinforzare'), findsOneWidget);
    expect(
      repo.summary.errors,
      hasLength(2),
      reason: 'the memory was not altered',
    );
  });

  testWidgets(
    'the screens update by themselves when a conversation changes the memory',
    (tester) async {
      final storage = InMemoryLocalStorage();
      final ai = FakeAIService(
        onRequest: (_) async => const Success(
          AIResponse(
            message: 'Quasi!',
            corrections: [
              Correction(
                original: 'Ieri ho andato al supermercato.',
                corrected: 'Ieri sono andato al supermercato.',
                explanation: 'Con andare si usa essere.',
                category: CorrectionCategory.grammar,
              ),
            ],
          ),
        ),
      );
      await pumpApp(
        tester,
        storage,
        profile: onboardedProfile,
        overrides: [aiServiceProvider.overrideWithValue(ai)],
      );

      await _goTo(tester, 'Percorso');
      expect(find.text('Stiamo iniziando a conoscerti.'), findsOneWidget);

      await _goTo(tester, 'Parla');
      await tester.enterText(
        find.byType(TextField),
        'Ieri ho andato al supermercato.',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Invia'));
      await tester.pumpAndSettle();

      await _goTo(tester, 'Percorso');
      expect(find.text('Stiamo iniziando a conoscerti.'), findsNothing);
      expect(find.text('Da rinforzare'), findsOneWidget);
      expect(_inTiles<TopicTile>('Essere e avere'), findsOneWidget);
      expect(_inTiles<TopicTile>('Passato prossimo'), findsOneWidget);

      await _goTo(tester, 'Home');
      expect(find.text('Il tuo focus'), findsOneWidget);
    },
  );
}
