import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/theme/app_tokens.dart';
import 'package:parla_con_me/features/conversation/presentation/conversation_screen.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';
import 'package:parla_con_me/features/learning/presentation/favorite_words.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/features/learning/presentation/widgets/vocabulary_tile.dart';
import 'package:parla_con_me/shared/ui/ui.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/learning_fixtures.dart';
import '../../support/pump_app.dart';

// The redesign of "Parole": the mastery meter, the starred words, a friendly
// empty state for each tab, the tabs' feedback and a list built on demand.
// The interface of these tests is Italian.

Future<InMemoryLocalStorage> _open(
  WidgetTester tester,
  FakeMemoryRepository repo, {
  InMemoryLocalStorage? storage,
}) async {
  final store = storage ?? InMemoryLocalStorage();
  await pumpApp(
    tester,
    store,
    profile: onboardedProfile,
    overrides: [learningRepositoryProvider.overrideWithValue(repo)],
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text('Parole'),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

FakeMemoryRepository _memory(List<UserVocabulary> words) =>
    FakeMemoryRepository(summaryOf(vocabulary: words));

// The tabs (SegmentedPills of the screen's private tab type).
final _pills = find.byWidgetPredicate(
  (w) => w.runtimeType.toString().startsWith('SegmentedPills'),
);

Finder _tab(String label) =>
    find.descendant(of: _pills, matching: find.text(label));

void main() {
  group('mastery meter', () {
    testWidgets('three dots, filled by correct uses, with the count in words', (
      tester,
    ) async {
      await _open(
        tester,
        _memory([
          wordOf('appuntamento', exposure: 3, successes: 1),
          wordOf('scontrino', exposure: 5, successes: 5),
        ]),
      );
      await tester.tap(_tab('Tutte'));
      await tester.pumpAndSettle();
      expect(find.text('1/3 usi corretti'), findsOneWidget);
      // More than three uses fill the meter, never more than that.
      expect(find.text('3/3 usi corretti'), findsOneWidget);
    });

    testWidgets('a word with no correct use yet says 0/3', (tester) async {
      await _open(tester, _memory([wordOf('prenotazione')]));
      expect(find.text('0/3 usi corretti'), findsOneWidget);
    });
  });

  group('favorite words', () {
    testWidgets('a star is saved, shown at once and put first', (tester) async {
      final storage = await _open(
        tester,
        _memory([wordOf('prenotazione'), wordOf('appuntamento')]),
      );
      List<String> order() => [
        for (final t in tester.widgetList<VocabularyTile>(
          find.byType(VocabularyTile),
        ))
          t.word.word,
      ];
      expect(order(), ['prenotazione', 'appuntamento']);

      // Star the second one.
      await tester.tap(find.byTooltip('Segna come preferita').last);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Togli dai preferiti'), findsOneWidget);
      expect(order(), ['appuntamento', 'prenotazione']);
      final saved = await storage.readString(FavoriteWords.storageKey);
      final ids = saved.when(
        success: (raw) => jsonDecode(raw!) as List,
        failure: (_) => fail('could not read'),
      );
      expect(ids, hasLength(1));
      expect(ids.single, endsWith(':appuntamento'));

      // And it can be taken off again.
      await tester.tap(find.byTooltip('Togli dai preferiti'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Togli dai preferiti'), findsNothing);
      expect(order(), ['prenotazione', 'appuntamento']);
    });

    testWidgets('the stars are still there in the next session', (
      tester,
    ) async {
      final storage = await _open(tester, _memory([wordOf('appuntamento')]));
      await tester.tap(find.byTooltip('Segna come preferita'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await _open(tester, _memory([wordOf('appuntamento')]), storage: storage);
      expect(find.byTooltip('Togli dai preferiti'), findsOneWidget);
    });

    testWidgets('an unreadable list of stars is an empty one', (tester) async {
      final storage = InMemoryLocalStorage();
      await storage.writeString(FavoriteWords.storageKey, '{not json');
      await _open(tester, _memory([wordOf('appuntamento')]), storage: storage);
      expect(find.byTooltip('Segna come preferita'), findsOneWidget);
    });
  });

  group('empty states, by tab', () {
    testWidgets('nothing to consolidate: all caught up, and a way to talk', (
      tester,
    ) async {
      await _open(
        tester,
        _memory([wordOf('scontrino', exposure: 5, successes: 5)]),
      );
      // Opens on "In uso" (the first tab with words); go to the empty one.
      await tester.tap(_tab('Da consolidare'));
      await tester.pumpAndSettle();
      expect(find.text('Tutto in pari'), findsOneWidget);
      expect(find.byType(VocabularyTile), findsNothing);

      // The invitation leads to the conversation.
      await tester.tap(find.widgetWithText(PrimaryButton, 'Parliamo'));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationScreen), findsOneWidget);
    });

    testWidgets('no word in use yet: says so and invites to use them', (
      tester,
    ) async {
      await _open(tester, _memory([wordOf('prenotazione')]));
      await tester.tap(_tab('In uso'));
      await tester.pumpAndSettle();
      expect(find.text('Ancora nessuna parola in uso'), findsOneWidget);
      expect(find.byType(VocabularyTile), findsNothing);
      expect(find.widgetWithText(PrimaryButton, 'Parliamo'), findsOneWidget);

      // The other tab is not empty.
      await tester.tap(_tab('Da consolidare'));
      await tester.pumpAndSettle();
      expect(find.text('Ancora nessuna parola in uso'), findsNothing);
      expect(find.byType(VocabularyTile), findsOneWidget);
    });

    testWidgets('no words at all: the same friendly start', (tester) async {
      await _open(tester, FakeMemoryRepository());
      expect(find.text('Le tue parole appariranno qui'), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'Parliamo'), findsOneWidget);
      expect(_pills, findsNothing);
    });
  });

  group('tabs', () {
    testWidgets('the active tab is filled green with white text', (
      tester,
    ) async {
      await _open(
        tester,
        _memory([
          wordOf('prenotazione'),
          wordOf('scontrino', exposure: 5, successes: 5),
        ]),
      );
      Color? background(String label) {
        final box = tester.widget<AnimatedContainer>(
          find.ancestor(
            of: _tab(label),
            matching: find.byType(AnimatedContainer),
          ),
        );
        return (box.decoration! as BoxDecoration).color;
      }

      Color? textColor(String label) =>
          tester.widget<Text>(_tab(label)).style?.color;

      expect(background('Da consolidare'), AppColors.green);
      expect(textColor('Da consolidare'), Colors.white);
      expect(background('In uso'), Colors.transparent);

      await tester.tap(_tab('In uso'));
      await tester.pumpAndSettle();
      expect(background('In uso'), AppColors.green);
      expect(textColor('In uso'), Colors.white);
      expect(background('Da consolidare'), Colors.transparent);
    });
  });

  testWidgets('a long list is built on demand, not all at once', (
    tester,
  ) async {
    await _open(tester, _memory([for (var i = 0; i < 45; i++) wordOf('p$i')]));
    Set<String> built() => {
      for (final t in tester.widgetList<VocabularyTile>(
        find.byType(VocabularyTile),
      ))
        t.word.word,
    };
    final first = built();
    expect(first, isNotEmpty);
    expect(first.length, lessThan(45));

    // Scrolling builds others (and lets go of what left the screen).
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -20000));
    await tester.pumpAndSettle();
    final last = built();
    expect(last, isNotEmpty);
    expect(last.length, lessThan(45));
    expect(last.intersection(first), isEmpty);
  });
}
