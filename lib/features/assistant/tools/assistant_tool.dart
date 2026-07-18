typedef AssistantToolData = Map<String, Object?>;

/// A self-contained source of structured business data for WardrobeGPT.
abstract interface class AssistantTool {
  String get id;
  String get description;

  Future<AssistantToolData> getData();
}
