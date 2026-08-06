import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/outfits/outfits_controller.dart';
import 'package:wardrobeos/models/garment.dart';

void main() {
  Garment garment(String id, String category) => Garment(
    id: id,
    name: id, category: category,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('l onglet Tenues calcule jusqu à trois propositions sans tenue sauvegardée', () async {
    final controller = OutfitsController(wardrobeLoader: () async => [
      garment('top-a', 'Hauts'), garment('top-b', 'Hauts'),
      garment('bottom-a', 'Pantalons'), garment('bottom-b', 'Pantalons'),
    ]);
    await controller.generate();
    expect(controller.proposals, hasLength(3));
    expect(controller.proposals, everyElement(predicate((proposal) => proposal.garments.length >= 2)));
    expect(controller.generationDiagnostic?.producedCount, 3);
    controller.dispose();
  });
}
