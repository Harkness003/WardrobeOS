import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/outfits/outfits_controller.dart';
import 'package:wardrobeos/models/outfit.dart';

void main() {
  final now = DateTime(2026, 7, 18, 15);

  Outfit outfit(String id, {DateTime? lastWorn}) => Outfit(
    id: id,
    name: id,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    lastWorn: lastWorn,
  );

  test('an outfit that has never been worn scores 100000', () {
    expect(
      OutfitsController.suggestionScore(outfit('new'), now: now),
      OutfitsController.neverWornScore,
    );
  });

  test('score is the number of calendar days since the last wear', () {
    expect(
      OutfitsController.suggestionScore(
        outfit('worn', lastWorn: DateTime(2026, 7, 8, 23)),
        now: now,
      ),
      10,
    );
  });

  test('suggestions contain the three highest scores in descending order', () {
    final suggestions = OutfitsController.selectSuggestions([
      outfit('yesterday', lastWorn: DateTime(2026, 7, 17)),
      outfit('never'),
      outfit('month', lastWorn: DateTime(2026, 6, 18)),
      outfit('week', lastWorn: DateTime(2026, 7, 11)),
    ], now: now);

    expect(suggestions.map((item) => item.id), ['never', 'month', 'week']);
  });
}
