import 'llm_provider.dart';

class FakeLlmProvider implements LlmProvider {
  final String response;

  const FakeLlmProvider({
    this.response = 'Je suis WardrobeGPT en mode démonstration.',
  });

  @override
  Future<String> generate(String prompt) async => response;
}
