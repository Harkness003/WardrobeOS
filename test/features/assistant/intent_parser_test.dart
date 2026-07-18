import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/intents/intent_parser.dart';
import 'package:wardrobeos/features/assistant/intents/intent_type.dart';

void main() {
  const parser = IntentParser();

  test("détecte une tenue quotidienne et aujourd'hui", () {
    final result = parser.parse("Que mettre aujourd'hui ?");
    expect(result.type, AssistantIntentType.dailyOutfit);
    expect(result.parameters, {'date': "aujourd'hui"});
  });

  test('détecte une sortie au restaurant', () {
    final result = parser.parse('Je vais au restaurant');
    expect(result.type, AssistantIntentType.eventOutfit);
    expect(result.parameters, {'occasion': 'restaurant'});
  });

  test('détecte les vêtements peu portés', () {
    final result = parser.parse('Quels vêtements je porte peu ?');
    expect(result.type, AssistantIntentType.forgottenGarments);
    expect(result.parameters, isEmpty);
  });

  test('classe une phrase inconnue comme question générale', () {
    final result = parser.parse('Raconte-moi une histoire');
    expect(result.type, AssistantIntentType.generalQuestion);
    expect(result.parameters, isEmpty);
  });

  test('extrait la date et occasion pour un mariage', () {
    final result = parser.parse(
      "Je vais au mariage samedi, comment m'habiller ?",
    );
    expect(result.type, AssistantIntentType.eventOutfit);
    expect(result.parameters, {'date': 'samedi', 'occasion': 'mariage'});
  });
}
