import 'package:parla_con_me/core/result/result.dart';
import 'package:parla_con_me/services/storage/local_storage.dart';

class InMemoryLocalStorage implements LocalStorage {
  final Map<String, String> data = {};

  @override
  Future<Result<String?>> readString(String key) async => Success(data[key]);

  @override
  Future<Result<void>> writeString(String key, String value) async {
    data[key] = value;
    return const Success(null);
  }

  @override
  Future<Result<void>> remove(String key) async {
    data.remove(key);
    return const Success(null);
  }
}
