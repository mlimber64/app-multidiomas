import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/features/profile/domain/user_learning_profile.dart';
import 'package:parla_con_me/features/profile/presentation/profile_controller.dart';
import 'package:parla_con_me/features/voice/domain/speech_text.dart';
import 'package:parla_con_me/features/voice/presentation/speech_controller.dart';

import '../../support/fake_voice.dart';
import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

// Phase 15: what the speech engine is given is what should be SAID, not what
// is drawn on the screen.

void main() {
  group('spokenText', () {
    test('plain sentences are untouched, in every script', () {
      for (final text in [
        'Come stai oggi?',
        "L'amico è arrivato; che bello!",
        '¿Cómo estás hoy?',
        'Ça va très bien, merci.',
        'Wie geht es dir heute?',
        '你好！你今天怎么样？',
        'Costa 3,50 euro.',
      ]) {
        expect(spokenText(text), text);
      }
    });

    test('emoji are not read out', () {
      expect(spokenText('Quasi! 😊'), 'Quasi!');
      expect(spokenText('Bravo 👍🏽 davvero ❤️'), 'Bravo davvero');
      expect(spokenText('Ciao 🇮🇹!'), 'Ciao !');
      expect(spokenText('😊'), '');
      expect(spokenText('Bene ✨ ✅'), 'Bene');
    });

    test('markdown marks are dropped, the words stay', () {
      expect(
        spokenText('Questo è **molto** importante'),
        'Questo è molto importante',
      );
      expect(spokenText('Usa _essere_ e `avere`'), 'Usa essere e avere');
      expect(spokenText('## Titolo\nTesto'), 'Titolo Testo');
      expect(
        spokenText('- uno\n- due\n* tre\n• quattro'),
        'uno due tre quattro',
      );
      expect(spokenText('> citazione'), 'citazione');
      expect(
        spokenText('Vedi [questa pagina](https://x.y/z) ora'),
        'Vedi questa pagina ora',
      );
    });

    test('lines and spaces fold into single spaces', () {
      expect(spokenText('  Ciao,\n\n  come   stai?  '), 'Ciao, come stai?');
    });

    test('punctuation, apostrophes, hyphens and numbers stay as written', () {
      expect(
        spokenText("Dov'è l'ufficio? Va' avanti - poi gira."),
        "Dov'è l'ufficio? Va' avanti - poi gira.",
      );
      expect(spokenText('Sono le 10:30.'), 'Sono le 10:30.');
      expect(spokenText('1. Primo punto'), '1. Primo punto');
    });

    test('spelling a word out is not changed by it', () {
      final spelled = spellOut('il computer');
      expect(spokenText(spelled), spelled);
    });
  });

  group('what the speech controller gives the engine', () {
    ProviderContainer containerFor(FakeSpeechService speech) {
      final c = ProviderContainer(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(InMemoryLocalStorage()),
          speechServiceProvider.overrideWithValue(speech),
          userLearningProfileProvider.overrideWith(
            () => PreloadedUserLearningProfileController(onboardedProfile),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('the cleaned text, in the learning language', () async {
      final speech = FakeSpeechService();
      final c = containerFor(speech);
      await c
          .read(speechControllerProvider.notifier)
          .speak(
            key: 'k',
            text: 'Quasi! 😊 **Dove** sei andato?',
            language: AppLanguage.italian,
          );
      expect(speech.spoken.single.text, 'Quasi! Dove sei andato?');
      expect(speech.spoken.single.localeTag, 'it-IT');
    });
  });
}
