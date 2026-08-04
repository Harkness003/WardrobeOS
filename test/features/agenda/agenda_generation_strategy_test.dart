import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/core/outfit_generation/outfit_generation_engine.dart';
import 'package:wardrobeos/features/agenda/agenda_models.dart';
import 'package:wardrobeos/features/agenda/agenda_service.dart';
import 'package:wardrobeos/models/garment.dart';

void main() {
  final now = DateTime(2026, 8, 4);

  Garment garment(String id) => Garment(
        id: id,
        name: id,
        category: 'Hauts',
        createdAt: now,
        updatedAt: now,
      );

  test('le sélecteur évite une proposition déjà utilisée', () {
    final result = OutfitGenerationEngine(clock: () => now).generate(
      OutfitGenerationRequest(
        wardrobe: [garment('a'), garment('b'), garment('c')],
        proposalCount: 3,
      ),
    );
    final first = result.proposals.first.outfit;
    final previous = PlannedOutfit(
      id: 'previous',
      date: now.subtract(const Duration(days: 1)),
      outfitId: first.id,
      outfit: first,
      createdAt: now,
      updatedAt: now,
    );

    final selected = const DefaultAgendaProposalSelector().select(
      date: now,
      result: result,
      previous: [previous],
      preferences: const AgendaPreferences(),
    );

    expect(selected, isNotNull);
    expect(selected!.outfit.allGarments.single.id,
        isNot(first.allGarments.single.id));
  });

  test('le sélecteur exprime explicitement un dressing vide', () {
    final result = OutfitGenerationEngine(clock: () => now).generate(
      const OutfitGenerationRequest(wardrobe: []),
    );

    expect(
      const DefaultAgendaProposalSelector().select(
        date: now,
        result: result,
        previous: const [],
        preferences: const AgendaPreferences(),
      ),
      isNull,
    );
  });
}
