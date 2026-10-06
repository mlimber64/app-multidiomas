import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/features/conversation/data/local_conversation_repository.dart';
import 'package:parla_con_me/features/conversation/domain/conversation.dart';
import 'package:parla_con_me/services/ai/ai_service.dart';
import 'package:parla_con_me/shared/models/correction.dart';

import '../../support/in_memory_local_storage.dart';

final _t0 = DateTime.utc(2026, 10, 5, 10);

ConversationMessage _msg(
  String id,
  MessageRole role,
  String text, {
  int minute = 0,
  List<Correction> corrections = const [],
}) => ConversationMessage(
  id: id,
  role: role,
  content: text,
  createdAt: _t0.add(Duration(minutes: minute)),
  corrections: corrections,
);

List<Conversation> _all(Result<List<Conversation>> r) =>
    r.when(success: (c) => c, failure: (f) => fail('unexpected $f'));

void main() {
  group('domain', () {
    test('AIResponse without corrections has an empty list', () {
      expect(const AIResponse(message: 'Ciao').corrections, isEmpty);
    });

    test('Correction decoding is lenient and category falls back to other', () {
      final c = Correction.tryFromJson({
        'original': ' sono andato ',
        'corrected': 'sono andato',
        'category': 'nonsense',
        'naturalAlternative': '  ',
      });
      expect(c, isNotNull);
      expect(c!.original, 'sono andato');
      expect(c.category, CorrectionCategory.other);
      expect(c.naturalAlternative, isNull);
      expect(c.explanation, '');

      expect(Correction.tryFromJson({'original': 'x'}), isNull);
      expect(Correction.tryFromJson('not a map'), isNull);
      expect(Correction.tryFromJson(null), isNull);
    });

    test('Conversation.addMessage appends and updates updatedAt', () {
      final start = Conversation.start(id: 'c1', now: _t0);
      expect(start.isEmpty, isTrue);

      final next = start.addMessage(
        _msg('m1', MessageRole.user, 'Ciao', minute: 3),
      );
      expect(start.messages, isEmpty, reason: 'immutable');
      expect(next.messages.single.content, 'Ciao');
      expect(next.createdAt, _t0);
      expect(next.updatedAt, _t0.add(const Duration(minutes: 3)));
    });
  });

  group('LocalConversationRepository', () {
    late InMemoryLocalStorage storage;
    late LocalConversationRepository repo;

    setUp(() {
      storage = InMemoryLocalStorage();
      repo = LocalConversationRepository(storage);
    });

    test('nothing stored reads as an empty list', () async {
      expect(_all(await repo.loadAll()), isEmpty);
    });

    test('saves and recovers a conversation with corrections', () async {
      const correction = Correction(
        original: 'ho andato',
        corrected: 'sono andato',
        explanation: 'Con "andare" si usa "essere".',
        naturalAlternative: 'Sono stato',
        category: CorrectionCategory.grammar,
      );
      final conversation = Conversation.start(id: 'c1', now: _t0)
          .addMessage(_msg('m1', MessageRole.user, 'Ieri ho andato', minute: 1))
          .addMessage(
            _msg(
              'm2',
              MessageRole.assistant,
              'Quasi!',
              minute: 2,
              corrections: [correction],
            ),
          );

      await repo.save(conversation);
      final loaded = _all(await repo.loadAll()).single;

      expect(loaded.id, 'c1');
      expect(loaded.messages.map((m) => m.content), [
        'Ieri ho andato',
        'Quasi!',
      ]);
      expect(loaded.messages.last.role, MessageRole.assistant);
      expect(loaded.messages.last.corrections.single, correction);
      expect(loaded.updatedAt, conversation.updatedAt);
    });

    test(
      'keeps multiple conversations, most recent first; save replaces by id',
      () async {
        final a = Conversation.start(
          id: 'a',
          now: _t0,
        ).addMessage(_msg('a1', MessageRole.user, 'uno', minute: 1));
        final b = Conversation.start(
          id: 'b',
          now: _t0,
        ).addMessage(_msg('b1', MessageRole.user, 'due', minute: 5));
        await repo.save(a);
        await repo.save(b);

        expect(_all(await repo.loadAll()).map((c) => c.id), ['b', 'a']);

        final aUpdated = a.addMessage(
          _msg('a2', MessageRole.assistant, 'tre', minute: 9),
        );
        await repo.save(aUpdated);
        final all = _all(await repo.loadAll());
        expect(all.map((c) => c.id), ['a', 'b']);
        expect(all.first.messages, hasLength(2));
        expect(all.last.messages, hasLength(1), reason: 'b was not touched');
      },
    );

    test('an empty conversation round-trips', () async {
      await repo.save(Conversation.start(id: 'e', now: _t0));
      final loaded = _all(await repo.loadAll()).single;
      expect(loaded.id, 'e');
      expect(loaded.isEmpty, isTrue);
    });

    test('a corrupt document reads as empty and can be overwritten', () async {
      storage.data[LocalConversationRepository.storageKey] = '{not json';
      expect(_all(await repo.loadAll()), isEmpty);

      await repo.save(Conversation.start(id: 'n', now: _t0));
      expect(_all(await repo.loadAll()).single.id, 'n');
    });

    test('corrupt entries are skipped without losing the good ones', () async {
      storage.data[LocalConversationRepository.storageKey] = jsonEncode({
        'v': 1,
        'conversations': [
          'garbage',
          {'id': 'no-dates', 'messages': []},
          {
            'id': 'ok',
            'createdAt': _t0.toIso8601String(),
            'updatedAt': _t0.toIso8601String(),
            'messages': [
              {
                'id': 'm1',
                'role': 'user',
                'content': 'Ciao',
                'createdAt': _t0.toIso8601String(),
              },
              {
                'id': 'm2',
                'role': 'alien',
                'content': 'x',
                'createdAt': _t0.toIso8601String(),
              },
              {'role': 'user'},
            ],
          },
        ],
      });
      final all = _all(await repo.loadAll());
      expect(all.single.id, 'ok');
      expect(all.single.messages.single.content, 'Ciao');
    });
  });
}
