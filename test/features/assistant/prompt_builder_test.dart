import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/builders/prompt_builder.dart';
import 'package:wardrobeos/features/assistant/models/assistant_context.dart';
import 'package:wardrobeos/features/assistant/models/assistant_request.dart';

void main() {
  test('assemble uniquement les sections disponibles', () {
    final prompt = PromptBuilder().build(
      const AssistantRequest(
        message: 'Que porter ?',
        constraints: {'occasion': 'travail'},
      ),
      const AssistantContext(weather: '23°C', wardrobe: ['Chemise bleue']),
    );

    expect(prompt, contains('## Demande\nQue porter ?'));
    expect(prompt, contains('## Météo\n23°C'));
    expect(prompt, contains('## Garde-robe\nChemise bleue'));
    expect(prompt, contains('## Contraintes'));
    expect(prompt, isNot(contains('## Historique')));
  });

  test('accepte des sections supplémentaires', () {
    final prompt = PromptBuilder(
      sections: [(request, context) => '## Calendrier\nAucun événement'],
    ).build(const AssistantRequest(), const AssistantContext());

    expect(prompt, '## Calendrier\nAucun événement');
  });
}
