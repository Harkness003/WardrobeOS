import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/outfits/outfits_controller.dart';
import 'package:wardrobeos/data/database_service.dart';
import 'package:wardrobeos/core/diagnostics/diagnostic_service.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/outfit.dart';

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
    final proposal = controller.proposals.firstOrNull;
    expect(proposal, isNotNull);
    final verifiedProposal = proposal!;
    expect(verifiedProposal.garments.length, greaterThanOrEqualTo(2));
    expect(controller.generationDiagnostic?.producedCount, 3);
    controller.dispose();
  });

  test('une référence vêtement invalide ne bloque pas les tenues valides', () async {
    final diagnostics = DiagnosticService.instance
      ..clear()
      ..setEnabled(true);
    final saved = Outfit(
      id: 'saved',
      name: 'Tenue sauvegardée',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final controller = OutfitsController(
      storedOutfitsLoader: () async => StoredOutfitReadResult([saved], 1),
      outfitGarmentsLoader: (_) async => [garment('top', 'Hauts')],
      missingReferencesLoader: () async => 1,
    );

    await controller.load();

    expect(controller.error, isNull);
    expect(controller.outfits, [saved]);
    final entry = diagnostics
        .filtered(module: DiagnosticModule.outfits)
        .firstWhere((item) => item.reason == 'storedOutfitPartialOrInvalid');
    expect(entry.level, AppDiagnosticLevel.warning);
    expect(entry.details['missingGarments'], 1);
    expect(entry.details['decodeErrors'], 1);
    controller.dispose();
    diagnostics.setEnabled(false);
  });

  test('un vêtement lié indécodable conserve la tenue et charge le reste', () async {
    final first = Outfit(
      id: 'broken-link',
      name: 'Ancienne tenue',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final second = Outfit(
      id: 'valid',
      name: 'Tenue valide',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final controller = OutfitsController(
      storedOutfitsLoader: () async => StoredOutfitReadResult([first, second], 0),
      outfitGarmentsLoader: (id) async {
        if (id == first.id) throw const FormatException('garment legacy');
        return [garment('bottom', 'Pantalons')];
      },
      missingReferencesLoader: () async => 0,
    );

    await controller.load();

    expect(controller.error, isNull);
    expect(controller.outfits, hasLength(2));
    expect(controller.garmentsByOutfit[first.id], isEmpty);
    expect(controller.garmentsByOutfit[second.id], hasLength(1));
    controller.dispose();
  });
}
