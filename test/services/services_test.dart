import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/config/app_config.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/services/ai/gemini_ai_service.dart';

import '../support/in_memory_local_storage.dart';

void main() {
  test('AppConfig parses environment and defaults to development', () {
    expect(AppEnvironment.parse('production'), AppEnvironment.production);
    expect(AppEnvironment.parse('nonsense'), AppEnvironment.development);
    expect(AppConfig.fromEnvironment().hasAICredentials, isFalse);
    expect(AppConfig.fromEnvironment().geminiModel, isNotEmpty);
  });

  test('AIService resolves to Gemini; without a key it reports '
      'notConfigured instead of calling the network', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final AIService ai = container.read(aiServiceProvider);
    expect(ai, isA<GeminiAIService>());

    final result = await ai.sendConversation(
      const AIRequest(
        messages: [AIMessage(role: AIRole.user, text: 'Ciao')],
      ),
    );
    final failure = result.when(success: (_) => null, failure: (f) => f);
    expect(failure, isA<AIFailure>());
    expect((failure! as AIFailure).kind, AIFailureKind.notConfigured);
  });

  test('LocalStorage contract: write, read, remove', () async {
    final storage = InMemoryLocalStorage();
    await storage.writeString('k', 'v');
    expect(
      (await storage.readString(
        'k',
      )).when(success: (v) => v, failure: (_) => null),
      'v',
    );
    await storage.remove('k');
    expect(
      (await storage.readString(
        'k',
      )).when(success: (v) => v, failure: (_) => 'err'),
      isNull,
    );
  });
}
