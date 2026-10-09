import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

/// Whether the learner wants daily reminders. On unless they turned it off;
/// kept apart from the learning profile (`reminders_enabled`, `1` or `0`) since
/// it is a setting of the device, not something about their learning.
final remindersEnabledProvider = NotifierProvider<RemindersEnabled, bool>(
  RemindersEnabled.new,
);

class RemindersEnabled extends Notifier<bool> {
  static const storageKey = 'reminders_enabled';

  /// Completes when the saved choice has been read, so nothing is scheduled
  /// on the default before the real answer is known.
  Future<void> ready = Future<void>.value();

  @override
  bool build() {
    ready = _load();
    return true;
  }

  /// Turns the reminders on or off. The change shows at once; saving is best
  /// effort.
  Future<void> set({required bool enabled}) async {
    await ready;
    if (!ref.mounted) return;
    state = enabled;
    await ref
        .read(localStorageProvider)
        .writeString(storageKey, enabled ? '1' : '0');
  }

  Future<void> _load() async {
    final result = await ref.read(localStorageProvider).readString(storageKey);
    if (!ref.mounted) return;
    result.when(
      success: (raw) {
        if (raw == '0') state = false;
      },
      failure: (_) {},
    );
  }
}
