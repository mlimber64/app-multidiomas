import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/local_user_learning_profile_repository.dart';
import '../domain/user_learning_profile.dart';

final userLearningProfileRepositoryProvider =
    Provider<UserLearningProfileRepository>(
      (ref) =>
          LocalUserLearningProfileRepository(ref.watch(localStorageProvider)),
    );

/// The saved learner profile. The initial value is loaded in `main()` before
/// the first frame (via override) so routing never flickers.
final userLearningProfileProvider =
    NotifierProvider<UserLearningProfileController, UserLearningProfile>(
      UserLearningProfileController.new,
    );

class UserLearningProfileController extends Notifier<UserLearningProfile> {
  @override
  UserLearningProfile build() => UserLearningProfile.empty;

  /// Persists [profile] and only then publishes it. Returns `false` (state
  /// unchanged) if saving failed.
  Future<bool> save(UserLearningProfile profile) async {
    final result = await ref
        .read(userLearningProfileRepositoryProvider)
        .save(profile);
    return result.when(
      success: (_) {
        state = profile;
        return true;
      },
      failure: (_) => false,
    );
  }
}

/// Bootstrap/test helper: a controller starting with a known profile.
class PreloadedUserLearningProfileController
    extends UserLearningProfileController {
  PreloadedUserLearningProfileController(this._initial);
  final UserLearningProfile _initial;

  @override
  UserLearningProfile build() => _initial;
}
