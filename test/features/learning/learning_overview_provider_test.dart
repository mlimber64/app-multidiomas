import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/app/providers.dart';
import 'package:parla_con_me/core/errors/failure.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/presentation/conversation_controller.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_overview.dart';
import 'package:parla_con_me/features/learning/presentation/learning_providers.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/fake_ai_service.dart';
import '../../support/in_memory_local_storage.dart';
import '../../support/learning_fixtures.dart';

ProviderContainer _container(FakeMemoryRepository repo, {FakeAIService? ai}) {
  final c = ProviderContainer(
    overrides: [
      localStorageProvider.overrideWithValue(InMemoryLocalStorage()),
      learningRepositoryProvider.overrideWithValue(repo),
      if (ai != null) aiServiceProvider.overrideWithValue(ai),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<LearningOverview> _overview(ProviderContainer c) =>
    c.read(learningOverviewProvider.future);

void main() {
  test('memory -> provider -> presentation state', () async {
    final repo = FakeMemoryRepository(
      summaryOf(
        topics: [topicOf(GrammarTopic.essereVsAvere, errors: 3)],
        errors: [
          errorOf(
            'ho andato',
            'sono andato',
            topic: GrammarTopic.essereVsAvere,
          ),
        ],
        vocabulary: [wordOf('prenotazione')],
      ),
    );
    final overview = await _overview(_container(repo));

    expect(overview.toReinforce.single.topic, GrammarTopic.essereVsAvere);
    expect(overview.recurringErrors.single.correct, 'sono andato');
    expect(overview.vocabularyToConsolidate.single.word, 'prenotazione');
    expect(repo.reads, 1);
  });

  test('an empty memory is an empty overview, not an error', () async {
    final overview = await _overview(_container(FakeMemoryRepository()));
    expect(overview.isEmpty, isTrue);
  });

  test(
    'an unreadable memory is an error state the screens can present',
    () async {
      final repo = FakeMemoryRepository()..failing = true;
      final c = _container(repo);
      await expectLater(
        c.read(learningOverviewProvider.future),
        throwsA(isA<StorageFailure>()),
      );
      expect(c.read(learningOverviewProvider).hasError, isTrue);
    },
  );

  test(
    'bumping the revision refreshes the overview from the repository',
    () async {
      final repo = FakeMemoryRepository();
      final c = _container(repo);
      expect((await _overview(c)).isEmpty, isTrue);

      repo.summary = summaryOf(
        topics: [topicOf(GrammarTopic.articles, errors: 2)],
      );
      c.read(learningRevisionProvider.notifier).bump();
      final refreshed = await _overview(c);

      expect(refreshed.toReinforce.single.topic, GrammarTopic.articles);
      expect(repo.reads, 2, reason: 'one read per refresh, no more');
    },
  );

  test(
    'the previous overview stays available while a refresh is in flight',
    () async {
      final repo = FakeMemoryRepository(
        summaryOf(topics: [topicOf(GrammarTopic.articles, errors: 2)]),
      );
      final c = _container(repo);
      final sub = c.listen(learningOverviewProvider, (_, _) {});
      addTearDown(sub.close);
      await _overview(c);

      repo.gate = Completer<void>();
      c.read(learningRevisionProvider.notifier).bump();
      await Future<void>.delayed(Duration.zero);

      final state = c.read(learningOverviewProvider);
      expect(state.isLoading, isTrue);
      expect(
        state.value?.toReinforce.single.topic,
        GrammarTopic.articles,
        reason: 'no flicker',
      );
      repo.gate!.complete();
    },
  );

  test(
    'a conversation turn that updates the memory refreshes the overview by itself',
    () async {
      final repo = FakeMemoryRepository();
      final ai = FakeAIService(
        onRequest: (_) async => const Success(
          AIResponse(
            message: 'Quasi!',
            corrections: [
              Correction(
                original: 'Ieri ho andato al supermercato.',
                corrected: 'Ieri sono andato al supermercato.',
                explanation: '',
                category: CorrectionCategory.grammar,
              ),
            ],
          ),
        ),
      );
      final c = _container(repo, ai: ai);
      final sub = c.listen(learningOverviewProvider, (_, _) {});
      addTearDown(sub.close);
      expect((await _overview(c)).isEmpty, isTrue);
      final readsBefore = repo.reads;

      // The memory changes (here through the fake) and the conversation reports
      // that its learning analysis finished.
      repo.summary = summaryOf(
        topics: [topicOf(GrammarTopic.essereVsAvere, errors: 1)],
      );
      c.read(conversationControllerProvider);
      while (c.read(conversationControllerProvider).status ==
          ConversationStatus.loading) {
        await Future<void>.delayed(Duration.zero);
      }
      await c
          .read(conversationControllerProvider.notifier)
          .send('Ieri ho andato al supermercato.');
      await pumpEventQueue();

      expect(
        (await _overview(c)).toReinforce.single.topic,
        GrammarTopic.essereVsAvere,
      );
      expect(repo.reads, greaterThan(readsBefore));
    },
  );
}
