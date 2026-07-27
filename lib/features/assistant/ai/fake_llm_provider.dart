import 'llm_provider.dart';

class FakeLlmProvider implements StreamingLlmProvider {
  final String response;

  const FakeLlmProvider({
    this.response = 'Je suis WardrobeGPT en mode démonstration.',
  });

  @override
  Future<String> generate(String prompt) async => response;

  @override
  Stream<String> generateStream(String prompt) async* {
    yield response;
  }
}
