import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/context/assistant_context.dart';
import 'package:wardrobeos/features/assistant/prompt/prompt_builder.dart';
import 'package:wardrobeos/features/assistant/prompt/prompt_composer.dart';
import 'package:wardrobeos/features/assistant/prompt/prompt_section.dart';

class _EmptySection implements PromptSection {
  const _EmptySection();
  @override
  String get title => 'VIDE';
  @override
  String? build(AssistantContext context) => null;
}

AssistantContext _context({bool withWeather = true}) => AssistantContext(
  weather:
      withWeather
          ? const AssistantWeather(
            temperature: 21.5,
            condition: 'Clair',
            city: 'Lyon',
          )
          : null,
  statistics: const AssistantStatistics(
    garmentCount: 12,
    outfitCount: 4,
    recordedWearCount: 7,
  ),
  history: const AssistantHistory(),
  date: AssistantDate(
    value: DateTime(2026, 7, 18, 9, 30),
    day: 'samedi',
    time: '09:30',
    season: 'été',
  ),
);

void main() {
  group('PromptComposer', () {
    test('retourne un prompt vide quand toutes les sections sont vides', () {
      expect(
        const PromptComposer().compose(_context(), const [_EmptySection()]),
        isEmpty,
      );
    });

    test('ignore les sections vides et sépare les autres', () {
      final prompt = const PromptComposer().compose(_context(), const [
        SystemPromptSection(),
        _EmptySection(),
        WardrobePromptSection(),
      ]);
      expect(prompt, contains('## SYSTÈME'));
      expect(prompt, contains('\n\n## GARDE-ROBE'));
      expect(prompt, isNot(contains('VIDE')));
    });
  });

  group('Sections', () {
    test('la météo est absente sans données météo', () {
      expect(
        const WeatherPromptSection().build(_context(withWeather: false)),
        isNull,
      );
    });

    test('la garde-robe expose les nombres de vêtements et tenues', () {
      final section = const WardrobePromptSection().build(_context());
      expect(section, contains('Nombre de vêtements : 12'));
      expect(section, contains('Nombre de tenues : 4'));
    });

    test('historique réserve une extension sans produire de contenu', () {
      expect(const HistoryPromptSection().build(_context()), isNull);
    });
  });

  test('PromptBuilder produit un prompt complet', () {
    final prompt = PromptBuilder().build(_context());
    expect(prompt, contains('Tu es WardrobeGPT.'));
    expect(prompt, contains('Ville : Lyon'));
    expect(prompt, contains('Température : 21.5°C'));
    expect(prompt, contains('Condition : Clair'));
    expect(prompt, contains('Nombre de vêtements : 12'));
    expect(prompt, contains('Utilisations enregistrées : 7'));
    expect(prompt, contains('Jour : samedi'));
    expect(prompt, isNot(contains('## HISTORIQUE')));
  });
}
