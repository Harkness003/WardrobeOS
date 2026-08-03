import 'garment.dart';

enum OutfitCategory {
  top,
  bottom,
  shoes,
  jacket,
  coat,
  accessory,
  bag,
  jewelry,
  otherLayer,
}

class OutfitCriterionScore {
  final double value;
  final String explanation;

  const OutfitCriterionScore({required this.value, required this.explanation})
    : assert(value >= 0 && value <= 1);
}

class OutfitScore {
  final OutfitCriterionScore styleCoherence;
  final OutfitCriterionScore weatherSuitability;
  final OutfitCriterionScore temperatureSuitability;
  final OutfitCriterionScore formality;
  final OutfitCriterionScore diversity;
  final OutfitCriterionScore overallConfidence;

  const OutfitScore({
    required this.styleCoherence,
    required this.weatherSuitability,
    required this.temperatureSuitability,
    required this.formality,
    required this.diversity,
    required this.overallConfidence,
  });
}

class Outfit {
  final String id;
  final String name;
  final String? season;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int timesWorn;
  final DateTime? lastWorn;
  final Map<OutfitCategory, List<Garment>> garments;
  final OutfitScore? score;
  final List<String> justification;

  const Outfit({
    required this.id,
    required this.name,
    this.season,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.timesWorn = 0,
    this.lastWorn,
    this.garments = const {},
    this.score,
    this.justification = const [],
  });

  List<Garment> get allGarments => List.unmodifiable(
    OutfitCategory.values.expand((category) => garments[category] ?? const []),
  );

  List<Garment> itemsFor(OutfitCategory category) =>
      List.unmodifiable(garments[category] ?? const []);

  Outfit copyWith({
    String? name,
    String? season,
    bool? favorite,
    DateTime? updatedAt,
    Map<OutfitCategory, List<Garment>>? garments,
    OutfitScore? score,
    List<String>? justification,
  }) => Outfit(
    id: id,
    name: name ?? this.name,
    season: season ?? this.season,
    favorite: favorite ?? this.favorite,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    timesWorn: timesWorn,
    lastWorn: lastWorn,
    garments: garments ?? this.garments,
    score: score ?? this.score,
    justification: justification ?? this.justification,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'season': season,
    'favorite': favorite ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'times_worn': timesWorn,
    'last_worn': lastWorn?.toIso8601String(),
  };

  factory Outfit.fromMap(Map<String, Object?> map) => Outfit(
    id: _text(map['id']) ?? '',
    name: _text(map['name']) ?? '',
    season: _text(map['season']),
    favorite: map['favorite'] == 1 || map['favorite'] == true,
    createdAt:
        _parseDate(map['created_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        _parseDate(map['updated_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    timesWorn: _integer(map['times_worn']) ?? 0,
    lastWorn: _parseDate(map['last_worn']),
  );

  static DateTime? _parseDate(Object? value) {
    return value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
  }

  static String? _text(Object? value) => value is String ? value : null;
  static int? _integer(Object? value) => value is num ? value.toInt() : null;
}
