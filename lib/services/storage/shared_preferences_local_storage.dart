import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/failure.dart';
import '../../core/result/result.dart';
import 'local_storage.dart';

/// [LocalStorage] backed by `shared_preferences`.
class SharedPreferencesLocalStorage implements LocalStorage {
  const SharedPreferencesLocalStorage(this._prefs);

  final SharedPreferencesAsync _prefs;

  @override
  Future<Result<String?>> readString(String key) =>
      _guard(() => _prefs.getString(key));

  @override
  Future<Result<void>> writeString(String key, String value) =>
      _guard(() => _prefs.setString(key, value));

  @override
  Future<Result<void>> remove(String key) => _guard(() => _prefs.remove(key));

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } catch (e) {
      return Failure(StorageFailure('$e'));
    }
  }
}
