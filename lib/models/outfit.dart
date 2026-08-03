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
