class AssistantContext {
  final String? weather;
  final List<String> wardrobe;
  final List<String> outfits;
  final List<String> wearHistory;
  final Map<String, Object?> statistics;

  const AssistantContext({
    this.weather,
    this.wardrobe = const [],
    this.outfits = const [],
    this.wearHistory = const [],
    this.statistics = const {},
  });
}
