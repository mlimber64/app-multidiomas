import '../../core/result/result.dart';

/// Minimal async key-value persistence boundary.
///
/// Repositories own serialization (e.g. JSON) of their domain models into
/// strings, so domain types never depend on the storage technology. When
/// learning data outgrows key-value storage, add a richer store behind a new
/// interface (or swap the implementation) without touching the domain.
abstract interface class LocalStorage {
  Future<Result<String?>> readString(String key);
  Future<Result<void>> writeString(String key, String value);
  Future<Result<void>> remove(String key);
}
