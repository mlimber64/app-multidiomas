import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

// The test device speaks Spanish (see pumpApp), so onboarding starts in
// Spanish with Spanish as the support language and Italian to learn.

Finder _button(String label) => find.widgetWithText(FilledButton, label);

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(_button(label)).onPressed != null;

Future<void> _tap(WidgetTester tester, String option) async {
  await tester.ensureVisible(find.text(option));
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

Future<void> _continue(WidgetTester tester, String cta) async {
  await tester.tap(_button(cta));
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String option, String cta) async {
  await _tap(tester, option);
  await _continue(tester, cta);
}

/// Welcome -> languages (defaults) -> level step.
Future<void> _toLevelStep(WidgetTester tester) async {
  await _continue(tester, 'Empezar');
  await _continue(tester, 'Continuar');
}

Map<String, dynamic> _saved(InMemoryLocalStorage storage) =>
    jsonDecode(storage.data['user_learning_profile']!) as Map<String, dynamic>;

void main() {
  testWidgets('new user completes onboarding, profile is saved, Home shows it, '
      'and onboarding does not return on relaunch', (tester) async {
    final storage = InMemoryLocalStorage();
    await pumpApp(tester, storage);

    // Welcome, in the device language.
    expect(find.text('Tu profesor de idiomas personal.'), findsOne);
    expect(find.byType(NavigationBar), findsNothing);
    await _continue(tester, 'Empezar');

    // Languages: single choice, starting on the device language and Italian.
    expect(find.text('Tus idiomas'), findsOneWidget);
    expect(_enabled(tester, 'Continuar'), isTrue);
    await _continue(tester, 'Continuar');

    // Level: Continuar is disabled until something is selected.
    expect(find.text('¿Cuánto sabes ya de este idioma?'), findsOneWidget);
    expect(_enabled(tester, 'Continuar'), isFalse);
    await _pick(tester, 'A2 — Elemental', 'Continuar');

    // Goals (multi): two answers.
    expect(find.text('¿Por qué quieres aprender este idioma?'), findsOne);
    expect(_enabled(tester, 'Continuar'), isFalse);
    await _tap(tester, 'Hablar con más seguridad');
    await _tap(tester, 'Trabajo');
    await _continue(tester, 'Continuar');

    // Focus (multi)
    expect(find.text('¿En qué quieres concentrarte?'), findsOneWidget);
    expect(_enabled(tester, 'Comenzar'), isFalse);
    await _tap(tester, 'Gramática');
    await _tap(tester, 'Vocabulario');
    await _continue(tester, 'Comenzar');

    // Home, reading the freshly saved profile, still in Spanish.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('A2 — Elemental'), findsOneWidget);
    expect(find.text('Hablar con más seguridad, Trabajo'), findsOneWidget);
    expect(find.text('Gramática, Vocabulario'), findsOneWidget);

    final saved = _saved(storage);
    expect(saved['v'], 2);
    expect(saved['supportLanguage'], 'spanish');
    expect(saved['learningLanguage'], 'italian');
    expect(saved['uiLanguage'], isNull, reason: 'the app follows the language');
    expect(saved['level'], 'a2');
    expect(saved['goals'], ['speakConfidently', 'work']);
    expect(saved['focusAreas'], ['grammar', 'vocabulary']);
    expect(saved['onboardingCompleted'], true);

    // Relaunch with the same storage: straight to Home.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, storage);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Tu profesor de idiomas personal.'), findsNothing);
  });

  testWidgets('back returns to the previous step keeping the selection', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryLocalStorage());
    await _toLevelStep(tester);
    await _pick(tester, 'B1 — Intermedio', 'Continuar');

    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();

    expect(find.text('¿Cuánto sabes ya de este idioma?'), findsOneWidget);
    expect(_enabled(tester, 'Continuar'), isTrue);
  });

  testWidgets('level is single choice: picking another replaces it', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryLocalStorage());
    await _toLevelStep(tester);
    await _tap(tester, 'A1 — Principiante');
    await _tap(tester, 'B2 — Intermedio alto');
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsNothing);
  });

  testWidgets('goals: select, deselect, minimum and maximum', (tester) async {
    await pumpApp(tester, InMemoryLocalStorage());
    await _toLevelStep(tester);
    await _pick(tester, 'A2 — Elemental', 'Continuar');

    // Multi-select tiles use check boxes, and a counter hint.
    expect(find.text('Elige de 1 a 3 · 0 seleccionados'), findsOneWidget);
    expect(_enabled(tester, 'Continuar'), isFalse);

    await _tap(tester, 'Hablar con más seguridad');
    await _tap(tester, 'Escribir mejor');
    expect(find.byIcon(Icons.check_box), findsNWidgets(2));
    expect(_enabled(tester, 'Continuar'), isTrue);

    // Deselecting keeps the other one.
    await _tap(tester, 'Escribir mejor');
    expect(find.byIcon(Icons.check_box), findsOneWidget);

    // Deselecting the last one disables Continuar again.
    await _tap(tester, 'Hablar con más seguridad');
    expect(_enabled(tester, 'Continuar'), isFalse);

    // Maximum is 3: the fourth is ignored.
    await _tap(tester, 'Hablar con más seguridad');
    await _tap(tester, 'Escribir mejor');
    await _tap(tester, 'Trabajo');
    await _tap(tester, 'Estudios');
    expect(find.byIcon(Icons.check_box), findsNWidgets(3));
    expect(find.text('Elige de 1 a 3 · 3 seleccionados'), findsOneWidget);
    expect(_enabled(tester, 'Continuar'), isTrue);

    // Removing one frees a slot again.
    await _tap(tester, 'Trabajo');
    await _tap(tester, 'Estudios');
    expect(find.byIcon(Icons.check_box), findsNWidgets(3));
  });

  testWidgets('"Un poco de todo" excludes the specific goals, both ways', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryLocalStorage());
    await _toLevelStep(tester);
    await _pick(tester, 'A2 — Elemental', 'Continuar');

    await _tap(tester, 'Trabajo');
    await _tap(tester, 'Estudios');
    await _tap(tester, 'Un poco de todo');
    expect(find.byIcon(Icons.check_box), findsOneWidget);

    await _tap(tester, 'Estudios');
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    await _continue(tester, 'Continuar');
    await _tap(tester, 'Gramática');
    await _continue(tester, 'Comenzar');
  });

  testWidgets('"No estoy seguro" is stored as such, not as a level', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await pumpApp(tester, storage);
    await _toLevelStep(tester);
    await _pick(tester, 'No estoy seguro', 'Continuar');
    await _pick(tester, 'Trabajo', 'Continuar');
    await _pick(tester, 'Gramática', 'Comenzar');

    expect(_saved(storage)['level'], 'notSure');
    expect(find.text('No estoy seguro'), findsOneWidget);
  });

  testWidgets('choosing English to learn (support Spanish) is saved', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await pumpApp(tester, storage);
    await _continue(tester, 'Empezar');

    expect(find.text('Idioma de apoyo'), findsOneWidget);
    expect(find.text('Idioma que quieres aprender'), findsOneWidget);
    // "English" is offered twice: as a support language and as a language to
    // learn (the last one). Spanish cannot be learned, so it is not offered.
    final english = find.text('English');
    expect(english, findsNWidgets(2));
    await tester.ensureVisible(english.last);
    await tester.tap(english.last);
    await tester.pumpAndSettle();
    await _continue(tester, 'Continuar');
    await _pick(tester, 'B1 — Intermedio', 'Continuar');
    await _pick(tester, 'Trabajo', 'Continuar');
    await _pick(tester, 'Gramática', 'Comenzar');

    final saved = _saved(storage);
    expect(saved['supportLanguage'], 'spanish');
    expect(saved['learningLanguage'], 'english');
    expect(find.text('English'), findsOneWidget, reason: 'shown on Home');
  });

  testWidgets('the interface switches to the language the learner picks, and '
      'a language is never learned through itself', (tester) async {
    final storage = InMemoryLocalStorage();
    await pumpApp(tester, storage);
    await _continue(tester, 'Empezar');
    expect(find.text('Tus idiomas'), findsOneWidget);

    // Picking Italian as "my language" moves the interface to Italian, and the
    // language to learn (Italian) can no longer be the same one.
    await tester.tap(find.text('Italiano').first);
    await tester.pumpAndSettle();
    expect(find.text('Le tue lingue'), findsOneWidget);
    expect(find.text('Tus idiomas'), findsNothing);
    expect(_enabled(tester, 'Continua'), isTrue);

    await _continue(tester, 'Continua');
    await _pick(tester, 'B1 — Intermedio', 'Continua');
    await _pick(tester, 'Lavoro', 'Continua');
    await _pick(tester, 'Grammatica', 'Inizia');

    final saved = _saved(storage);
    expect(saved['supportLanguage'], 'italian');
    expect(saved['learningLanguage'], 'english');
    expect(saved['uiLanguage'], isNull);
    expect(find.text('Home'), findsOneWidget, reason: 'Italian interface');
  });

  testWidgets('French is offered to learn, in its own name, and is saved', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await pumpApp(tester, storage);
    await _continue(tester, 'Empezar');

    // French can be learned but is not an interface language: it is not
    // offered as "my language".
    expect(find.text('Français'), findsOneWidget);
    await _tap(tester, 'Français');
    await _continue(tester, 'Continuar');
    await _pick(tester, 'A1 — Principiante', 'Continuar');
    await _pick(tester, 'Trabajo', 'Continuar');
    await _pick(tester, 'Gramática', 'Comenzar');

    final saved = _saved(storage);
    expect(saved['supportLanguage'], 'spanish');
    expect(saved['learningLanguage'], 'french');
    expect(find.text('Français'), findsOneWidget, reason: 'shown on Home');
  });

  testWidgets('Portuguese is offered to learn and is saved', (tester) async {
    final storage = InMemoryLocalStorage();
    await pumpApp(tester, storage);
    await _continue(tester, 'Empezar');

    expect(find.text('Português'), findsOneWidget);
    await _tap(tester, 'Português');
    await _continue(tester, 'Continuar');
    await _pick(tester, 'A1 — Principiante', 'Continuar');
    await _pick(tester, 'Trabajo', 'Continuar');
    await _pick(tester, 'Gramática', 'Comenzar');

    expect(_saved(storage)['learningLanguage'], 'portuguese');
    expect(find.text('Português'), findsOneWidget, reason: 'shown on Home');
  });

  testWidgets('German is offered to learn and is saved', (tester) async {
    final storage = InMemoryLocalStorage();
    await pumpApp(tester, storage);
    await _continue(tester, 'Empezar');

    expect(find.text('Deutsch'), findsOneWidget);
    // The last option of a long list: scroll it clear of the button below.
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await _tap(tester, 'Deutsch');
    await _continue(tester, 'Continuar');
    await _pick(tester, 'A1 — Principiante', 'Continuar');
    await _pick(tester, 'Trabajo', 'Continuar');
    await _pick(tester, 'Gramática', 'Comenzar');

    expect(_saved(storage)['learningLanguage'], 'german');
    expect(find.text('Deutsch'), findsOneWidget, reason: 'shown on Home');
  });

  testWidgets('an English speaker can learn Spanish, the interface following', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await pumpApp(tester, storage);
    await _continue(tester, 'Empezar');

    // "My language": English. The interface switches, and Spanish (now free)
    // is offered to learn next to Italian.
    await tester.tap(find.text('English').first);
    await tester.pumpAndSettle();
    expect(find.text('Your languages'), findsOneWidget);
    final spanish = find.text('Español');
    expect(spanish, findsNWidgets(2), reason: 'as support and as to learn');
    // The last option of a long list: scroll it clear of the button below.
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(spanish.last);
    await tester.pumpAndSettle();
    await _continue(tester, 'Continue');
    await _pick(tester, 'B1 — Intermediate', 'Continue');
    await _pick(tester, 'Work', 'Continue');
    await _pick(tester, 'Grammar', 'Start');

    final saved = _saved(storage);
    expect(saved['supportLanguage'], 'english');
    expect(saved['learningLanguage'], 'spanish');
    expect(saved['uiLanguage'], isNull);
    expect(find.text('Español'), findsOneWidget, reason: 'shown on Home');
  });

  testWidgets('choosing Spanish as "my language" moves a Spanish learner on', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await pumpApp(tester, storage);
    await _continue(tester, 'Empezar');

    // English speaker learning Spanish...
    await tester.tap(find.text('English').first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    // ...switches to Spanish as their own language: no longer learning it.
    await tester.tap(find.text('Español').first);
    await tester.pumpAndSettle();
    expect(find.text('Tus idiomas'), findsOneWidget);
    await _continue(tester, 'Continuar');
    await _pick(tester, 'B1 — Intermedio', 'Continuar');
    await _pick(tester, 'Trabajo', 'Continuar');
    await _pick(tester, 'Gramática', 'Comenzar');

    final saved = _saved(storage);
    expect(saved['supportLanguage'], 'spanish');
    expect(saved['learningLanguage'], 'italian');
  });

  testWidgets('Mandarin is offered to learn, by its own name, and is saved', (
    tester,
  ) async {
    final storage = InMemoryLocalStorage();
    await pumpApp(tester, storage);
    await _continue(tester, 'Empezar');

    expect(find.text('中文'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    await _tap(tester, '中文');
    await _continue(tester, 'Continuar');
    await _pick(tester, 'A1 — Principiante', 'Continuar');
    await _pick(tester, 'Trabajo', 'Continuar');
    await _pick(tester, 'Gramática', 'Comenzar');

    expect(_saved(storage)['learningLanguage'], 'mandarin');
    expect(find.text('中文'), findsOneWidget, reason: 'shown on Home');
  });
}
