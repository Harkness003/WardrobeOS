import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/ai/llm_provider.dart';
import 'package:wardrobeos/features/assistant/ai/openai_provider.dart';
import 'package:wardrobeos/features/assistant/settings/api_key_storage.dart';

class _EmptyStorage implements SecureKeyValueStorage {
  @override
  Future<void> delete({required String key}) async {}
  @override
  Future<String?> read({required String key}) async => null;
  @override
  Future<void> write({required String key, required String? value}) async {}
}

void main() {
  test('signale proprement une clé absente', () async {
    final provider = OpenAiProvider(
      apiKeyStorage: ApiKeyStorage(storage: _EmptyStorage()),
    );

    expect(
      () => provider.generate('Bonjour'),
      throwsA(isA<MissingApiKeyException>()),
    );
  });
}
