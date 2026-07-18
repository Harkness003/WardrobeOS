import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/builders/context_builder.dart';
import 'package:wardrobeos/features/assistant/models/assistant_request.dart';

class _Source implements AssistantContextSource {
  final Object? value;
  const _Source(this.value);

  @override
  Future<Object?> load(AssistantRequest request) async => value;
}

void main() {
  test('rassemble les sources configurées dans un contexte', () async {
    final context = await const ContextBuilder(
      weatherSource: _Source('18°C'),
      wardrobeSource: _Source(['Pantalon noir']),
      outfitsSource: _Source(['Tenue bureau']),
      wearHistorySource: _Source(['Pantalon noir: hier']),
      statisticsSource: _Source({'total': 1}),
    ).build(const AssistantRequest());

    expect(context.weather, '18°C');
    expect(context.wardrobe, ['Pantalon noir']);
    expect(context.outfits, ['Tenue bureau']);
    expect(context.wearHistory, ['Pantalon noir: hier']);
    expect(context.statistics, {'total': 1});
  });

  test('retourne un contexte vide sans source', () async {
    final context = await const ContextBuilder().build(
      const AssistantRequest(),
    );

    expect(context.weather, isNull);
    expect(context.wardrobe, isEmpty);
    expect(context.statistics, isEmpty);
  });
}
