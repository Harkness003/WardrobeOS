import '../../wardrobe/wardrobe_controller.dart';
import 'assistant_tool.dart';

class WardrobeTool implements AssistantTool {
  final WardrobeController _controller;

  const WardrobeTool({required WardrobeController controller})
    : _controller = controller;

  @override
  String get id => 'wardrobe';

  @override
  String get description => 'Contenu et utilisation actuelle du dressing.';

  @override
  Future<AssistantToolData> getData() async {
    if (_controller.loading) await _controller.load();
    final garments = _controller.garments;
    final recentlyWorn = garments.where((garment) => garment.lastWorn != null).toList()
      ..sort((a, b) => b.lastWorn!.compareTo(a.lastWorn!));

    return {
      'totalGarments': garments.length,
      'categories': _values(garments.map((garment) => garment.category)),
      'mainColors': _values(garments.map((garment) => garment.color)),
      'recentlyWorn': recentlyWorn
          .take(5)
          .map(
            (garment) => {
              'id': garment.id,
              'name': garment.name,
              'lastWorn': garment.lastWorn!.toIso8601String(),
            },
          )
          .toList(growable: false),
      'neverWorn': garments
          .where((garment) => garment.wearCount == 0)
          .map((garment) => {'id': garment.id, 'name': garment.name})
          .toList(growable: false),
    };
  }

  static List<String> _values(Iterable<String?> values) {
    final unique = values
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    unique.sort();
    return unique;
  }
}
