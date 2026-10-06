import 'dart:convert';

import '../../../core/result/result.dart';
import '../../../services/storage/local_storage.dart';
import '../domain/user_learning_profile.dart';

/// Stores the profile as one versioned JSON document in [LocalStorage].
/// Enums are persisted by name; unknown or corrupt values are dropped (or fall
/// back to the default language) so a bad value never crashes the app.
///
/// Versions: 1 stored single `primaryGoal` / `learningFocus` values and no
/// languages; 2 stores `goals` / `focusAreas` lists plus the two languages
/// (the support language was first called `interfaceLanguage`, still read).
/// Reading accepts all of them; the next save writes 2.
class LocalUserLearningProfileRepository
    implements UserLearningProfileRepository {
  const LocalUserLearningProfileRepository(this._storage);

  static const storageKey = 'user_learning_profile';
  static const _version = 2;

  final LocalStorage _storage;

  @override
  Future<Result<UserLearningProfile>> load() async {
    final read = await _storage.readString(storageKey);
    return read.when(
      success: (raw) => Success(_decode(raw)),
      failure: Failure.new,
    );
  }

  @override
  Future<Result<void>> save(UserLearningProfile profile) {
    return _storage.writeString(
      storageKey,
      jsonEncode({
        'v': _version,
        'supportLanguage': profile.supportLanguage.name,
        'learningLanguage': profile.learningLanguage.name,
        'uiLanguage': profile.uiLanguage?.name,
        'level': profile.level?.name,
        // Enum order, so the stored form is deterministic.
        'goals': [
          for (final g in LearningGoal.values)
            if (profile.goals.contains(g)) g.name,
        ],
        'focusAreas': [
          for (final f in LearningFocus.values)
            if (profile.focusAreas.contains(f)) f.name,
        ],
        'speakReplies': profile.speakReplies,
        'onboardingCompleted': profile.onboardingCompleted,
      }),
    );
  }

  UserLearningProfile _decode(String? raw) {
    if (raw == null) return UserLearningProfile.empty;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return UserLearningProfile.empty;
      final support = _language(
        json['supportLanguage'] ?? json['interfaceLanguage'],
        availableSupportLanguages,
        defaultSupportLanguage,
      );
      final learning = _language(
        json['learningLanguage'],
        supportedLearningLanguages,
        defaultLearningLanguage,
      );
      return UserLearningProfile(
        // `interfaceLanguage` is the name the support language had before it
        // was told apart from the UI language: same meaning, still read.
        supportLanguage: support,
        // A language is never learned through itself.
        learningLanguage: learning == support
            ? defaultLearningLanguageFor(support)
            : learning,
        // Absent (older documents) or not an interface language: follow the
        // support language.
        uiLanguage: _optionalLanguage(json['uiLanguage'], availableUiLanguages),
        // The v1 level enum stored the same names, so they read unchanged.
        level: _byName(LanguageLevel.values, json['level']),
        goals: _set(
          LearningGoal.values,
          json['goals'] ?? json['primaryGoal'],
          maxGoals,
          aliases: LearningGoal.legacyNames,
        ),
        focusAreas: _set(
          LearningFocus.values,
          json['focusAreas'] ?? json['learningFocus'],
          maxFocusAreas,
        ),
        speakReplies: json['speakReplies'] == true,
        onboardingCompleted: json['onboardingCompleted'] == true,
      );
    } on FormatException {
      return UserLearningProfile.empty;
    }
  }

  /// A list of names (v2) or one legacy name (v1) as a set: unknown entries
  /// are dropped and the result never exceeds [max].
  static Set<T> _set<T extends Enum>(
    List<T> values,
    Object? stored,
    int max, {
    Map<String, T> aliases = const {},
  }) {
    final names = switch (stored) {
      final List<dynamic> list => list,
      final String single => [single],
      _ => const <dynamic>[],
    };
    final result = <T>{};
    for (final name in names) {
      final value = _byName(values, name) ?? aliases[name];
      if (value != null && result.length < max) result.add(value);
    }
    return result;
  }

  /// A stored language the app can really use for this role, else [fallback]:
  /// a name it does not know, or a language that is not (yet) supported, never
  /// reaches the learning system.
  static AppLanguage _language(
    Object? stored,
    List<AppLanguage> usable,
    AppLanguage fallback,
  ) {
    final language = _byName(AppLanguage.values, stored);
    return language != null && usable.contains(language) ? language : fallback;
  }

  static AppLanguage? _optionalLanguage(
    Object? stored,
    List<AppLanguage> usable,
  ) {
    final language = _byName(AppLanguage.values, stored);
    return language != null && usable.contains(language) ? language : null;
  }

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
