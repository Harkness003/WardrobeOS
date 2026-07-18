import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureKeyValueStorage {
  Future<void> write({required String key, required String? value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class FlutterSecureKeyValueStorage implements SecureKeyValueStorage {
  final FlutterSecureStorage _storage;

  const FlutterSecureKeyValueStorage([
    this._storage = const FlutterSecureStorage(),
  ]);

  @override
  Future<void> write({required String key, required String? value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class ApiKeyStorage {
  static const storageKey = 'openai_api_key';
  final SecureKeyValueStorage _storage;

  const ApiKeyStorage({SecureKeyValueStorage? storage})
    : _storage = storage ?? const FlutterSecureKeyValueStorage();

  Future<void> save(String apiKey) async {
    final value = apiKey.trim();
    if (value.isEmpty) throw ArgumentError.value(apiKey, 'apiKey');
    await _storage.write(key: storageKey, value: value);
  }

  Future<String?> read() async {
    final value = (await _storage.read(key: storageKey))?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> delete() => _storage.delete(key: storageKey);

  Future<bool> exists() async => await read() != null;
}
