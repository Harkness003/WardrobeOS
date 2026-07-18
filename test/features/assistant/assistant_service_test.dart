import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/context/assistant_context_builder.dart';
import 'package:wardrobeos/features/assistant/services/assistant_service.dart';
import 'package:wardrobeos/features/assistant/ai/fake_llm_provider.dart';
import 'package:wardrobeos/features/assistant/tools/assistant_tool.dart';
import 'package:wardrobeos/features/assistant/tools/assistant_tool_context_builder.dart';
import 'package:wardrobeos/features/outfits/outfits_controller.dart';
import 'package:wardrobeos/features/wardrobe/wardrobe_controller.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/outfit.dart';
import 'package:wardrobeos/weather/models/weather_data.dart';
import 'package:wardrobeos/weather/services/weather_service.dart';
import 'package:wardrobeos/features/assistant/recommendation/outfit_candidate.dart';
import 'package:wardrobeos/features/assistant/recommendation/outfit_recommendation_engine.dart';

class _WeatherService implements WeatherService {
  @override
  void clearCache() {}
  @override
  Future<WeatherData> getCurrentWeather({bool forceRefresh = false}) async =>
      WeatherData(
        city: 'Lyon', latitude: 0, longitude: 0, temperature: 22,
        apparentTemperature: 22, humidity: 0, windSpeed: 0, windDirection: 0,
        weatherCode: 0, description: 'Clair', measuredAt: DateTime(2026),
      );
}

class _BusinessTool implements AssistantTool {
  @override
  String get id => 'business';
  @override
  String get description => 'Données de test';
  @override
  Future<AssistantToolData> getData() async => {'available': true};
}

void main() {
  test('génère un prompt à partir du contexte', () async {
    final wardrobe = WardrobeController()
      ..loading = false
      ..garments = List.generate(
        2,
        (index) => Garment(
          id: '$index', name: 'Vêtement $index', category: 'Haut',
          createdAt: DateTime(2026), updatedAt: DateTime(2026),
        ),
      );
    final outfits = OutfitsController()
      ..loading = false
      ..outfits = [
        Outfit(
          id: 'o1', name: 'Tenue', createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
    final service = AssistantService(
      contextBuilder: AssistantContextBuilder(
        weatherService: _WeatherService(), wardrobeController: wardrobe,
        outfitsController: outfits,
        clock: () => DateTime(2026, 7, 14),
      ),
      llmProvider: const FakeLlmProvider(response: 'Conseil généré'),
    );

    final message = await service.generatePrompt();

    expect(message, contains('Jour : mardi'));
    expect(message, contains('Température : 22°C'));
    expect(message, contains('Ville : Lyon'));
    expect(message, contains('Nombre de vêtements : 2'));
    expect(message, contains('Nombre de tenues : 1'));
  });

  test('génère une réponse avec le fournisseur injecté', () async {
    final wardrobe = WardrobeController()..loading = false;
    final outfits = OutfitsController()..loading = false;
    final service = AssistantService(
      contextBuilder: AssistantContextBuilder(
        weatherService: _WeatherService(),
        wardrobeController: wardrobe,
        outfitsController: outfits,
      ),
      toolContextBuilder: AssistantToolContextBuilder(
        tools: [_BusinessTool()],
      ),
      llmProvider: const FakeLlmProvider(response: 'Conseil hors ligne'),
    );

    expect(await service.generateMessage(), 'Conseil hors ligne');
    expect(service.lastToolContext['business']?['data'], {'available': true});
  });

  test('génère une recommandation avec FakeLlmProvider', () async {
    final wardrobe = WardrobeController()..loading = false;
    final outfits = OutfitsController()..loading = false;
    final service = AssistantService(
      contextBuilder: AssistantContextBuilder(
        weatherService: _WeatherService(),
        wardrobeController: wardrobe,
        outfitsController: outfits,
        clock: () => DateTime(2026, 7, 18),
      ),
      recommendationEngine: OutfitRecommendationEngine(
        candidateSource: () async => const [
          OutfitCandidate(
            id: 'shirt', name: 'Chemise bleue', category: 'Hauts',
            season: 'été',
          ),
        ],
        clock: () => DateTime(2026, 7, 18),
      ),
      llmProvider: const FakeLlmProvider(response: 'Portez la chemise bleue.'),
    );

    final response = await service.generateMessage(
      userMessage: "Que mettre aujourd'hui ?",
    );

    expect(response, 'Portez la chemise bleue.');
    expect(service.lastRecommendationCandidates.single.id, 'shirt');
    expect(
      await service.generatePrompt(userMessage: "Que mettre aujourd'hui ?"),
      contains('### RECOMMANDATION TENUE'),
    );
  });
}
