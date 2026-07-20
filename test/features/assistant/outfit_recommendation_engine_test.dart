import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/recommendation/outfit_candidate.dart';
import 'package:wardrobeos/features/assistant/recommendation/outfit_recommendation_engine.dart';
import 'package:wardrobeos/features/assistant/recommendation/outfit_recommendation_request.dart';

void main() {
  final now = DateTime(2026, 1, 15, 12);

  OutfitRecommendationEngine engine(List<OutfitCandidate> candidates) =>
      OutfitRecommendationEngine(
        candidateSource: () async => candidates,
        clock: () => now,
      );

  const coldRequest = OutfitRecommendationRequest(
    userIntent: 'dailyOutfit',
    originalMessage: "Que mettre aujourd'hui ?",
    season: 'hiver',
    weather: OutfitWeatherConstraints(temperature: 5, condition: 'Froid'),
  );

  test('sélectionne en priorité les vêtements adaptés au froid', () async {
    final result = await engine(const [
      OutfitCandidate(
        id: 'shirt',
        name: 'Chemise',
        category: 'Hauts',
        season: 'hiver',
      ),
      OutfitCandidate(
        id: 'coat',
        name: 'Manteau chaud',
        category: 'Manteaux',
        season: 'hiver',
      ),
      OutfitCandidate(
        id: 'shorts',
        name: 'Short',
        category: 'Shorts',
        season: 'été',
      ),
    ]).recommend(coldRequest);

    expect(result.candidates.map((item) => item.id), ['coat', 'shirt']);
  });

  test('exclut les vêtements portés très récemment', () async {
    final result = await engine([
      OutfitCandidate(
        id: 'recent',
        name: 'Pull récent',
        category: 'Pulls',
        season: 'hiver',
        lastWorn: now.subtract(const Duration(hours: 12)),
      ),
      const OutfitCandidate(
        id: 'available',
        name: 'Pull disponible',
        category: 'Pulls',
        season: 'hiver',
      ),
    ]).recommend(coldRequest);

    expect(result.candidates.map((item) => item.id), ['available']);
  });

  test('donne la priorité aux vêtements oubliés', () async {
    final result = await engine([
      OutfitCandidate(
        id: 'frequent',
        name: 'Pull fréquent',
        category: 'Pulls',
        season: 'hiver',
        wearCount: 20,
        lastWorn: now.subtract(const Duration(days: 10)),
      ),
      const OutfitCandidate(
        id: 'forgotten',
        name: 'Pull oublié',
        category: 'Pulls',
        season: 'hiver',
        wearCount: 0,
      ),
    ]).recommend(coldRequest);

    expect(result.candidates.first.id, 'forgotten');
  });
}
