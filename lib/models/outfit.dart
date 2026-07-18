class Outfit {
  final String id;
  final String name;
  final String? season;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int timesWorn;
  final DateTime? lastWorn;

  const Outfit({
    required this.id,
    required this.name,
    this.season,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.timesWorn = 0,
    this.lastWorn,
  });

  Outfit copyWith({
    String? name,
    String? season,
    bool? favorite,
    DateTime? updatedAt,
  }) => Outfit(
    id: id,
    name: name ?? this.name,
    season: season ?? this.season,
    favorite: favorite ?? this.favorite,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    timesWorn: timesWorn,
    lastWorn: lastWorn,
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
    id: map['id'] as String,
    name: map['name'] as String,
    season: map['season'] as String?,
    favorite: (map['favorite'] as int? ?? 0) == 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    timesWorn: map['times_worn'] as int? ?? 0,
    lastWorn: _parseDate(map['last_worn']),
  );

  static DateTime? _parseDate(Object? value) {
    final text = value as String?;
    return text == null || text.isEmpty ? null : DateTime.tryParse(text);
  }
}
