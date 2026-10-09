import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/domain/teacher_prompt.dart';
import 'package:parla_con_me/features/conversation/presentation/widgets/message_bubble.dart';
import 'package:parla_con_me/features/profile/domain/language_pair.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';
import 'package:parla_con_me/shared/ui/app_action_chip.dart';
import 'package:parla_con_me/shared/ui/app_bottom_nav.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';
import '../../support/pump_app.dart';

// The chat's redesign: the teacher's avatar, the quick replies, the correction
// icon and the voice button. The interface of these tests is Italian.
const _notUnderstood = 'Non ho capito';
const _notUnderstoodMessage = 'Non ho capito. Puoi spiegarlo in un altro modo?';

Future<FakeAIService> _openChat(WidgetTester tester) async {
  final ai = FakeAIService(
    onRequest: (request) async => const Success(
      AIResponse(
        message: 'Quasi! Dove sei andato?',
        corrections: [
          Correction(
            original: 'ho andato',
            corrected: 'sono andato',
            explanation: 'Con "andare" si usa "essere".',
            category: CorrectionCategory.grammar,
          ),
        ],
      ),
    ),
  );
  await pumpApp(
    tester,
    InMemoryLocalStorage(),
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
  return ai;
}

Future<void> _sendTyped(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byTooltip('Invia'));
  await tester.pumpAndSettle();
}

Finder get _quickChip => find.widgetWithText(AppActionChip, _notUnderstood);

void main() {
  testWidgets('the quick replies appear only once the teacher has spoken', (
    tester,
  ) async {
    await _openChat(tester);
    expect(_quickChip, findsNothing, reason: 'nothing to ask about yet');

    await _sendTyped(tester, 'Ieri ho andato al mare');
    expect(_quickChip, findsOneWidget);
    expect(
      find.widgetWithText(AppActionChip, 'Più lentamente'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(AppActionChip, 'Fammi un esempio'),
      findsOneWidget,
    );
  });

  testWidgets('a quick reply is sent as the learner\'s message', (
    tester,
  ) async {
    final ai = await _openChat(tester);
    await _sendTyped(tester, 'Ieri ho andato al mare');
    expect(ai.requests, hasLength(1));

    await tester.tap(_quickChip);
    await tester.pumpAndSettle();

    expect(ai.requests, hasLength(2));
    expect(ai.requests.last.messages.last.text, _notUnderstoodMessage);
    expect(find.text(_notUnderstoodMessage), findsOneWidget);
  });

  testWidgets('quick replies share the row of "Corrígeme" and scroll with it', (
    tester,
  ) async {
    await _openChat(tester);
    await _sendTyped(tester, 'Ieri ho andato al mare');
    final row = find.ancestor(
      of: _quickChip,
      matching: find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      ),
    );
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('Correggimi')),
      findsOneWidget,
    );
  });

  testWidgets('every teacher message has the avatar; the learner has none', (
    tester,
  ) async {
    await _openChat(tester);
    expect(find.byType(TeacherAvatar), findsNothing);
    await _sendTyped(tester, 'Ieri ho andato al mare');
    // One reply from the teacher, one message from the learner.
    expect(find.byType(MessageBubble), findsNWidgets(2));
    expect(find.byType(TeacherAvatar), findsOneWidget);
  });

  testWidgets('a correction has the magic wand', (tester) async {
    await _openChat(tester);
    await _sendTyped(tester, 'Ieri ho andato al mare');
    expect(
      find.descendant(
        of: find.byType(CorrectionCard),
        matching: find.byIcon(Icons.auto_fix_high),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'the voice button is the prominent one, and gives way to typing',
    (tester) async {
      await _openChat(tester);
      final mic = find.byTooltip('Registra un messaggio vocale');
      expect(mic, findsOneWidget);
      // The mint ring around it makes it bigger than the 52-wide send button.
      final ring = find.ancestor(
        of: mic,
        matching: find.byWidgetPredicate((w) {
          final d = w is Container ? w.decoration : null;
          return d is BoxDecoration &&
              d.shape == BoxShape.circle &&
              d.border != null;
        }),
      );
      expect(tester.getSize(ring).width, greaterThan(52));

      await tester.enterText(find.byType(TextField), 'Ciao');
      await tester.pump();
      expect(mic, findsNothing);
      expect(find.byTooltip('Invia'), findsOneWidget);
    },
  );

  test('the teacher knows how to answer a quick reply', () {
    final prompt = buildTeacherSystemPrompt(
      learning: AppLanguage.italian,
      support: AppLanguage.spanish,
    );
    expect(prompt, contains('asks for help in Spanish'));
    expect(prompt, contains('do not correct that message'));
  });
}
