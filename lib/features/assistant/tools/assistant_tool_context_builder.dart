import 'assistant_tool.dart';

typedef AssistantToolContext = Map<String, AssistantToolData>;

class AssistantToolContextBuilder {
  final List<AssistantTool> _tools;

  AssistantToolContextBuilder({required List<AssistantTool> tools})
    : _tools = List.unmodifiable(tools) {
    final ids = _tools.map((tool) => tool.id).toSet();
    if (ids.length != _tools.length) {
      throw ArgumentError('Chaque outil assistant doit avoir un identifiant unique.');
    }
  }

  Future<AssistantToolContext> build() async {
    final context = <String, AssistantToolData>{};
    for (final tool in _tools) {
      context[tool.id] = {
        'description': tool.description,
        'data': await tool.getData(),
      };
    }
    return Map.unmodifiable(context);
  }
}
