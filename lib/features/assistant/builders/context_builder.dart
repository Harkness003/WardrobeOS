import '../models/assistant_context.dart';
import '../models/assistant_request.dart';

abstract interface class AssistantContextSource {
  Future<Object?> load(AssistantRequest request);
}

class ContextBuilder {
  final AssistantContextSource? weatherSource;
  final AssistantContextSource? wardrobeSource;
  final AssistantContextSource? outfitsSource;
  final AssistantContextSource? wearHistorySource;
  final AssistantContextSource? statisticsSource;

  const ContextBuilder({
    this.weatherSource,
    this.wardrobeSource,
    this.outfitsSource,
    this.wearHistorySource,
    this.statisticsSource,
  });

  Future<AssistantContext> build(AssistantRequest request) async {
    final values = await Future.wait<Object?>([
      _load(weatherSource, request),
      _load(wardrobeSource, request),
      _load(outfitsSource, request),
      _load(wearHistorySource, request),
      _load(statisticsSource, request),
    ]);

    return AssistantContext(
      weather: values[0] as String?,
      wardrobe: _strings(values[1]),
      outfits: _strings(values[2]),
      wearHistory: _strings(values[3]),
      statistics: _map(values[4]),
    );
  }

  Future<Object?> _load(
    AssistantContextSource? source,
    AssistantRequest request,
  ) => source?.load(request) ?? Future<Object?>.value(null);

  List<String> _strings(Object? value) =>
      value is Iterable ? value.whereType<String>().toList() : const [];

  Map<String, Object?> _map(Object? value) =>
      value is Map<String, Object?> ? value : const {};
}
