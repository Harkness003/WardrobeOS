import '../../outfits/outfits_controller.dart';
import 'assistant_tool.dart';

class OutfitTool implements AssistantTool {
  final OutfitsController _controller;

  const OutfitTool({required OutfitsController controller})
    : _controller = controller;

  @override
  String get id => 'outfits';

  @override
  String get description => 'Tenues, suggestions et fréquence de port.';

  @override
  Future<AssistantToolData> getData() async {
    if (_controller.loading) await _controller.load();
    final worn = _controller.outfits.where((outfit) => outfit.lastWorn != null).toList()
      ..sort((a, b) => b.lastWorn!.compareTo(a.lastWorn!));
    final last = worn.isEmpty ? null : worn.first;

    return {
      'totalOutfits': _controller.outfits.length,
      'suggestions': _controller.suggestions
          .map((outfit) => {'id': outfit.id, 'name': outfit.name})
          .toList(growable: false),
      'lastWorn': last == null
          ? null
          : {
              'id': last.id,
              'name': last.name,
              'wornAt': last.lastWorn!.toIso8601String(),
            },
      'wearFrequency': {
        for (final outfit in _controller.outfits) outfit.id: outfit.timesWorn,
      },
    };
  }
}
