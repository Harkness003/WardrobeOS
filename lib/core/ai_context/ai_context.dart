import '../../features/assistant/memory/personalization_snapshot.dart';
import '../../models/garment.dart';

/// Provenance of a value exposed to an AI engine.
enum AiDataSource { user, aiAnalysis, calculated }

class AiContextValue<T> {
  final T value;
  final AiDataSource source;

  const AiContextValue(this.value, this.source);

  Map<String, Object?> toMap() => {
    'value': value,
    'source': source.name,
  };
}

/// Immutable, prompt-safe representation of one garment.
///
/// [id] is the existing database primary key. It is deliberately included in
/// AI payloads but remains an internal implementation detail in the UI.
class AiGarmentContext {
  final String id;
  final Map<String, AiContextValue<Object>> fields;

  AiGarmentContext._({required this.id, required Map<String, AiContextValue<Object>> fields})
      : fields = Map.unmodifiable(fields);

  factory AiGarmentContext.fromGarment(Garment garment) {
    final values = <String, AiContextValue<Object>>{};
    void add(String key, Object? value, AiDataSource source) {
      if (value == null || value == '' || value is List && value.isEmpty) return;
      values[key] = AiContextValue<Object>(value, source);
    }

    // Editable form values are authoritative user data, even when initially
    // suggested by AI: once the user saves the sheet, later analysis must not
    // silently replace them.
    add('name', garment.name, AiDataSource.user);
    add('category', garment.category, AiDataSource.user);
    add('subcategory', garment.sousCategorie, AiDataSource.user);
    add('color', garment.couleurPrincipale ?? garment.color, AiDataSource.user);
    add('secondaryColors', garment.couleursSecondaires, AiDataSource.aiAnalysis);
    add('material', garment.matierePrincipale ?? garment.material, AiDataSource.user);
    add('secondaryMaterials', garment.matieresSecondaires, AiDataSource.aiAnalysis);
    final style = garment.styleAnalysis;
    if (style != null) {
      add('styleCompatibilities', style.compatibilities.map((value) => value.toMap()).toList(),
          style.userCompatibilities != null ? AiDataSource.user : AiDataSource.aiAnalysis);
      add('styleCharacteristics', style.characteristics,
          style.userCharacteristics != null ? AiDataSource.user : AiDataSource.aiAnalysis);
    }
    add('seasons', garment.effectiveSeasons, AiDataSource.user);
    add('occasions', garment.effectiveOccasions, AiDataSource.user);
    final thermal = garment.thermalProfile;
    if (thermal != null) add('thermalProfile', thermal.toJson(), AiDataSource.calculated);
    add('description', garment.descriptionIA, AiDataSource.aiAnalysis);
    add('wearCount', garment.wearCount, AiDataSource.calculated);
    add('lastWorn', garment.lastWorn?.toIso8601String(), AiDataSource.calculated);
    return AiGarmentContext._(id: garment.id, fields: values);
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'fields': fields.map((key, value) => MapEntry(key, value.toMap())),
  };
}

/// A fresh snapshot shared by all intelligent features.
class WardrobeAiContext {
  final DateTime generatedAt;
  final List<Garment> garments;
  final List<AiGarmentContext> aiGarments;
  final PersonalizationSnapshot? personalization;
  final Duration loadDuration;

  WardrobeAiContext({
    required this.generatedAt,
    required List<Garment> garments,
    required this.personalization,
    this.loadDuration = Duration.zero,
  })  : garments = List.unmodifiable(garments),
        aiGarments = List.unmodifiable(garments.map(AiGarmentContext.fromGarment));

  Map<String, Object?> toMap() => {
    'generatedAt': generatedAt.toIso8601String(),
    'wardrobeSource': 'live_database',
    'memoryPolicy': 'memory_never_overrides_garments',
    'loadDurationMs': loadDuration.inMilliseconds,
    'garments': aiGarments.map((garment) => garment.toMap()).toList(growable: false),
  };
}
