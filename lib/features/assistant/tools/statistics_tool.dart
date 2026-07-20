import '../../wardrobe/wardrobe_controller.dart';
import 'assistant_tool.dart';

class StatisticsTool implements AssistantTool {
  final WardrobeController _controller;

  const StatisticsTool({required WardrobeController controller})
    : _controller = controller;

  @override
  String get id => 'statistics';

  @override
  String get description => 'Statistiques d’utilisation des vêtements.';

  @override
  Future<AssistantToolData> getData() async {
    if (_controller.loading) await _controller.load();
    final garments = _controller.garments;
    final ranked =
        garments.toList()..sort((a, b) => b.wearCount.compareTo(a.wearCount));
    return {
      'garmentCount': garments.length,
      'wearCount': garments.fold<int>(
        0,
        (total, garment) => total + garment.wearCount,
      ),
      'mostUsed': ranked
          .where((garment) => garment.wearCount > 0)
          .take(5)
          .map(
            (garment) => {
              'id': garment.id,
              'name': garment.name,
              'wearCount': garment.wearCount,
            },
          )
          .toList(growable: false),
      'forgotten': garments
          .where((garment) => garment.wearCount == 0)
          .map((garment) => {'id': garment.id, 'name': garment.name})
          .toList(growable: false),
    };
  }
}
