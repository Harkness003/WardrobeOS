class PersonalStyle {
  final String id;
  final String name;
  final String description;
  final String notes;
  final List<String> examples;
  final List<String> characteristics;
  final List<String> colors;
  final List<String> materials;
  final List<String> occasions;
  final List<String> typicalPieces;

  const PersonalStyle({required this.id, required this.name,
    this.description = '', this.notes = '', this.examples = const [],
    this.characteristics = const [], this.colors = const [],
    this.materials = const [], this.occasions = const [],
    this.typicalPieces = const []});

  PersonalStyle copyWith({String? name, String? description, String? notes,
    List<String>? examples, List<String>? characteristics, List<String>? colors,
    List<String>? materials, List<String>? occasions, List<String>? typicalPieces}) =>
      PersonalStyle(id: id, name: name ?? this.name,
        description: description ?? this.description, notes: notes ?? this.notes,
        examples: examples ?? this.examples,
        characteristics: characteristics ?? this.characteristics,
        colors: colors ?? this.colors, materials: materials ?? this.materials,
        occasions: occasions ?? this.occasions,
        typicalPieces: typicalPieces ?? this.typicalPieces);

  Map<String, Object?> toMap() => {'id': id, 'name': name,
    'description': description, 'notes': notes, 'examples': examples,
    'characteristics': characteristics, 'colors': colors, 'materials': materials,
    'occasions': occasions, 'typicalPieces': typicalPieces};

  factory PersonalStyle.fromMap(Map<String, Object?> map) {
    List<String> list(String key) => (map[key] as List? ?? const []).map((e) => '$e').toList();
    return PersonalStyle(id: '${map['id']}', name: '${map['name']}',
      description: '${map['description'] ?? ''}', notes: '${map['notes'] ?? ''}',
      examples: list('examples'), characteristics: list('characteristics'),
      colors: list('colors'), materials: list('materials'),
      occasions: list('occasions'), typicalPieces: list('typicalPieces'));
  }
}
