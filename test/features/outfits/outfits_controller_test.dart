import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/outfits/outfits_controller.dart';
import 'package:wardrobeos/models/garment.dart';

void main() {
  Garment garment(String id) => Garment(
    id: id,
    name: id, category: 'Hauts',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('l onglet Tenues calcule jusqu à trois propositions sans tenue sauvegardée', () async {
    final controller = OutfitsController(wardrobeLoader: () async => [
      garment('a'), garment('b'), garment('c'), garment('d'),
    ]);
    await controller.generate();
    expect(controller.proposals, hasLength(3));
    expect(controller.proposals.map((item) => item.outfit.allGarments.single.id).toSet(), hasLength(3));
    controller.dispose();
  });
}
