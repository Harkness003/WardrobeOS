import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/context/assistant_context.dart';

void main() {
  test('conserve toutes les sections du contexte', () {
    final date = DateTime(2026, 7, 14, 9, 5);
    final context = AssistantContext(
      weather: const AssistantWeather(
        temperature: 22,
        condition: 'Ensoleillé',
        city: 'Lyon',
      ),
      statistics: const AssistantStatistics(
        garmentCount: 58,
        outfitCount: 17,
        recordedWearCount: 42,
      ),
      history: AssistantHistory(
        recentlyWornGarments: [
          WornGarment(id: 'g1', name: 'Chemise', wornAt: date),
        ],
      ),
      date: AssistantDate(
        value: date,
        day: 'mardi',
        time: '09:05',
        season: 'été',
      ),
    );

    expect(context.weather.city, 'Lyon');
    expect(context.statistics.recordedWearCount, 42);
    expect(context.history.recentlyWornGarments.single.name, 'Chemise');
    expect(context.date.season, 'été');
  });
}
