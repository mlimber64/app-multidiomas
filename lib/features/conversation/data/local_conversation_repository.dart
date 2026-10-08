import 'dart:convert';

import '../../../core/result/result.dart';
import '../../../services/storage/local_storage.dart';
import '../../../shared/models/correction.dart';
import '../domain/conversation.dart';

/// Stores all conversations as one versioned JSON document in [LocalStorage].
///
/// Fine for the MVP's small volume (the whole document is rewritten on each
/// save). When history grows, swap this class for a database-backed
/// implementation of [ConversationRepository]; the UI is unaffected.
///
/// Reads are defensive: a corrupt document reads as empty and a corrupt
/// conversation or message is skipped, so bad data never breaks the app.
class LocalConversationRepository implements ConversationRepository {
  const LocalConversationRepository(this._storage);

  static const storageKey = 'conversations';
  static const _version = 1;

  final LocalStorage _storage;

  @override
  Future<Result<List<Conversation>>> loadAll() async {
    final read = await _storage.readString(storageKey);
    return read.when(
      success: (raw) => Success(_decodeAll(raw)),
      failure: Failure.new,
    );
  }

  @override
  Future<Result<void>> save(Conversation conversation) async {
    final loaded = await loadAll();
    switch (loaded) {
      case Failure(:final failure):
        return Failure(failure);
      case Success(value: final existing):
        final all = [
          for (final c in existing)
            if (c.id != conversation.id) c,
          conversation,
        ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return _storage.writeString(
          storageKey,
          jsonEncode({
            'v': _version,
            'conversations': all.map(_encode).toList(),
          }),
        );
    }
  }

  Map<String, Object?> _encode(Conversation c) => {
    'id': c.id,
    'createdAt': c.createdAt.toIso8601String(),
    'updatedAt': c.updatedAt.toIso8601String(),
    'messages': [
      for (final m in c.messages)
        {
          'id': m.id,
          'role': m.role.name,
          'content': m.content,
          'createdAt': m.createdAt.toIso8601String(),
          'corrections': m.corrections.map((x) => x.toJson()).toList(),
          if (m.isVoice) 'voice': true,
          if (m.translation != null) 'translation': m.translation,
        },
    ],
  };

  List<Conversation> _decodeAll(String? raw) {
    if (raw == null) return const [];
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    final items = json is Map ? json['conversations'] : null;
    if (items is! List) return const [];
    return [for (final item in items) ?_decodeConversation(item)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Conversation? _decodeConversation(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final createdAt = _date(json['createdAt']);
    final updatedAt = _date(json['updatedAt']);
    final rawMessages = json['messages'];
    if (id is! String || createdAt == null || updatedAt == null) return null;
    if (rawMessages is! List) return null;
    return Conversation(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      messages: [for (final m in rawMessages) ?_decodeMessage(m)],
    );
  }

  ConversationMessage? _decodeMessage(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final content = json['content'];
    final createdAt = _date(json['createdAt']);
    final role = MessageRole.values
        .where((r) => r.name == json['role'])
        .firstOrNull;
    if (id is! String || content is! String || createdAt == null) return null;
    if (role == null) return null;
    final rawCorrections = json['corrections'];
    return ConversationMessage(
      id: id,
      role: role,
      content: content,
      createdAt: createdAt,
      corrections: rawCorrections is List
          ? [for (final c in rawCorrections) ?Correction.tryFromJson(c)]
          : const [],
      isVoice: json['voice'] == true,
      translation: _translation(json['translation']),
    );
  }

  /// Messages stored before translations existed have none.
  String? _translation(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
