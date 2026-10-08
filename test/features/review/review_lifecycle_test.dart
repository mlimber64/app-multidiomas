import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/shared/ui/ui.dart';
import 'package:parla_con_me/features/learning/data/local_learning_repository.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_error.dart';
import 'package:parla_con_me/features/review/data/local_review_repository.dart';
import 'package:parla_con_me/features/review/presentation/review_screen.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

Finder get _ripassaTile => find
    .descendant(of: find.byType(AppCard), matching: find.text('Ripassa'))
    .last;

Future<InMemoryLocalStorage> _seeded() async {
  final storage = InMemoryLocalStorage();
  final learning = LocalLearningRepository(storage);
  for (var i = 0; i < 2; i++) {
    await learning.recordError(
      LearningError(
        id: 'ho andato -> sono andato',
        category: LearningErrorCategory.grammar,
        original: 'ho andato',
        corrected: 'sono andato',
        firstSeenAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
        confidence: 0.9,
        grammarTopic: GrammarTopic.essereVsAvere,
      ),
    );
  }
  return storage;
}

void main() {
  testWidgets('tapping Ripassa twice quickly opens one review screen', (
    tester,
  ) async {
    await pumpApp(tester, await _seeded(), profile: onboardedProfile);
    await tester.tap(_ripassaTile);
    // A real double tap has at least a frame between the two taps.
    await tester.pump();
    await tester.tap(_ripassaTile, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen, skipOffstage: false), findsOneWidget);

    // One back is enough to leave.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen, skipOffstage: false), findsNothing);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgets('leaving mid-session records nothing; reopening starts fresh', (
    tester,
  ) async {
    final storage = await _seeded();
    await pumpApp(tester, storage, profile: onboardedProfile);

    await tester.tap(_ripassaTile);
    await tester.pumpAndSettle();
    expect(find.text('Correggi la frase'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'sono andato');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    final repo = LocalReviewRepository(storage);
    final items = (await repo.getItems()).when(
      success: (i) => i,
      failure: (f) => fail('unexpected $f'),
    );
    expect(items, isNotEmpty);
    expect(items.every((i) => i.lastReviewedAt == null), isTrue);
    expect(
      items.every((i) => i.successfulReviews + i.failedReviews == 0),
      isTrue,
    );

    // A new session: the previous half-typed answer is gone, same exercise.
    await tester.tap(_ripassaTile);
    await tester.pumpAndSettle();
    expect(find.text('Correggi la frase'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.text('1 di 1'), findsOneWidget);
  });

  testWidgets('a correct answer is scheduled once and not offered again', (
    tester,
  ) async {
    final storage = await _seeded();
    await pumpApp(tester, storage, profile: onboardedProfile);

    await tester.tap(_ripassaTile);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sono andato');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Controlla'));
    await tester.pumpAndSettle();
    expect(find.text('Esatto!'), findsOneWidget);
    // Double tap on Continua: one transition only.
    await tester.tap(find.widgetWithText(FilledButton, 'Continua'));
    await tester.tap(
      find.widgetWithText(FilledButton, 'Continua'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ripasso completato'), findsOneWidget);

    final items = (await LocalReviewRepository(storage).getItems()).when(
      success: (i) => i,
      failure: (f) => fail('unexpected $f'),
    );
    final reviewed = items.where((i) => i.lastReviewedAt != null).toList();
    expect(reviewed, hasLength(1));
    expect(reviewed.single.successfulReviews, 1);
    expect(reviewed.single.failedReviews, 0);
    expect(reviewed.single.interval, const Duration(days: 1));

    // Back to Percorso, then Ripassa again: due tomorrow, so nothing now.
    await tester.tap(find.widgetWithText(FilledButton, 'Torna al percorso'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_ripassaTile);
    await tester.pumpAndSettle();
    expect(find.text('Nessun ripasso disponibile'), findsOneWidget);
  });
}
