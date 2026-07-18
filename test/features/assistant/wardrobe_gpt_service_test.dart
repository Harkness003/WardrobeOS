import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/builders/context_builder.dart';
import 'package:wardrobeos/features/assistant/builders/prompt_builder.dart';
import 'package:wardrobeos/features/assistant/models/assistant_request.dart';
import 'package:wardrobeos/features/assistant/services/wardrobe_gpt_service.dart';

class _WeatherSource implements AssistantContextSource {
  @override
  Future<Object?> load(AssistantRequest request) async => '19°C';
}

void main() {
  test('construit le contexte et retourne la réponse simulée', () async {
    final service = WardrobeGptService(
      contextBuilder: ContextBuilder(weatherSource: _WeatherSource()),
      promptBuilder: PromptBuilder(),
    );

    final response = await service.generate(
      const AssistantRequest(message: 'Bonjour'),
    );

    expect(response.message, contains('Bonjour 👋'));
    expect(response.message, contains('19°C'));
    expect(response.message, contains('Je prépare mes recommandations.'));
    expect(response.suggestions, isEmpty);
  });
}
