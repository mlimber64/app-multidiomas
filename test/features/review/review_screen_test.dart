import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/review/domain/exercise.dart';
import 'package:parla_con_me/features/review/domain/review_session.dart';
import 'package:parla_con_me/features/review/presentation/review_session_controller.dart';

import 'package:parla_con_me/shared/widgets/selectable_option_tile.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

// --- a controller whose state the test drives ---------------------------------

class _FakeSession extends ReviewSessionController {
  _FakeSession({this.onStart});

  /// What `start()` does; by default it never leaves `loading`.
  final void Function(_FakeSession)? onStart;
  int starts = 0;
  int continues = 0;
  final submitted = <String>[];
  bool accept = true;

  @override
  ReviewSessionState build() => const ReviewSessionState();

  @override
  Future<void> start() async {
    starts++;
    state = const ReviewSessionState(status: ReviewSessionStatus.loading);
    onStart?.call(this);
  }

  @override
  Future<bool> submitAnswer(String answer) async {
    submitted.add(answer);
    return accept;
  }

  @override
  void continueSession() => continues++;

  void emit(ReviewSessionState s) => state = s;
}

Exercise _typed({
  ExerciseType type = ExerciseType.errorCorrection,
  String prompt = 'ho andato',
  String correct = 'sono andato',
  String explanation = 'Usiamo "essere" con andare.',
}) => Exercise(
  id: 'exercise:error:a',
  reviewItemId: 'error:a',
  type: type,
  prompt: prompt,
  correctAnswer: correct,
  explanation: explanation,
);

final _choice = Exercise(
  id: 'exercise:grammar:essereVsAvere',
  reviewItemId: 'grammar:essereVsAvere',
  type: ExerciseType.grammarChoice,
  prompt: 'essereVsAvere',
  options: const ['ho andato', 'sono andato'],
  correctAnswer: 'sono andato',
  explanation: 'Usiamo "essere" con andare.',
);

ReviewSessionState _answering(Exercise e, {int total = 5, int index = 1}) =>
    ReviewSessionState(
      status: ReviewSessionStatus.answering,
      exercises: [for (var i = 0; i < total; i++) e],
      index: index,
    );

ReviewSessionState _feedback(
  Exercise e, {
  required bool correct,
  String answer = 'x',
}) => ReviewSessionState(
  status: ReviewSessionStatus.feedback,
  exercises: [e],
  outcome: AnswerOutcome(
    answer: answer,
    isCorrect: correct,
    correctAnswer: e.correctAnswer,
    explanation: e.explanation,
  ),
);

Future<_FakeSession> _open(
  WidgetTester tester, {
  void Function(_FakeSession)? onStart,
}) async {
  final fake = _FakeSession(onStart: onStart);
  await pumpApp(
    tester,
    InMemoryLocalStorage(),
    profile: onboardedProfile,
    overrides: <Override>[
      reviewSessionControllerProvider.overrideWith(() => fake),
    ],
  );
  await tester.tap(
    find.descendant(of: find.byType(Card), matching: find.text('Ripassa')),
  );
  await tester.pump();
  await tester.pump();
  return fake;
}

