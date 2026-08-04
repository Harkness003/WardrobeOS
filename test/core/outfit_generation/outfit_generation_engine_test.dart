import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/core/outfit_generation/outfit_generation_engine.dart';
import 'package:wardrobeos/core/recommendation/recommendation_context.dart';
import 'package:wardrobeos/models/garment.dart';

void main() {
  final now = DateTime(2026, 8, 4);
  Garment garment(String id, String category, {int wearCount = 0}) => Garment(
    id: id,
    name: id,
    category: category,
    wearCount: wearCount,
    createdAt: now,
    updatedAt: now,
  );
  OutfitGenerationEngine engine() => OutfitGenerationEngine(clock: () => now);

  test('gère un dressing très réduit sans inventer de pièce', () {
    final result = engine().generate(OutfitGenerationRequest(
      wardrobe: [garment('top', 'Hauts')],
      proposalCount: 3,
    ));
    expect(result.proposals, hasLength(1));
    expect(result.proposals.single.outfit.allGarments.single.id, 'top');
  });

  test('borne la génération pour un dressing important', () {
    final wardrobe = List.generate(300, (index) =>
      garment('item-$index', index.isEven ? 'Hauts' : 'Pantalons'));
    final result = engine().generate(OutfitGenerationRequest(
      wardrobe: wardrobe,
      proposalCount: 5,
    ));
    expect(result.proposals, hasLength(5));
    expect(result.proposals.every((item) => item.outfit.allGarments.length == 2), isTrue);
  });

  test('diversifie plusieurs vêtements similaires', () {
    final result = engine().generate(OutfitGenerationRequest(
      wardrobe: List.generate(6, (index) => garment('pull-$index', 'Hauts')),
      proposalCount: 4,
    ));
    expect(result.proposals.map((item) => item.outfit.allGarments.single.id).toSet(), hasLength(4));
  });

  test('accepte une météo absente et fournit des explications', () {
    final result = engine().generate(OutfitGenerationRequest(
      wardrobe: [garment('top', 'Hauts'), garment('bottom', 'Pantalons')],
    ));
    expect(result.proposals.single.reasons, isNotEmpty);
    expect(result.proposals.single.score, inInclusiveRange(0, 1));
  });

  test('retourne plusieurs propositions à la demande', () {
    final wardrobe = [
      for (var i = 0; i < 4; i++) garment('top-$i', 'Hauts'),
      for (var i = 0; i < 4; i++) garment('bottom-$i', 'Pantalons'),
    ];
    expect(engine().generate(OutfitGenerationRequest(
      wardrobe: wardrobe,
      proposalCount: 3,
    )).proposals, hasLength(3));
  });

  test('le classement est stable et favorise la rotation', () {
    final wardrobe = [
      garment('often', 'Hauts', wearCount: 20),
      garment('rare', 'Hauts'),
      garment('bottom-a', 'Pantalons'),
      garment('bottom-b', 'Pantalons'),
    ];
    List<String> ranking() => engine().generate(OutfitGenerationRequest(
      wardrobe: wardrobe,
      context: const RecommendationContext(),
      proposalCount: 2,
    )).proposals.map((item) => item.outfit.allGarments.map((g) => g.id).join('|')).toList();
    expect(ranking(), ranking());
    expect(ranking().first, contains('rare'));
  });
}
