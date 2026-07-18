import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/settings/api_key_storage.dart';

class _MemoryStorage implements SecureKeyValueStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

void main() {
  test('sauvegarde, récupère et supprime la clé', () async {
    final storage = ApiKeyStorage(storage: _MemoryStorage());

    expect(await storage.exists(), isFalse);
    await storage.save('  sk-test  ');
    expect(await storage.read(), 'sk-test');
    expect(await storage.exists(), isTrue);
    await storage.delete();
    expect(await storage.read(), isNull);
  });

  test('refuse une clé vide', () async {
    final storage = ApiKeyStorage(storage: _MemoryStorage());
    expect(() => storage.save('  '), throwsArgumentError);
  });
}
