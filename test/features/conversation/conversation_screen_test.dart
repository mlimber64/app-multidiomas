import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/shared/ui/app_bottom_nav.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

Future<void> _openParla(
  WidgetTester tester,
  FakeAIService ai, {
  InMemoryLocalStorage? storage,
}) async {
  await pumpApp(
    tester,
    storage ?? InMemoryLocalStorage(),
    profile: onboardedProfile,
    overrides: [
      aiServiceProvider.overrideWithValue(ai),
      learningEngineProvider.overrideWithValue(RecordingLearningEngine()),
    ],
  );
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text('Parla'),
    ),
  );
  await tester.pumpAndSettle();
}

// Found by tooltip because the icon becomes a spinner while sending.
Finder get _sendButton => find.ancestor(
  of: find.byTooltip('Invia'),
  matching: find.byType(IconButton),
);

bool _sendEnabled(WidgetTester tester) =>
    tester.widget<IconButton>(_sendButton).onPressed != null;

void main() {
  testWidgets(
    'first use: greeting and suggestions; a suggestion starts the chat',
    (tester) async {
      final ai = FakeAIService();
      await _openParla(tester, ai);

      expect(
        find.text('Ciao! Sono il tuo insegnante di lingue.'),
        findsOneWidget,
      );
      expect(find.text('Di cosa vuoi parlare oggi?'), findsOneWidget);
      expect(find.text('Coming in a later phase'), findsNothing);

      await tester.tap(find.text('La mia giornata'));
      await tester.pumpAndSettle();

      expect(
        find.text('La mia giornata'),
        findsOneWidget,
        reason: 'now a bubble',
      );
      expect(find.text('Bene! E poi?'), findsOneWidget);
      expect(
        find.text('Parliamo del lavoro'),
        findsNothing,
        reason: 'suggestions hidden',
      );
      expect(ai.requests.single.messages.single.text, 'La mia giornata');
    },
  );

  testWidgets(
    'send is disabled when empty; typing sends and clears the field',
    (tester) async {
      final ai = FakeAIService();
      await _openParla(tester, ai);

      expect(_sendEnabled(tester), isFalse);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(_sendEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), 'Ciao');
      await tester.pump();
      expect(_sendEnabled(tester), isTrue);
      await tester.tap(_sendButton);
      await tester.pumpAndSettle();

      expect(find.text('Ciao'), findsOneWidget);
      expect(find.text('Bene! E poi?'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(_sendEnabled(tester), isFalse);
    },
  );

  testWidgets('shows a typing indicator while the teacher replies', (
    tester,
  ) async {
    final ai = FakeAIService(
      onRequest: (_) => Future.delayed(
        const Duration(seconds: 1),
        () => const Success(AIResponse(message: 'Ecco')),
      ),
    );
    await _openParla(tester, ai);

    await tester.enterText(find.byType(TextField), 'Ciao');
    await tester.pump();
    await tester.tap(_sendButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.bySemanticsLabel('Il professore sta scrivendo'),
      findsOneWidget,
    );
    expect(_sendEnabled(tester), isFalse, reason: 'no duplicate sends');
    expect(find.text('Ciao'), findsOneWidget, reason: 'history stays visible');

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Ecco'), findsOneWidget);
    expect(find.bySemanticsLabel('Il professore sta scrivendo'), findsNothing);
  });

  testWidgets(
    'corrections appear as cards and Correggimi is passed to the AI',
    (tester) async {
      final ai = FakeAIService(
        onRequest: (_) async => const Success(
          AIResponse(
            message: 'Quasi! 😊 E com’è andata?',
            corrections: [
              Correction(
                original: 'ho andato',
                corrected: 'sono andato',
                explanation: 'Con "andare" si usa "essere".',
                naturalAlternative: 'Sono stato',
                category: CorrectionCategory.grammar,
              ),
            ],
          ),
        ),
      );
      await _openParla(tester, ai);

      await tester.tap(find.text('Correggimi'));
      await tester.pump();
      await tester.enterText(
        find.byType(TextField),
        'Ieri ho andato al supermercato.',
      );
      await tester.pump();
      await tester.tap(_sendButton);
      await tester.pumpAndSettle();

      expect(
        ai.requests.single.systemInstruction,
        contains('CORRECTION MODE is ON'),
      );
      expect(find.text('Grammatica'), findsOneWidget);
      expect(
        find.textContaining('ho andato', findRichText: true),
        findsWidgets,
      );
      expect(
        find.textContaining('sono andato', findRichText: true),
        findsWidgets,
      );
      expect(find.text('Con "andare" si usa "essere".'), findsOneWidget);
      expect(find.text('Più naturale: Sono stato'), findsOneWidget);
    },
  );

  testWidgets('errors are friendly (no internals), retry works', (
    tester,
  ) async {
    var failing = true;
    final ai = FakeAIService(
      onRequest: (_) async => failing
          ? const Failure(
              AIFailure('HTTP 503 secret-detail', kind: AIFailureKind.unknown),
            )
          : const Success(AIResponse(message: 'Eccomi di nuovo!')),
    );
    await _openParla(tester, ai);

    await tester.enterText(find.byType(TextField), 'Ciao');
    await tester.pump();
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Non riesco a rispondere in questo momento. Riproviamo?'),
      findsOneWidget,
    );
    expect(find.textContaining('503'), findsNothing);
    expect(find.textContaining('secret-detail'), findsNothing);
    expect(find.text('Ciao'), findsOneWidget);

    failing = false;
    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();

    expect(find.text('Eccomi di nuovo!'), findsOneWidget);
    expect(find.text('Riprova'), findsNothing);
  });

  testWidgets('missing configuration gets its own friendly message', (
    tester,
  ) async {
    final ai = FakeAIService(
      onRequest: (_) async =>
          const Failure(AIFailure('no key', kind: AIFailureKind.notConfigured)),
    );
    await _openParla(tester, ai);
    await tester.tap(find.text('La mia giornata'));
    await tester.pumpAndSettle();
    expect(find.textContaining('non è ancora configurato'), findsOneWidget);
  });

  testWidgets(
    'new conversation clears the screen; reopening restores the latest',
    (tester) async {
      final storage = InMemoryLocalStorage();
      final ai = FakeAIService();
      await _openParla(tester, ai, storage: storage);

      final newButton = find.widgetWithIcon(
        IconButton,
        Icons.add_comment_outlined,
      );
      expect(
        tester.widget<IconButton>(newButton).onPressed,
        isNull,
        reason: 'nothing to reset yet',
      );

      await tester.tap(find.text('La mia giornata'));
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(newButton).onPressed, isNotNull);

      await tester.tap(newButton);
      await tester.pumpAndSettle();
      expect(
        find.text('Ciao! Sono il tuo insegnante di lingue.'),
        findsOneWidget,
      );
      expect(find.text('Bene! E poi?'), findsNothing);

      // "Close and reopen" the app: the first conversation is still there.
      await tester.pumpWidget(const SizedBox());
      await _openParla(tester, FakeAIService(), storage: storage);
      expect(find.text('La mia giornata'), findsOneWidget);
      expect(find.text('Bene! E poi?'), findsOneWidget);
    },
  );
}
