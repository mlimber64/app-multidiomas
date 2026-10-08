import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/shared/ui/ui.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/learning/domain/language_learning_rules.dart';
import 'package:parla_con_me/features/profile/data/local_user_learning_profile_repository.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

UserLearningProfile _unwrap(Result<UserLearningProfile> r) =>
    r.when(success: (p) => p, failure: (f) => fail('unexpected $f'));

const _key = 'user_learning_profile';

/// Taps an option inside the open bottom sheet (the same labels also show on
/// the Profile page behind it).
Future<void> tap(WidgetTester tester, String label) async {
  final option = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.text(label),
  );
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  group('UserLearningProfile', () {
    test('languages default to the supported pair and are configurable', () {
      expect(UserLearningProfile.empty.supportLanguage, AppLanguage.spanish);
      expect(UserLearningProfile.empty.learningLanguage, AppLanguage.italian);
      final other = UserLearningProfile.empty.copyWith(
        learningLanguage: AppLanguage.spanish,
        supportLanguage: AppLanguage.italian,
      );
      expect(other.learningLanguage, AppLanguage.spanish);
      expect(other.supportLanguage, AppLanguage.italian);
      expect(other, isNot(UserLearningProfile.empty));
    });

    test('equality and hashCode ignore set order', () {
      const a = UserLearningProfile(
        goals: {LearningGoal.work, LearningGoal.study},
      );
      const b = UserLearningProfile(
        goals: {LearningGoal.study, LearningGoal.work},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('validity enforces minimum and maximum of goals and focus', () {
      const complete = UserLearningProfile(
        level: LanguageLevel.a2,
        goals: {LearningGoal.work},
        focusAreas: {LearningFocus.grammar},
      );
      expect(complete.isValid, isTrue);
      expect(complete.copyWith(goals: {}).isValid, isFalse);
      expect(complete.copyWith(focusAreas: {}).isValid, isFalse);
      expect(
        complete
            .copyWith(
              goals: {
                LearningGoal.work,
                LearningGoal.study,
                LearningGoal.writeBetter,
                LearningGoal.liveAbroad,
              },
            )
            .isValid,
        isFalse,
      );
      expect(UserLearningProfile.empty.isValid, isFalse);
      expect(
        const UserLearningProfile(
          goals: {LearningGoal.work},
          focusAreas: {LearningFocus.grammar},
        ).isValid,
        isFalse,
        reason: 'level is required',
      );
    });

    test('toggleSelection respects max and the exclusive option', () {
      const ex = LearningGoal.everything;
      var s = <LearningGoal>{};
      s = toggleSelection(s, LearningGoal.work, max: 2, exclusive: ex);
      s = toggleSelection(s, LearningGoal.study, max: 2, exclusive: ex);
      expect(s, {LearningGoal.work, LearningGoal.study});

      // Over the limit: unchanged.
      s = toggleSelection(s, LearningGoal.writeBetter, max: 2, exclusive: ex);
      expect(s, {LearningGoal.work, LearningGoal.study});

      // Exclusive clears the rest, and a concrete option clears it.
      s = toggleSelection(s, ex, max: 2, exclusive: ex);
      expect(s, {ex});
      s = toggleSelection(s, LearningGoal.work, max: 2, exclusive: ex);
      expect(s, {LearningGoal.work});

      // Removing is always allowed.
      expect(toggleSelection(s, LearningGoal.work, max: 2), isEmpty);
    });
  });

  group('LocalUserLearningProfileRepository', () {
    test(
      'returns an empty, not-onboarded profile when nothing is stored',
      () async {
        final repo = LocalUserLearningProfileRepository(InMemoryLocalStorage());
        expect(_unwrap(await repo.load()), UserLearningProfile.empty);
        expect(_unwrap(await repo.load()).onboardingCompleted, isFalse);
      },
    );

    test('saved profile can be recovered', () async {
      final repo = LocalUserLearningProfileRepository(InMemoryLocalStorage());
      const profile = UserLearningProfile(
        level: LanguageLevel.b1,
        goals: {LearningGoal.speakConfidently, LearningGoal.liveAbroad},
        focusAreas: {LearningFocus.grammar, LearningFocus.vocabulary},
        onboardingCompleted: true,
      );
      await repo.save(profile);
      expect(_unwrap(await repo.load()), profile);
      await repo.save(onboardedProfile);
      expect(_unwrap(await repo.load()), onboardedProfile);
    });

    test('a v1 profile migrates: goal -> goals, focus -> focusAreas', () async {
      final storage = InMemoryLocalStorage();
      final repo = LocalUserLearningProfileRepository(storage);
      storage.data[_key] = jsonEncode({
        'v': 1,
        'level': 'a2',
        'primaryGoal': 'liveInItaly',
        'learningFocus': 'grammar',
        'onboardingCompleted': true,
      });

      final migrated = _unwrap(await repo.load());
      expect(migrated.level, LanguageLevel.a2);
      expect(migrated.goals, {LearningGoal.liveAbroad});
      expect(migrated.focusAreas, {LearningFocus.grammar});
      expect(migrated.supportLanguage, AppLanguage.spanish);
      expect(migrated.learningLanguage, AppLanguage.italian);
      expect(migrated.onboardingCompleted, isTrue);
      expect(migrated.isValid, isTrue);

      // Saving writes v2 and reads back identically.
      await repo.save(migrated);
      final stored = jsonDecode(storage.data[_key]!) as Map<String, dynamic>;
      expect(stored['v'], 2);
      expect(stored['goals'], ['liveAbroad']);
      expect(stored.containsKey('primaryGoal'), isFalse);
      expect(_unwrap(await repo.load()), migrated);
    });

    test('reading replies aloud is stored, and off when absent', () async {
      final storage = InMemoryLocalStorage();
      final repo = LocalUserLearningProfileRepository(storage);
      await repo.save(onboardedProfile.copyWith(speakReplies: true));
      expect(_unwrap(await repo.load()).speakReplies, isTrue);
      await repo.save(onboardedProfile);
      expect(_unwrap(await repo.load()).speakReplies, isFalse);
      // Profiles saved before the setting existed.
      storage.data[_key] = jsonEncode({
        'v': 2,
        'level': 'a2',
        'goals': ['work'],
        'focusAreas': ['grammar'],
        'onboardingCompleted': true,
      });
      expect(_unwrap(await repo.load()).speakReplies, isFalse);
    });

    test('corrupt or unknown stored values never crash', () async {
      final storage = InMemoryLocalStorage();
      final repo = LocalUserLearningProfileRepository(storage);

      storage.data[_key] = '{not json';
      expect(_unwrap(await repo.load()), UserLearningProfile.empty);

      storage.data[_key] = jsonEncode({
        'level': 'c9',
        'primaryGoal': 'work',
        'onboardingCompleted': true,
      });
      final p = _unwrap(await repo.load());
      expect(p.level, isNull);
      expect(p.goals, {LearningGoal.work});
      expect(p.onboardingCompleted, isTrue);

      // Unknown names, wrong types, duplicates and too many entries.
      storage.data[_key] = jsonEncode({
        'v': 2,
        'supportLanguage': 'klingon',
        'learningLanguage': 42,
        'goals': [
          'work',
          'nope',
          7,
          'work',
          'study',
          'writeBetter',
          'liveAbroad',
        ],
        'focusAreas': 'grammar',
        'onboardingCompleted': 'yes',
      });
      final q = _unwrap(await repo.load());
      expect(q.supportLanguage, AppLanguage.spanish);
      expect(q.learningLanguage, AppLanguage.italian);
      expect(q.goals, hasLength(maxGoals));
      expect(q.goals, containsAll([LearningGoal.work, LearningGoal.study]));
      expect(q.focusAreas, {LearningFocus.grammar});
      expect(q.onboardingCompleted, isFalse);

      storage.data[_key] = '[1,2]';
      expect(_unwrap(await repo.load()), UserLearningProfile.empty);
    });
  });

  testWidgets('Profile shows the saved preferences and edits persist', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await LocalUserLearningProfileRepository(storage).save(onboardedProfile);
    await pumpApp(tester, storage);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Profilo'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Español'), findsOneWidget);
    // The language learned, and the interface (explicitly Italian here).
    expect(find.text('Italiano'), findsNWidgets(2));
    expect(find.text('A2 — Elementare'), findsOneWidget);
    expect(find.text('Conversazione'), findsOneWidget);

    await tester.tap(find.text('Livello'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B2 — Intermedio alto'));
    await tester.pumpAndSettle();

    expect(find.text('B2 — Intermedio alto'), findsOneWidget);
    expect(jsonDecode(storage.data[_key]!)['level'], 'b2');
  });

  testWidgets('Profile edits goals and focus areas as multi-select', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await LocalUserLearningProfileRepository(storage).save(onboardedProfile);
    await pumpApp(tester, storage);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Profilo'),
      ),
    );
    await tester.pumpAndSettle();

    // Goals: add two, remove the original -> saved only on "Salva".
    await tester.tap(find.text('Obiettivi'));
    await tester.pumpAndSettle();
    await tap(tester, 'Lavoro');
    await tap(tester, 'Studio');
    await tester.pumpAndSettle();
    expect(find.text('Scegli da 1 a 3 · 3 selezionati'), findsOneWidget);
    // At the maximum: other options are disabled and ignore taps.
    await tap(tester, 'Scrivere meglio');
    await tester.pumpAndSettle();
    expect(find.text('Scegli da 1 a 3 · 3 selezionati'), findsOneWidget);
    await tap(tester, 'Parlare con più sicurezza');
    await tester.pumpAndSettle();
    await tap(tester, 'Studio');
    await tester.pumpAndSettle();
    await tap(tester, 'Lavoro');
    await tester.pumpAndSettle();

    // Nothing selected: Salva is disabled.
    final save = find.widgetWithText(PrimaryButton, 'Salva');
    expect(tester.widget<PrimaryButton>(save).onPressed, isNull);
    await tap(tester, 'Studio');
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(jsonDecode(storage.data[_key]!)['goals'], ['study']);

    // Focus areas: add one.
    await tester.tap(find.text('Aree'));
    await tester.pumpAndSettle();
    await tap(tester, 'Grammatica');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Salva'));
    await tester.pumpAndSettle();
    expect(jsonDecode(storage.data[_key]!)['focusAreas'], [
      'conversation',
      'grammar',
    ]);
    expect(find.text('Conversazione, Grammatica'), findsOneWidget);
  });

  group('language pair', () {
    test('equality, hash and support rules', () {
      const a = LanguagePair(
        support: AppLanguage.spanish,
        learning: AppLanguage.italian,
      );
      const b = LanguagePair(
        support: AppLanguage.spanish,
        learning: AppLanguage.italian,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const LanguagePair(
            support: AppLanguage.italian,
            learning: AppLanguage.spanish,
          ),
        ),
      );
      expect(a.isSupported, isTrue);
      // Support and learning are different concepts, never the same language.
      expect(
        const LanguagePair(
          support: AppLanguage.italian,
          learning: AppLanguage.italian,
        ).isSupported,
        isFalse,
      );
      // Known by name is not the same as supported: French can be learned
      // but there is no French interface to explain things in.
      expect(
        const LanguagePair(
          support: AppLanguage.french,
          learning: AppLanguage.italian,
        ).isSupported,
        isFalse,
      );
    });

    test(
      'the profile exposes its pair; es -> it and es -> en are supported',
      () {
        expect(
          UserLearningProfile.empty.languagePair,
          const LanguagePair(
            support: AppLanguage.spanish,
            learning: AppLanguage.italian,
          ),
        );
        expect(availableSupportLanguages, [
          AppLanguage.spanish,
          AppLanguage.english,
          AppLanguage.italian,
        ]);
        // Italian first, then the languages added later, in order.
        expect(
          supportedLearningLanguages,
          containsAllInOrder([AppLanguage.italian, AppLanguage.english]),
        );
        expect(AppLanguage.english.code, 'en');
        const toEnglish = LanguagePair(
          support: AppLanguage.spanish,
          learning: AppLanguage.english,
        );
        expect(toEnglish.isSupported, isTrue);
        // Any interface language can be the support language of a learner of
        // another language the app teaches.
        expect(
          const LanguagePair(
            support: AppLanguage.italian,
            learning: AppLanguage.english,
          ).isSupported,
          isTrue,
        );
        expect(
          const LanguagePair(
            support: AppLanguage.english,
            learning: AppLanguage.italian,
          ).isSupported,
          isTrue,
        );
        expect(
          const LanguagePair(
            support: AppLanguage.english,
            learning: AppLanguage.english,
          ).isSupported,
          isFalse,
        );
        expect(
          const LanguagePair(
            support: AppLanguage.spanish,
            learning: AppLanguage.spanish,
          ).isSupported,
          isFalse,
        );
      },
    );

    test('every supported learning language has learning rules', () {
      for (final language in supportedLearningLanguages) {
        expect(learningRulesFor(language)?.language, language);
      }
      // No rules, no support: nothing else claims to be teachable.
      for (final language in AppLanguage.values) {
        if (!supportedLearningLanguages.contains(language)) {
          expect(learningRulesFor(language), isNull);
        }
      }
    });

    test(
      'stored languages: legacy key is read, unsupported ones fall back',
      () async {
        final storage = InMemoryLocalStorage();
        final repo = LocalUserLearningProfileRepository(storage);

        // Written before the support language had its own name.
        storage.data[_key] = jsonEncode({
          'v': 2,
          'interfaceLanguage': 'spanish',
          'learningLanguage': 'italian',
          'level': 'a2',
          'goals': ['work'],
          'focusAreas': ['grammar'],
          'onboardingCompleted': true,
        });
        final migrated = _unwrap(await repo.load());
        expect(migrated.supportLanguage, AppLanguage.spanish);
        expect(migrated.learningLanguage, AppLanguage.italian);
        expect(migrated.isValid, isTrue);
        expect(migrated.onboardingCompleted, isTrue);

        // Saving writes the new name and nothing is lost.
        await repo.save(migrated);
        final stored = jsonDecode(storage.data[_key]!) as Map<String, dynamic>;
        expect(stored['supportLanguage'], 'spanish');
        expect(stored.containsKey('interfaceLanguage'), isFalse);
        expect(_unwrap(await repo.load()), migrated);

        // A language with no interface cannot be the support language: it
        // falls back to the default one.
        storage.data[_key] = jsonEncode({
          'v': 2,
          'supportLanguage': 'french',
          'learningLanguage': 'german',
          'onboardingCompleted': true,
        });
        final noInterface = _unwrap(await repo.load());
        expect(noInterface.supportLanguage, AppLanguage.spanish);
        expect(noInterface.learningLanguage, AppLanguage.german);
        expect(noInterface.languagePair.isSupported, isTrue);

        // ... and a language is never learned through itself: the language to
        // learn moves aside for the support one.
        storage.data[_key] = jsonEncode({
          'v': 2,
          'supportLanguage': 'italian',
          'learningLanguage': 'italian',
          'onboardingCompleted': true,
        });
        final same = _unwrap(await repo.load());
        expect(same.languagePair.isSupported, isTrue);
        expect(same.supportLanguage, AppLanguage.italian);
        expect(same.learningLanguage, AppLanguage.english);
      },
    );
  });

  testWidgets('Profile can switch the learning language to English and back', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await LocalUserLearningProfileRepository(storage).save(onboardedProfile);
    await pumpApp(tester, storage);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Profilo'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lingua che impari'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);

    await tester.tap(find.text('Lingua che impari'));
    await tester.pumpAndSettle();
    // Only languages the app can teach are offered; Spanish is not one.
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Italiano'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Español'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    final stored = jsonDecode(storage.data[_key]!) as Map<String, dynamic>;
    expect(stored['learningLanguage'], 'english');
    expect(stored['supportLanguage'], 'spanish');
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('Lingua che impari'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Italiano'),
      ),
    );
    await tester.pumpAndSettle();
    expect(jsonDecode(storage.data[_key]!)['learningLanguage'], 'italian');
  });

  testWidgets('the interface language can follow the support language or be '
      'another one, and changes the app at once', (tester) async {
    final storage = InMemoryLocalStorage();
    // Spanish speaker, interface in Italian (explicit choice).
    await LocalUserLearningProfileRepository(storage).save(onboardedProfile);
    await pumpApp(tester, storage);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Profilo'),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> pick(String tile, String option) async {
      await tester.tap(find.text(tile));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(option),
        ),
      );
      await tester.pumpAndSettle();
    }

    // To English: an explicit choice.
    await pick('Lingua dell’app', 'English');
    expect(jsonDecode(storage.data[_key]!)['uiLanguage'], 'english');
    expect(find.text('App language'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Profile'),
      ),
      findsOneWidget,
    );

    // To the support language (Español): back to "follow it".
    await pick('App language', 'Español');
    expect(jsonDecode(storage.data[_key]!)['uiLanguage'], isNull);
    expect(find.text('Idioma de la app'), findsOneWidget);
  });
}
