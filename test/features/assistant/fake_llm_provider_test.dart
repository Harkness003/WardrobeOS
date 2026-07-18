import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/ai/fake_llm_provider.dart';

void main() {
  test('retourne une réponse de démonstration sans appel réseau', () async {
    const provider = FakeLlmProvider();

    expect(
      await provider.generate('Un prompt'),
      'Je suis WardrobeGPT en mode démonstration.',
    );
  });
}