Finder _button(String label) => find.widgetWithText(FilledButton, label);
bool _enabled(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(_button(label)).onPressed != null;

void main() {
  group('navigation', () {
    testWidgets('Ripassa opens the real screen, starts one session', (
      tester,
    ) async {
      final fake = await _open(tester);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Ripassa'),
        ),
        findsOneWidget,
      );
      expect(fake.starts, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NavigationBar), findsNothing);
      expect(fake.starts, 1, reason: 'rebuilds never start another session');
    });

    testWidgets('back returns to Home without recording anything', (
      tester,
    ) async {
      final fake = await _open(
        tester,
        onStart: (f) => f.emit(_answering(_typed())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Il tuo percorso'), findsOneWidget);
      expect(fake.submitted, isEmpty);
    });

    testWidgets('completion leads back to the path', (tester) async {
      await _open(
        tester,
        onStart: (f) => f.emit(
          ReviewSessionState(
            status: ReviewSessionStatus.completed,
            exercises: [_typed()],
            summary: const ReviewSessionSummary(correct: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_button('Torna al percorso'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Percorso'),
        ),
        findsOneWidget,
      );
    });
  });

  group('states', () {
    testWidgets('loading', (tester) async {
      await _open(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('empty session is friendly and shows no internals', (
      tester,
    ) async {
      await _open(
        tester,
        onStart: (f) => f.emit(
          const ReviewSessionState(
            status: ReviewSessionStatus.completed,
            summary: ReviewSessionSummary(skipped: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nessun ripasso disponibile'), findsOneWidget);
      expect(
        find.textContaining('Per ora non ci sono esercizi pronti'),
        findsOneWidget,
      );
      expect(find.textContaining('skipped'), findsNothing);
      expect(find.textContaining('3'), findsNothing);
      expect(_button('Torna al percorso'), findsOneWidget);
    });

    testWidgets('error shows a friendly message and retry restarts', (
      tester,
    ) async {
      final fake = await _open(
        tester,
        onStart: (f) {
          if (f.starts == 1) {
            f.emit(
              const ReviewSessionState(
                status: ReviewSessionStatus.error,
                failure: StorageFailure('boom'),
              ),
            );
          }
        },
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Non sono riuscito'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      await tester.tap(find.text('Riprova'));
      await tester.pump();
      expect(fake.starts, 2);
    });

    testWidgets('completed shows the session summary from the controller', (
      tester,
    ) async {
      await _open(
        tester,
        onStart: (f) => f.emit(
          ReviewSessionState(
            status: ReviewSessionStatus.completed,
            exercises: [_typed()],
            summary: const ReviewSessionSummary(
              correct: 4,
              incorrect: 1,
              skipped: 2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ripasso completato'), findsOneWidget);
      expect(find.text('5 esercizi completati'), findsOneWidget);
      expect(find.text('4 corrette'), findsOneWidget);
      expect(find.text('1 da riprovare'), findsOneWidget);
      expect(find.textContaining('XP'), findsNothing);
    });
  });

  group('exercises', () {
    testWidgets('error correction: fragment and text input', (tester) async {
      await _open(tester, onStart: (f) => f.emit(_answering(_typed())));
      await tester.pumpAndSettle();
      expect(find.text('2 di 5'), findsOneWidget);
      expect(find.text('Correggi la frase'), findsOneWidget);
      expect(find.text('ho andato'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('La tua risposta'), findsOneWidget);
    });

    testWidgets('vocabulary: contextual prompt and text input', (tester) async {
      await _open(
        tester,
        onStart: (f) => f.emit(
          _answering(
            _typed(
              type: ExerciseType.vocabularyContext,
              prompt: 'il ${Exercise.blank}',
              correct: 'computer',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Completa la frase'), findsOneWidget);
      expect(find.text('il ____'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('grammar: topic label and single-choice options', (
      tester,
    ) async {
      await _open(tester, onStart: (f) => f.emit(_answering(_choice)));
      await tester.pumpAndSettle();
      expect(find.text('Scegli la risposta corretta'), findsOneWidget);
      expect(find.text('Essere e avere'), findsOneWidget);
      expect(find.text('ho andato'), findsOneWidget);
      expect(find.text('sono andato'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('ho andato'));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.tap(find.text('sono andato'));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget, reason: 'single');
    });
  });

  group('interaction', () {
    testWidgets('Controlla is disabled until there is an answer (text)', (
      tester,
    ) async {
      await _open(tester, onStart: (f) => f.emit(_answering(_typed())));
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'Controlla'), isFalse);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(_enabled(tester, 'Controlla'), isFalse);
      await tester.enterText(find.byType(TextField), 'sono andato');
      await tester.pump();
      expect(_enabled(tester, 'Controlla'), isTrue);
    });

    testWidgets('Controlla is disabled until an option is chosen', (
      tester,
    ) async {
      await _open(tester, onStart: (f) => f.emit(_answering(_choice)));
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'Controlla'), isFalse);
      await tester.tap(find.text('sono andato'));
      await tester.pump();
      expect(_enabled(tester, 'Controlla'), isTrue);
    });

    testWidgets('submit forwards the answer to the controller only', (
      tester,
    ) async {
      final fake = await _open(
        tester,
        onStart: (f) => f.emit(_answering(_choice)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ho andato'));
      await tester.pump();
      await tester.tap(_button('Controlla'));
      await tester.pump();
      expect(fake.submitted, ['ho andato']);
    });

    testWidgets('typed answers are sent as typed', (tester) async {
      final fake = await _open(
        tester,
        onStart: (f) => f.emit(_answering(_typed())),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), ' Sono Andato ');
      await tester.pump();
      await tester.tap(_button('Controlla'));
      await tester.pump();
      expect(fake.submitted, [' Sono Andato ']);
    });

    testWidgets('no second submission while submitting', (tester) async {
      final fake = await _open(
        tester,
        onStart: (f) => f.emit(_answering(_choice)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('sono andato'));
      await tester.pump();
      await tester.tap(_button('Controlla'));
      await tester.pump();
      // The controller moves to submitting.
      fake.emit(
        ReviewSessionState(
          status: ReviewSessionStatus.submitting,
          exercises: [_choice],
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      expect(fake.submitted, hasLength(1));
    });

    testWidgets(
      'Continua only exists after feedback and calls the controller',
      (tester) async {
        final fake = await _open(
          tester,
          onStart: (f) => f.emit(_answering(_typed())),
        );
        await tester.pumpAndSettle();
        expect(_button('Continua'), findsNothing);

        fake.emit(_feedback(_typed(), correct: true, answer: 'sono andato'));
        await tester.pumpAndSettle();
        expect(_button('Controlla'), findsNothing);
        await tester.tap(_button('Continua'));
        await tester.pump();
        expect(fake.continues, 1);
      },
    );
  });

  group('feedback', () {
    testWidgets('correct', (tester) async {
      final fake = await _open(tester);
      fake.emit(_feedback(_typed(), correct: true, answer: 'sono andato'));
      await tester.pumpAndSettle();
      expect(find.text('Esatto!'), findsOneWidget);
      expect(find.text('Quasi.'), findsNothing);
      expect(find.text('Usiamo "essere" con andare.'), findsOneWidget);
    });

    testWidgets('incorrect shows answer, correct answer and explanation', (
      tester,
    ) async {
      final fake = await _open(tester);
      fake.emit(_feedback(_typed(), correct: false, answer: 'ho andato'));
      await tester.pumpAndSettle();
      expect(find.text('Quasi.'), findsOneWidget);
      expect(find.text('La tua risposta: ho andato'), findsOneWidget);
      expect(find.text('La risposta corretta è:'), findsOneWidget);
      expect(find.text('sono andato'), findsOneWidget);
      expect(find.text('Usiamo "essere" con andare.'), findsOneWidget);
      // Not only color: icons and text.
      expect(find.byIcon(Icons.info), findsOneWidget);
    });

    testWidgets('no explanation: nothing is invented', (tester) async {
      final fake = await _open(tester);
      fake.emit(
        _feedback(_typed(explanation: ''), correct: false, answer: 'x'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quasi.'), findsOneWidget);
      expect(find.textContaining('essere'), findsNothing);
    });

    testWidgets('the submitted answer cannot be edited', (tester) async {
      final fake = await _open(
        tester,
        onStart: (f) => f.emit(_answering(_typed())),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ho andato');
      await tester.pump();
      fake.emit(_feedback(_typed(), correct: false, answer: 'ho andato'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      expect(field.controller!.text, 'ho andato');
    });

    testWidgets('choices after feedback mark chosen and correct, with text', (
      tester,
    ) async {
      final fake = await _open(
        tester,
        onStart: (f) => f.emit(_answering(_choice)),
      );
      await tester.pumpAndSettle();
      fake.emit(_feedback(_choice, correct: false, answer: 'ho andato'));
      await tester.pumpAndSettle();
      expect(find.text('Risposta corretta'), findsOneWidget);
      expect(find.text('La tua risposta'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      // Options can no longer be changed: no selectable tiles remain.
      expect(find.byType(SelectableOptionTile), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('keyboard open: no overflow and the button stays visible', (
      tester,
    ) async {
      await _open(tester, onStart: (f) => f.emit(_answering(_typed())));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sono');
      tester.view.viewInsets = const FakeViewPadding(bottom: 1200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final bottom = tester.getRect(_button('Controlla')).bottom;
      expect(
        bottom,
        lessThanOrEqualTo(800 - 400),
        reason: 'above the keyboard',
      );
    });
  });

  group('end to end with the real controller', () {
    testWidgets('a wrong answer, feedback and completion', (tester) async {
      final storage = InMemoryLocalStorage();
      final learning = LocalLearningRepository(storage);
      for (var i = 0; i < 2; i++) {
        await learning.recordError(
          LearningError(
            id: 'ho andato -> sono andato',
            category: LearningErrorCategory.grammar,
            original: 'ho andato',
            corrected: 'sono andato',
            explanation: 'Usiamo "essere" con andare.',
            firstSeenAt: DateTime.now(),
            lastSeenAt: DateTime.now(),
            confidence: 0.9,
            grammarTopic: GrammarTopic.essereVsAvere,
          ),
        );
      }
      await pumpApp(tester, storage, profile: onboardedProfile);
      await tester.tap(
        find.descendant(of: find.byType(Card), matching: find.text('Ripassa')),
      );
      await tester.pumpAndSettle();

      // The real session: whatever the generator can build from this memory.
      expect(find.text('Correggi la frase'), findsOneWidget);
      expect(find.text('1 di 1'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ho andato');
      await tester.pump();
      await tester.tap(_button('Controlla'));
      await tester.pumpAndSettle();
      expect(find.text('Quasi.'), findsOneWidget);
      expect(find.text('Usiamo "essere" con andare.'), findsOneWidget);

      await tester.tap(_button('Continua'));
      await tester.pumpAndSettle();
      expect(find.text('Ripasso completato'), findsOneWidget);
      expect(find.text('1 esercizio completato'), findsOneWidget);
      expect(find.text('0 corrette'), findsOneWidget);
      expect(find.text('1 da riprovare'), findsOneWidget);
      expect(storage.data.keys.toSet(), {'learning_memory', 'review_memory'});

      await tester.tap(_button('Torna al percorso'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
