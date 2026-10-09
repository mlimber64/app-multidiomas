import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/user_vocabulary.dart';

/// The words the learner starred, by id (see `UserVocabulary.idFor`). They are
/// a preference of the learner, not something the memory inferred, so they
/// live apart from the learning memory (`favorite_words`, a JSON list).
final favoriteWordsProvider = NotifierProvider<FavoriteWords, Set<String>>(
  FavoriteWords.new,
);

class FavoriteWords extends Notifier<Set<String>> {
  static const storageKey = 'favorite_words';

  Future<void> _loaded = Future<void>.value();

  @override
  Set<String> build() {
    _loaded = _load();
    return const {};
  }

  /// Whether [word] (in [language]) is starred.
  bool contains(String word, String language) =>
      state.contains(UserVocabulary.idFor(word, language));

  /// Stars or unstars a word. The screen changes at once; saving is best
  /// effort (a failed write only means the star is not there next time).
  Future<void> toggle(String word, String language) async {
    await _loaded;
    if (!ref.mounted) return;
    final id = UserVocabulary.idFor(word, language);
    state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
    await ref
        .read(localStorageProvider)
        .writeString(storageKey, jsonEncode(state.toList()..sort()));
  }

  Future<void> _load() async {
    final result = await ref.read(localStorageProvider).readString(storageKey);
    if (!ref.mounted) return;
    result.when(
      success: (raw) {
        if (raw == null) return;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            // What is already starred this session is kept.
            state = {...state, ...decoded.whereType<String>()};
          }
        } on FormatException {
          // An unreadable list is an empty list.
        }
      },
      failure: (_) {},
    );
  }
}
